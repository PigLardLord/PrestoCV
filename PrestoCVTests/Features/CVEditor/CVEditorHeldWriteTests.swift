import Testing
import Foundation
import Combine
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - A store whose writes go as the test scripts them

/// A store whose writes go as a test scripts them, one step per write: stored, failed, or held until the test lets it go
/// and then stored or failed. The writes after the script are stored.
actor ScriptedCVStore: CVManagementUseCaseProtocol {
    enum Step: Sendable {
        case stores
        case fails
        case heldThenStores
        case heldThenFails
    }

    /// What the store holds, by id.
    private(set) var stored: [UUID: CVModel] = [:]
    /// The writes that were tried, in order, whatever became of them.
    private(set) var attempts: [CVModel] = []
    private var script: [Step]
    private var held: CheckedContinuation<Void, Never>?
    private var heldWatchers: [CheckedContinuation<Void, Never>] = []

    init(holding cv: CVModel? = nil, script: [Step]) {
        if let cv { stored[cv.id] = cv }
        self.script = script
    }

    /// Returns once a write is held.
    func waitUntilHeld() async {
        guard held == nil else { return }
        await withCheckedContinuation { heldWatchers.append($0) }
    }

    /// Lets the held write go on, as its step says.
    func release() {
        let write = held
        held = nil
        write?.resume()
    }

    private func write(_ cv: CVModel) async throws -> CVModel {
        attempts.append(cv)
        let step = script.isEmpty ? .stores : script.removeFirst()
        if step == .heldThenStores || step == .heldThenFails {
            await withCheckedContinuation { continuation in
                held = continuation
                heldWatchers.forEach { $0.resume() }
                heldWatchers = []
            }
        }
        if step == .fails || step == .heldThenFails {
            throw AppError.fileSystemError("disk full")
        }
        stored[cv.id] = cv
        return cv
    }

    func storeNewCV(_ cv: CVModel) async throws -> CVModel { try await write(cv) }
    func updateCV(_ cv: CVModel) async throws -> CVModel { try await write(cv) }
    func getCV(by id: UUID) async throws -> CVModel? { stored[id] }
    func getAllCVs() async throws -> [CVModel] { Array(stored.values) }
    func createCV(from template: CVModel) async throws -> CVModel { try await write(template.copy()) }
    func deleteCV(id: UUID) async throws { stored[id] = nil }
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { throw AppError.notFound("CV with id \(id)") }
}

/// The announcements an editor makes, in order.
@MainActor
private final class Announcements {
    private(set) var kinds: [SaveAnnouncement.Kind] = []
    private var subscription: AnyCancellable?

    init(of viewModel: CVEditorViewModel) {
        subscription = viewModel.$saveAnnouncement.sink { [weak self] announcement in
            if let announcement { self?.kinds.append(announcement.kind) }
        }
    }
}

// MARK: - What the editor shows while a write runs

/// Every predicate the editor derives from where its writes stand, while a write is held: the edge swipe's guard
/// (`storeHoldsWhatTheFormShows`), the line under the title (`showsSavedOnDevice`, `subtitle`), the banner
/// (`showsSaveFailure`), what VoiceOver hears, and the way out (`saveBeforeLeaving`, which Back, the guarded swipe and
/// "Open in" go through).
@MainActor
@Suite("CVEditorViewModel - while a write runs", .timeLimit(.minutes(1)))
struct CVEditorHeldWriteTests {

    /// Where the writes of an editor stand when the test looks: the store holds `stored` when the editor opens, and the
    /// form shows its phone number changed or put back.
    enum HeldWrite: CaseIterable, Sendable, CustomTestStringConvertible {
        /// Nothing changed, and no write runs: the one case that may leave at once.
        case noWrite
        /// The write of the change runs, and the form shows what it writes.
        case writeOfTheFormRuns
        /// The write of the change runs, and the form was put back to what the store held; the write that puts it back fails.
        case formUndoesTheRunningWrite
        /// The write of the change runs, and the form changed again.
        case formChangedDuringTheRunningWrite
        /// The first write failed, and Try Again runs.
        case retryRuns
        /// The first write failed, Try Again runs and fails, and so does the write of leaving.
        case retryRunsAndFailsAgain
        /// The first write failed, Try Again runs, and the form was put back to what the store held.
        case formUndoneDuringTheRetry
        /// The first write of a new CV runs.
        case firstWriteOfANewCVRuns

