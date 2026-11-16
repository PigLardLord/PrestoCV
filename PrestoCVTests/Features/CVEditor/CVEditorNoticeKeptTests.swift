import Testing
import Foundation
import Combine
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("CVEditorViewModel - the import's notice stays with the CV until the person dismisses it (#452)", .timeLimit(.minutes(1)))
struct CVEditorNoticeKeptTests {

    private let review = ImportReview(
        items: [ImportReview.Item(field: .title, reason: .byPosition, text: "Mobile Developer")],
        passages: [
            ImportReview.Passage(place: .top, text: "EU citizen\navailable from March 2026", isWholeSection: false),
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today", isWholeSection: true),
        ]
    )

    private func imported() -> CVModel {
        CVModel(personalInfo: PersonalInfo(name: "Tobias Renn", title: "Mobile Developer"))
    }

    @Test("An imported CV keeps its notice once it is stored, under the id it is stored with")
    func importedNoticeIsKeptWithTheCV() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )

        await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(await store.notice(ofCVWithId: stored.id) == .imported(review))
    }

    @Test("A stored CV opens again with the notice kept for it")
    func storedCVOpensWithItsNotice() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "", personalInfo: PersonalInfo(name: "Tobias Renn"))
        await useCase.storeCV(cv)
        let store = InMemoryEditorNoticeStore(notices: [cv.id: .importedDescription(review)])
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)

        await viewModel.loadCV()

        #expect(viewModel.notice == .importedDescription(review))
        #expect(viewModel.notice?.review?.sectionsNotImported == ["OWN VENTURES"])
    }

    @Test("A stored CV with no notice kept opens without one")
    func storedCVWithoutNotice() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "Kept", personalInfo: PersonalInfo(name: "Mara Ellison"))
        await useCase.storeCV(cv)
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: InMemoryEditorNoticeStore())

        await viewModel.loadCV()

        #expect(viewModel.notice == nil)
    }

    @Test("Dismissing the notice of a stored CV forgets it, so the CV opens again without it")
    func dismissedNoticeIsForgotten() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "", personalInfo: PersonalInfo(name: "Tobias Renn"))
        await useCase.storeCV(cv)
        let store = InMemoryEditorNoticeStore(notices: [cv.id: .imported(review)])
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)
        await viewModel.loadCV()

        await viewModel.dismissNotice()

        #expect(viewModel.notice == nil)
        #expect(await store.notice(ofCVWithId: cv.id) == nil)
        let reopened = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)
        await reopened.loadCV()
        #expect(reopened.notice == nil)
    }

    @Test("Two loads of one editor that overlap read the notice once, so a dismissal is never undone by the later read")
    func overlappingLoadsDoNotRestoreADismissedNotice() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "", personalInfo: PersonalInfo(name: "Tobias Renn"))
        await useCase.storeCV(cv)
        let store = HeldNoticeStore(notices: [cv.id: .imported(review)])
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)
        let shown = NoticeShown(of: viewModel)

        // The view's task and a retry, say, both load the editor: whichever reads the notice second is held
        let first = Task { await viewModel.loadCV() }
        let second = Task { await viewModel.loadCV() }
        await shown.wait()
        await viewModel.dismissNotice()
        await store.releaseHeld()
        await first.value
        await second.value

        #expect(viewModel.notice == nil, "The notice the person dismissed stays dismissed")
        #expect(await store.kept(ofCVWithId: cv.id) == nil)
        #expect(await store.readCount == 1, "The editor is loaded once")
    }

    @Test("VoiceOver hears that the import's notice is dismissed, over the element it moves to, and nothing when no notice is shown")
    func dismissalIsAnnounced() async {
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: MockCVManagementUseCase(),
            noticeStore: InMemoryEditorNoticeStore()
        )
        let heard = Heard(of: viewModel)

        await viewModel.dismissNotice()
        await viewModel.dismissNotice()

        #expect(heard.kinds == [.noticeDismissed], "The banner and the button that held the focus are gone: the editor says why, once")
        #expect(viewModel.saveAnnouncement?.speaksOverFocusChange == true)
    }

    @Test("A notice dismissed before the imported CV is stored is never kept")
    func noticeDismissedBeforeTheStore() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )

        await viewModel.dismissNotice()
        await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first, "The imported CV is stored as it is")
        #expect(await store.notice(ofCVWithId: stored.id) == nil)
    }

    @Test("Dismissing the notice after the imported CV is stored forgets it")
    func noticeDismissedAfterTheStore() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        await viewModel.saveNow()
        let stored = try #require(await useCase.createdCVs.first)

        await viewModel.dismissNotice()

        #expect(await store.notice(ofCVWithId: stored.id) == nil)
    }

    @Test("The AI draft's notice is not kept: it says nothing to come back to")
    func aiDraftNoticeIsNotKept() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .aiDraft, cvManagementUseCase: useCase, noticeStore: store
        )

        await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(viewModel.notice == .aiDraft, "The editor still shows it")
        #expect(await store.notice(ofCVWithId: stored.id) == nil)
    }

    @Test("The import's notice offers a way to dismiss it; the AI draft's reminder and no notice do not")
    func onlyAKeptNoticeIsDismissible() {
        let useCase = MockCVManagementUseCase()
        let notices: [(EditorNotice?, Bool)] = [
            (.imported(review), true),
            (.importedDescription(review), true),
            (.imported(ImportReview(items: [], notImported: "")), true),
            (.aiDraft, false),
            (.aiDraftUnchecked, false),
            (nil, false),
        ]

        for (notice, dismissible) in notices {
            let viewModel = CVEditorViewModel(
                cvId: nil, initialCV: imported(), notice: notice, cvManagementUseCase: useCase, noticeStore: InMemoryEditorNoticeStore()
            )
            #expect(viewModel.noticeIsDismissible == dismissible, "\(String(describing: notice))")
        }
    }

    // MARK: A notice that cannot be kept

    @Test("When the CV is stored and its notice cannot be kept, the save fails as for the CV, and Retry keeps the notice without storing the CV twice")
    func noticeNotKeptFailsTheSave() async throws {
        let useCase = MockCVManagementUseCase()
        let store = FailingNoticeStore(failures: 1)
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        let heard = Heard(of: viewModel)

        let saved = await viewModel.saveNow()

        #expect(!saved, "The notice is only in memory")
        #expect(viewModel.showsSaveFailure)
        #expect(!viewModel.showsSavedOnDevice)
        #expect(!viewModel.storeHoldsWhatTheFormShows, "Leaving the editor would lose the notice")
        #expect(heard.kinds == [.failed])
        let stored = try #require(await useCase.createdCVs.first, "The CV itself is stored")

        await viewModel.retrySaving()

        #expect(await useCase.createdCVs.count == 1, "The CV is stored once")
        #expect(await useCase.updatedCVs.map(\.id) == [stored.id], "The retry updates the CV the store holds")
        #expect(!viewModel.showsSaveFailure)
        #expect(viewModel.showsSavedOnDevice)
        #expect(viewModel.storeHoldsWhatTheFormShows)
        #expect(heard.kinds == [.failed, .saved])
        #expect(await store.keepAttempts == 2)
        let reopened = CVEditorViewModel(cvId: stored.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)
        await reopened.loadCV()
        #expect(reopened.notice == .imported(review), "The CV opens again with its notice")
    }

    @Test("A notice that could not be kept is kept by the next save")
    func nextSaveKeepsTheNotice() async throws {
        let useCase = MockCVManagementUseCase()
        let store = FailingNoticeStore(failures: 1)
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        await viewModel.saveNow()

        let saved = await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(saved)
        #expect(await useCase.createdCVs.count == 1)
        #expect(await store.notice(ofCVWithId: stored.id) == .imported(review))
        #expect(viewModel.showsSavedOnDevice)
    }

    @Test("A notice dismissed while its keep waits for a retry is never kept, and the retry settles the failure")
    func noticeDismissedWhileItsKeepWaits() async throws {
        let useCase = MockCVManagementUseCase()
        let store = FailingNoticeStore(failures: 1)
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        await viewModel.saveNow()

        await viewModel.dismissNotice()
        await viewModel.retrySaving()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(!viewModel.showsSaveFailure)
        #expect(viewModel.showsSavedOnDevice)
        #expect(await store.notice(ofCVWithId: stored.id) == nil)
        #expect(await store.keepAttempts == 1, "Nothing is left to keep")
    }

    @Test("A CV whose notice keeps failing stays unsaved, retry after retry, and is stored once")
    func noticeThatKeepsFailing() async throws {
        let useCase = MockCVManagementUseCase()
        let store = FailingNoticeStore(failures: 3)
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        let heard = Heard(of: viewModel)

        await viewModel.saveNow()
        await viewModel.retrySaving()
        await viewModel.retrySaving()

        #expect(viewModel.showsSaveFailure)
        #expect(await useCase.createdCVs.count == 1)
        #expect(heard.kinds == [.failed, .failed, .failed], "Each failed write is heard")

        await viewModel.retrySaving()

        #expect(!viewModel.showsSaveFailure)
        #expect(heard.kinds == [.failed, .failed, .failed, .saved])
        let stored = try #require(await useCase.createdCVs.first)
        #expect(await store.notice(ofCVWithId: stored.id) == .imported(review))
    }

    @Test("A CV the store holds while its notice waits to be kept stays to be written, even once it is emptied")
    func emptiedCVWhoseNoticeWaits() async throws {
        let useCase = MockCVManagementUseCase()
        let store = FailingNoticeStore(failures: 1)
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        let heard = Heard(of: viewModel)
        await viewModel.saveNow()

        viewModel.cv.personalInfo = PersonalInfo()

        #expect(viewModel.showsSaveFailure, "The store holds the CV as imported, without its notice")
        #expect(!viewModel.storeHoldsWhatTheFormShows)
        #expect(heard.kinds == [.failed])
        #expect(viewModel.screenTitle == "cv.untitled".localized, "The store holds the CV: it is no longer a new one")

        await viewModel.retrySaving()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(await useCase.createdCVs.count == 1)
        #expect(await useCase.updatedCVs.last?.personalInfo.name == "")
        #expect(!viewModel.showsSaveFailure)
        #expect(viewModel.storeHoldsWhatTheFormShows)
        #expect(heard.kinds == [.failed, .saved])
        #expect(await store.notice(ofCVWithId: stored.id) == .imported(review))
    }
}