        var testDescription: String { "\(self)" }

        var script: [ScriptedCVStore.Step] {
            switch self {
            case .noWrite: return []
            case .writeOfTheFormRuns, .formChangedDuringTheRunningWrite, .firstWriteOfANewCVRuns: return [.heldThenStores]
            case .formUndoesTheRunningWrite: return [.heldThenStores, .fails]
            case .retryRuns, .formUndoneDuringTheRetry: return [.fails, .heldThenStores]
            case .retryRunsAndFailsAgain: return [.fails, .heldThenFails, .fails]
            }
        }

        /// Whether a failure came before the write that runs.
        var followsAFailure: Bool {
            switch self {
            case .retryRuns, .retryRunsAndFailsAgain, .formUndoneDuringTheRetry: return true
            default: return false
            }
        }

        /// What the editor shows while the write is held.
        var whileHeld: (swipeLeavesAtOnce: Bool, savedOnDevice: Bool, banner: Bool) {
            switch self {
            case .noWrite: return (true, true, false)
            case .writeOfTheFormRuns, .formUndoesTheRunningWrite, .formChangedDuringTheRunningWrite: return (false, true, false)
            case .retryRuns, .retryRunsAndFailsAgain, .formUndoneDuringTheRetry: return (false, false, true)
            case .firstWriteOfANewCVRuns: return (false, false, false)
            }
        }

        /// Whether leaving stores what the form shows, once the held write is let go.
        var leaves: Bool {
            switch self {
            case .formUndoesTheRunningWrite, .retryRunsAndFailsAgain: return false
            default: return true
            }
        }
    }

    private func storedCV() -> CVModel {
        CVModel(id: UUID(), name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi", phone: "+39 333 0000000"))
    }

    /// An editor brought to `held`, with the work that runs in it.
    private func editor(_ held: HeldWrite, of stored: CVModel, in store: ScriptedCVStore, clock: ManualClock) async -> (CVEditorViewModel, Task<Void, Never>?) {
        let changed = "+39 333 1234567"
        if held == .firstWriteOfANewCVRuns {
            let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: store, clock: clock)
            viewModel.cv.personalInfo.name = "Marta Rinaldi"
            clock.advance(by: .seconds(1))
            await store.waitUntilHeld()
            return (viewModel, nil)
        }
        let viewModel = CVEditorViewModel(cvId: stored.id.uuidString, cvManagementUseCase: store, clock: clock)
        await viewModel.loadCV()
        guard held != .noWrite else { return (viewModel, nil) }

        viewModel.cv.personalInfo.phone = changed
        var retry: Task<Void, Never>?
        if held.followsAFailure {
            await viewModel.saveNow()
            retry = Task { await viewModel.retrySaving() }
        } else {
            clock.advance(by: .seconds(1))
        }
        await store.waitUntilHeld()
        switch held {
        case .formUndoesTheRunningWrite, .formUndoneDuringTheRetry:
            viewModel.cv.personalInfo.phone = stored.personalInfo.phone
        case .formChangedDuringTheRunningWrite:
            viewModel.cv.personalInfo.location = "Bologna"
        default:
            break
        }
        return (viewModel, retry)
    }