// MARK: - What VoiceOver hears

/// The announcements an editor makes, in order.
@MainActor
private final class Heard {
    private(set) var kinds: [SaveAnnouncement.Kind] = []
    private var subscription: AnyCancellable?

    init(of viewModel: CVEditorViewModel) {
        subscription = viewModel.$saveAnnouncement.sink { [weak self] announcement in
            if let announcement { self?.kinds.append(announcement.kind) }
        }
    }
}

// MARK: - Overlapping loads

/// A store whose first read of a notice answers at once and whose later reads wait until `releaseHeld()`, so that the
/// reads of two loads overlap. Each read answers with what the store held when it was asked.
private actor HeldNoticeStore: EditorNoticeStore {
    private var notices: [UUID: EditorNotice]
    private var held: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false
    private(set) var readCount = 0

    init(notices: [UUID: EditorNotice]) {
        self.notices = notices
    }

    func notice(ofCVWithId id: UUID) async -> EditorNotice? {
        readCount += 1
        let notice = notices[id]
        if readCount > 1 && !isReleased {
            await withCheckedContinuation { continuation in
                hold(continuation)
            }
        }
        return notice
    }

    func keep(_ notice: EditorNotice, forCVWithId id: UUID) {
        notices[id] = notice
    }

    func forget(cvWithId id: UUID) {
        notices[id] = nil
    }

    func keptCVIds() -> [UUID] {
        Array(notices.keys)
    }

    /// The notice kept for the CV, without counting as a read.
    func kept(ofCVWithId id: UUID) -> EditorNotice? {
        notices[id]
    }

    /// Answers the reads that wait, and every later read at once.
    func releaseHeld() {
        isReleased = true
        let waiting = held
        held = []
        waiting.forEach { $0.resume() }
    }

    private func hold(_ continuation: CheckedContinuation<Void, Never>) {
        held.append(continuation)
    }
}

// MARK: - A notice that cannot be kept

/// A store whose first `failures` keeps throw, as a full disk would; the keeps after them succeed.
private actor FailingNoticeStore: EditorNoticeStore {
    struct KeepFailed: Error {}

    private var notices: [UUID: EditorNotice] = [:]
    private var failuresLeft: Int
    private(set) var keepAttempts = 0

    init(failures: Int) {
        failuresLeft = failures
    }

    func notice(ofCVWithId id: UUID) -> EditorNotice? {
        notices[id]
    }

    func keep(_ notice: EditorNotice, forCVWithId id: UUID) throws {
        keepAttempts += 1
        if failuresLeft > 0 {
            failuresLeft -= 1
            throw KeepFailed()
        }
        notices[id] = notice
    }

    func forget(cvWithId id: UUID) {
        notices[id] = nil
    }

    func keptCVIds() -> [UUID] {
        Array(notices.keys)
    }
}

/// Returns from `wait()` once the editor shows a notice.
@MainActor
private final class NoticeShown {
    private var isShown = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var subscription: AnyCancellable?

    init(of viewModel: CVEditorViewModel) {
        subscription = viewModel.$notice.sink { [weak self] notice in
            if notice != nil { self?.show() }
        }
    }

    func wait() async {
        guard !isShown else { return }
        await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }

    private func show() {
        isShown = true
        waiter?.resume()
        waiter = nil
    }
}