    @Test("Every predicate derived from the writes holds while a write runs: the swipe, the line under the title, the banner, VoiceOver and the way out",
          arguments: HeldWrite.allCases)
    func predicatesWhileAWriteIsHeld(_ held: HeldWrite) async {
        let stored = storedCV()
        let store = ScriptedCVStore(holding: stored, script: held.script)
        let (viewModel, retry) = await editor(held, of: stored, in: store, clock: ManualClock())
        let heard = Announcements(of: viewModel)

        #expect(viewModel.storeHoldsWhatTheFormShows == held.whileHeld.swipeLeavesAtOnce, "The edge swipe leaves at once")
        #expect(viewModel.showsSavedOnDevice == held.whileHeld.savedOnDevice, "The line says the CV is saved on this device")
        #expect(viewModel.subtitle.isEmpty == !held.whileHeld.savedOnDevice)
        #expect(viewModel.showsSaveFailure == held.whileHeld.banner, "The banner says the change could not be saved")
        #expect(heard.kinds == (held.followsAFailure ? [.failed] : []), "Nothing is told while a write runs")

        let leaving = Task { await viewModel.saveBeforeLeaving() }
        await store.release()
        let left = await leaving.value
        await retry?.value

        #expect(left == held.leaves, "Leaving reports whether the store holds what the form shows")
        #expect(viewModel.storeHoldsWhatTheFormShows == held.leaves)
        #expect(viewModel.showsSaveFailure == !held.leaves, "A write that failed last is shown")
        #expect(viewModel.showsSavedOnDevice == held.leaves)
        if held.leaves {
            #expect(await store.stored[viewModel.cv.id] == viewModel.cv, "The store holds what the form shows")
        }
    }

    // MARK: - The findings this suite was written for

    /// What the guarded edge swipe does, as `CVEditorView` wires it: it leaves at once when the editor says the store
    /// holds what the form shows (the system pops the editor, and its disappearance stores what is left), and goes
    /// through Back otherwise.
    private func swipeBack(from editor: CVEditorViewModel, in router: AppRouter) async {
        if editor.storeHoldsWhatTheFormShows {
            router.navigateBack()
            router.editorDisappeared(editor)
        } else {
            await router.leaveEditor(editor)
        }
    }

    @Test("The edge swipe while a write runs goes through Back: when the write that puts the form back fails, the editor stays with its failure")
    func swipeOverAnUndoneWriteKeepsTheEditorWhenTheCorrectionFails() async {
        let stored = storedCV()
        let store = ScriptedCVStore(holding: stored, script: [.heldThenStores, .fails])
        let clock = ManualClock()
        let router = AppRouter(isAIShipped: false)
        let editor = CVEditorViewModel(cvId: stored.id.uuidString, cvManagementUseCase: store, clock: clock)
        await editor.loadCV()
        router.openEditor(.stored(cvId: stored.id.uuidString))
        router.editorAppeared(editor)
        editor.cv.personalInfo.phone = "+39 333 1234567"
        clock.advance(by: .seconds(1))
        await store.waitUntilHeld()
        editor.cv.personalInfo.phone = stored.personalInfo.phone

        let swipe = Task { await swipeBack(from: editor, in: router) }
        await store.release()
        await swipe.value

        #expect(router.navigationPath.count == 1, "The editor stays: the store does not hold what the form shows")
        #expect(editor.showsSaveFailure, "and it says so")
        #expect(editor.cv.personalInfo.phone == stored.personalInfo.phone, "The correction is still in the form")
        #expect(await store.stored[stored.id]?.personalInfo.phone == "+39 333 1234567", "The store holds the change the form undid")
    }

    @Test("While Try Again writes, the banner stays and nothing says the CV is saved, until the write succeeds")
    func retryShowsTheFailureUntilItSucceeds() async {
        let stored = storedCV()
        let store = ScriptedCVStore(holding: stored, script: [.fails, .heldThenStores])
        let editor = CVEditorViewModel(cvId: stored.id.uuidString, cvManagementUseCase: store, clock: ManualClock())
        await editor.loadCV()
        let heard = Announcements(of: editor)
        editor.cv.personalInfo.phone = "+39 333 1234567"
        await editor.saveNow()
        #expect(editor.showsSaveFailure)

        let retry = Task { await editor.retrySaving() }
        await store.waitUntilHeld()

        #expect(editor.showsSaveFailure, "The banner stays while the retry runs")
        #expect(!editor.showsSavedOnDevice, "Nothing says the CV is saved before the write has succeeded")
        #expect(editor.subtitle.isEmpty)
        #expect(heard.kinds == [.failed], "The start of the retry is not told")

        await store.release()
        await retry.value

        #expect(!editor.showsSaveFailure)
        #expect(editor.showsSavedOnDevice)
        #expect(heard.kinds == [.failed, .saved], "Saved is told once the write has succeeded")
    }
}
