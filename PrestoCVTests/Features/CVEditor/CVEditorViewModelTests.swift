import Testing
import Foundation
import Combine
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Mock CVManagementUseCase

actor MockCVManagementUseCase: CVManagementUseCaseProtocol {
    private(set) var createCVCallCount = 0
    private(set) var updateCVCallCount = 0
    private(set) var getCVCallCount = 0
    private(set) var deleteCVCalled = false
    private(set) var getAllCVsCalled = false

    var createCVCalled: Bool { createCVCallCount > 0 }
    var updateCVCalled: Bool { updateCVCallCount > 0 }
    var getCVCalled: Bool { getCVCallCount > 0 }

    private(set) var createdCVs: [CVModel] = []
    private(set) var updatedCVs: [CVModel] = []

    private var storedCVs: [UUID: CVModel] = [:]
    private var createCVResult: Result<CVModel, Error> = .success(CVModel())
    private var getCVResult: Result<CVModel?, Error> = .success(nil)
    private var updateCVError: Error?

    // Configuration methods
    func setCreateCVResult(_ result: Result<CVModel, Error>) {
        self.createCVResult = result
    }

    func setGetCVResult(_ result: Result<CVModel?, Error>) {
        self.getCVResult = result
    }

    func setUpdateCVError(_ error: Error?) {
        self.updateCVError = error
    }

    func storeCV(_ cv: CVModel) {
        storedCVs[cv.id] = cv
    }

    // Protocol implementation
    func createCV(from model: CVModel) async throws -> CVModel {
        createCVCallCount += 1

        switch createCVResult {
        case .success(var cv):
            // Generate a new ID and timestamp
            cv.id = UUID()
            cv.name = model.name
            cv.personalInfo = model.personalInfo
            cv.skills = model.skills
            cv.relevant_experience = model.relevant_experience
            cv.education = model.education
            cv.languages = model.languages
            cv.certifications = model.certifications
            cv.social = model.social
            cv.interests = model.interests

            createdCVs.append(cv)
            storedCVs[cv.id] = cv
            return cv
        case .failure(let error):
            throw error
        }
    }

    /// A new CV the editor stores keeps the id it got when its editing began; it counts as a creation.
    func storeNewCV(_ model: CVModel) async throws -> CVModel {
        createCVCallCount += 1
        if case .failure(let error) = createCVResult {
            throw error
        }
        createdCVs.append(model)
        storedCVs[model.id] = model
        return model
    }

    func updateCV(_ model: CVModel) async throws -> CVModel {
        updateCVCallCount += 1
        if let updateCVError {
            throw updateCVError
        }
        updatedCVs.append(model)
        storedCVs[model.id] = model
        return model
    }

    func getCV(by id: UUID) async throws -> CVModel? {
        getCVCallCount += 1

        switch getCVResult {
        case .success(let cv):
            return cv ?? storedCVs[id]
        case .failure(let error):
            throw error
        }
    }

    func deleteCV(id: UUID) async throws {
        deleteCVCalled = true
        storedCVs.removeValue(forKey: id)
    }

    func getAllCVs() async throws -> [CVModel] {
        getAllCVsCalled = true
        return Array(storedCVs.values)
    }

    func duplicateCV(id: UUID, named name: String) async throws -> CVModel {
        guard let original = storedCVs[id] else {
            throw AppError.notFound("CV with id \(id)")
        }
        var duplicate = original
        duplicate.id = UUID()
        duplicate.name = name
        storedCVs[duplicate.id] = duplicate
        return duplicate
    }
}

// MARK: - Gated CVManagementUseCase

/// Holds the first call of one operation open until the test releases it, so a test can use the editor while a
/// save is running. Later calls return at once, which makes an unwanted second create show up as a count instead of a hang.
actor GatedCVManagementUseCase: CVManagementUseCaseProtocol {
    enum Operation {
        case create
        case update
    }

    private(set) var createCVCallCount = 0
    private(set) var createdCVs: [CVModel] = []
    private(set) var updatedCVs: [CVModel] = []

    private let gatedOperation: Operation
    private let storedCV: CVModel?
    private var gatedCallStarted = false
    private var gateIsOpen = false
    private var gatedCallStartedWaiter: CheckedContinuation<Void, Never>?
    private var gateWaiter: CheckedContinuation<Void, Never>?

    init(gating gatedOperation: Operation = .create, storedCV: CVModel? = nil) {
        self.gatedOperation = gatedOperation
        self.storedCV = storedCV
    }

    func waitUntilGatedCallStarts() async {
        guard !gatedCallStarted else { return }
        await withCheckedContinuation { gatedCallStartedWaiter = $0 }
    }

    func openGate() {
        gateIsOpen = true
        gateWaiter?.resume()
        gateWaiter = nil
    }

    private func holdIfFirstCall(of operation: Operation, callCount: Int) async {
        guard operation == gatedOperation, callCount == 1 else { return }
        gatedCallStarted = true
        gatedCallStartedWaiter?.resume()
        gatedCallStartedWaiter = nil
        if !gateIsOpen {
            await withCheckedContinuation { gateWaiter = $0 }
        }
    }

    func createCV(from template: CVModel) async throws -> CVModel {
        createCVCallCount += 1
        let created = template.copy()
        createdCVs.append(created)
        await holdIfFirstCall(of: .create, callCount: createCVCallCount)
        return created
    }

    func storeNewCV(_ cv: CVModel) async throws -> CVModel {
        createCVCallCount += 1
        createdCVs.append(cv)
        await holdIfFirstCall(of: .create, callCount: createCVCallCount)
        return cv
    }

    func updateCV(_ cv: CVModel) async throws -> CVModel {
        updatedCVs.append(cv)
        await holdIfFirstCall(of: .update, callCount: updatedCVs.count)
        return cv
    }

    func getCV(by id: UUID) async throws -> CVModel? { storedCV }
    func getAllCVs() async throws -> [CVModel] { [] }
    func deleteCV(id: UUID) async throws {}
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { throw AppError.notFound("CV with id \(id)") }
}

private extension ViewState {
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - CVEditorViewModel Tests

@MainActor
@Suite("CVEditorViewModel Tests - the editor saves by itself", .timeLimit(.minutes(1)))
struct CVEditorViewModelTests {

    private func storedCV() -> CVModel {
        CVModel(id: UUID(), name: "Existing CV", personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com"))
    }

    /// An editor of `cv` as it is stored, loaded.
    private func editor(of cv: CVModel, in useCase: CVManagementUseCaseProtocol, clock: ManualClock = ManualClock()) async -> CVEditorViewModel {
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, clock: clock)
        await viewModel.loadCV()
        return viewModel
    }

    // MARK: - New CVs

    @Test("A blank CV left untouched is never stored")
    func untouchedBlankCVIsNotStored() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: mockUseCase)

        await viewModel.loadCV()
        await viewModel.saveNow()

        #expect(await !mockUseCase.createCVCalled)
        #expect(!viewModel.showsSavedOnDevice, "Nothing is stored, so nothing is said to be")
        #expect(viewModel.subtitle.isEmpty, "The bar has no line under the title")
    }

    @Test("A CV started from an example is not stored until it is changed, and then once")
    func exampleIsStoredOnceChanged() async {
        let mockUseCase = MockCVManagementUseCase()
        let example = CVModel(name: "Example", personalInfo: PersonalInfo(name: "John Doe", email: "john@example.com"))
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: example, cvManagementUseCase: mockUseCase)

        await viewModel.saveNow()
        #expect(await !mockUseCase.createCVCalled, "An example opened and left as it is leaves nothing behind")

        viewModel.cv.personalInfo.name = "Maria Rossi"
        await viewModel.saveNow()
        await viewModel.saveNow()

        #expect(await mockUseCase.createdCVs.map(\.personalInfo.name) == ["Maria Rossi"])
        #expect(await mockUseCase.createdCVs.first?.id != example.id, "The new CV has an id of its own")
    }

    @Test("Typing into a new CV stores it a second after the last change, and later changes update the same CV")
    func typingStoresTheNewCVAfterThePause() async {
        let useCase = GatedCVManagementUseCase(gating: .create)
        await useCase.openGate()
        let clock = ManualClock()
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: useCase, clock: clock)

        for name in ["M", "Ma", "Maria"] {
            viewModel.cv.personalInfo.name = name
            clock.advance(by: .milliseconds(100))
        }
        clock.advance(by: .seconds(1))
        await useCase.waitUntilGatedCallStarts()

        #expect(await useCase.createdCVs.map(\.personalInfo.name) == ["Maria"])
        viewModel.cv.personalInfo.title = "Nurse"
        await viewModel.saveNow()
        #expect(await useCase.createCVCallCount == 1, "The CV is created once")
        #expect(await useCase.updatedCVs.map(\.id) == [viewModel.cv.id], "Later changes update the CV that was created")
    }

    @Test("A draft made by AI is stored as it is, without a change")
    func draftIsStoredAsItIs() async {
        let mockUseCase = MockCVManagementUseCase()
        let draft = CVModel(name: "Drafted", personalInfo: PersonalInfo(name: "Lena Hartmann"))
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: draft, notice: .aiDraft, cvManagementUseCase: mockUseCase)

        await viewModel.saveNow()

        #expect(viewModel.notice == .aiDraft)
        #expect(await mockUseCase.createdCVs.map(\.personalInfo.name) == ["Lena Hartmann"])
        #expect(viewModel.showsSavedOnDevice)
    }

    @Test("A CV imported from the person's text is stored as it is, and keeps its notice with what to check and the text not imported")
    func importedCVIsStoredAsItIs() async {
        let mockUseCase = MockCVManagementUseCase()
        let imported = CVModel(personalInfo: PersonalInfo(name: "Lena Hartmann", title: "Pflegefachfrau"))
        let review = ImportReview(
            items: [ImportReview.Item(field: .title, reason: .byPosition, text: "Pflegefachfrau")],
            notImported: "Geburtsdatum: 14.05.1992"
        )
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: imported, notice: .imported(review), cvManagementUseCase: mockUseCase)

        await viewModel.saveNow()

        #expect(await mockUseCase.createdCVs.map(\.personalInfo) == [imported.personalInfo], "Nothing waits for a change")
        #expect(await mockUseCase.createdCVs.first?.id != imported.id, "The imported CV gets an id of its own")
        #expect(viewModel.notice == .imported(review))
        #expect(viewModel.notice?.review?.notImported == "Geburtsdatum: 14.05.1992")
        #expect(viewModel.showsSavedOnDevice)
    }

    @Test("A CV imported and left at once is stored once, however often the editor is left")
    func importedCVLeftAtOnceIsStoredOnce() async {
        let mockUseCase = MockCVManagementUseCase()
        let imported = CVModel(personalInfo: PersonalInfo(name: "Lena Hartmann"))
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported, notice: .imported(ImportReview(items: [], notImported: "")), cvManagementUseCase: mockUseCase
        )

        #expect(await viewModel.saveBeforeLeaving())
        #expect(await viewModel.saveBeforeLeaving())

        #expect(await mockUseCase.createCVCallCount == 1)
        #expect(await !mockUseCase.updateCVCalled, "Nothing changed after it was stored")
    }

    // MARK: - Stored CVs

    @Test("A stored CV that is not changed is never written, so its edit time stays")
    func unchangedCVIsNeverWritten() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        let viewModel = await editor(of: existing, in: mockUseCase)

        await viewModel.sceneDidChange(isActive: false)
        await viewModel.saveNow()

        #expect(await !mockUseCase.updateCVCalled)
        #expect(viewModel.showsSavedOnDevice, "The CV is stored on this device")
        #expect(viewModel.subtitle == "editor.saved".localized, "The line under the title says so")
    }

    @Test("Going to the background stores the change at once, without waiting for the pause")
    func backgroundStoresAtOnce() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        let viewModel = await editor(of: existing, in: mockUseCase)

        viewModel.cv.personalInfo.phone = "+39 333 1234567"
        await viewModel.sceneDidChange(isActive: true)
        #expect(await !mockUseCase.updateCVCalled, "Coming to the foreground stores nothing")
        await viewModel.sceneDidChange(isActive: false)

        #expect(await mockUseCase.updatedCVs.map(\.personalInfo.phone) == ["+39 333 1234567"])
    }

    @Test("The language chosen for the PDF is stored by itself, with no question to answer")
    func documentLanguageIsStoredByItself() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        let viewModel = await editor(of: existing, in: mockUseCase)

        viewModel.documentLanguageSelection = .german
        await viewModel.saveNow()

        #expect(await mockUseCase.updatedCVs.map(\.documentLanguage) == ["de"])
    }

    // MARK: - Failures

    @Test("A failed save is shown and keeps the edits; Try Again stores them")
    func failedSaveCanBeRetried() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let viewModel = await editor(of: existing, in: mockUseCase)

        viewModel.cv.personalInfo.location = "Bologna"
        await viewModel.saveNow()

        #expect(viewModel.showsSaveFailure)
        #expect(!viewModel.showsSavedOnDevice, "A failed save is not said to be saved")
        #expect(viewModel.subtitle.isEmpty, "The banner says what happened, not the line under the title")
        #expect(viewModel.cv.personalInfo.location == "Bologna", "The edits stay in the editor")
        #expect(viewModel.saveAnnouncement?.text == "editor.save_failed".localized, "VoiceOver hears the failure")

        await mockUseCase.setUpdateCVError(nil)
        await viewModel.retrySaving()

        #expect(!viewModel.showsSaveFailure)
        #expect(viewModel.showsSavedOnDevice)
        #expect(viewModel.saveAnnouncement?.text == "editor.saved".localized, "VoiceOver hears that the CV is saved again")
        #expect(await mockUseCase.updatedCVs.map(\.personalInfo.location) == ["Bologna"])
    }

    @Test("A new CV whose first save fails is created by the next one")
    func failedCreateIsRetried() async {
        let mockUseCase = MockCVManagementUseCase()
        await mockUseCase.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: mockUseCase)

        viewModel.cv.personalInfo.name = "Jane Doe"
        await viewModel.saveNow()
        #expect(viewModel.showsSaveFailure)
        #expect(!viewModel.showsSavedOnDevice, "A CV the store does not hold is not said to be saved")

        await mockUseCase.setCreateCVResult(.success(CVModel()))
        await viewModel.retrySaving()

        #expect(await mockUseCase.createdCVs.map(\.personalInfo.name) == ["Jane Doe"])
        #expect(await !mockUseCase.updateCVCalled, "The first successful save creates the CV")
    }

    @Test("After a failed save, the next change tries again, and its success takes the failure away")
    func nextChangeRetriesAFailedSave() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let viewModel = await editor(of: existing, in: mockUseCase)
        viewModel.cv.personalInfo.location = "Bologna"
        await viewModel.saveNow()
        #expect(viewModel.showsSaveFailure)

        await mockUseCase.setUpdateCVError(nil)
        viewModel.cv.personalInfo.location = "Bologna, Italy"
        #expect(viewModel.showsSaveFailure, "The failure stays until a save succeeds")
        await viewModel.saveNow()

        #expect(!viewModel.showsSaveFailure)
        #expect(await mockUseCase.updatedCVs.map(\.personalInfo.location) == ["Bologna, Italy"])
    }

    @Test("Saving before another screen takes the editor's place tells whether the store holds the edits")
    func savingBeforeLeavingTellsTheOutcome() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let viewModel = await editor(of: existing, in: mockUseCase)

        #expect(await viewModel.saveBeforeLeaving(), "Nothing changed: there is nothing to store")

        viewModel.cv.personalInfo.location = "Bologna"
        #expect(await !viewModel.saveBeforeLeaving(), "The edits are only in the editor")
        #expect(viewModel.showsSaveFailure)

        await mockUseCase.setUpdateCVError(nil)
        #expect(await viewModel.saveBeforeLeaving())
        #expect(await mockUseCase.updatedCVs.map(\.personalInfo.location) == ["Bologna"])
    }

    // MARK: - What VoiceOver hears

    /// The announcements an editor makes, in order.
    private final class Heard {
        private(set) var kinds: [SaveAnnouncement.Kind] = []
        private var subscription: AnyCancellable?

        @MainActor
        init(_ viewModel: CVEditorViewModel) {
            subscription = viewModel.$saveAnnouncement.sink { [self] announcement in
                if let announcement { kinds.append(announcement.kind) }
            }
        }
    }

    @Test("VoiceOver hears every failed write, nothing when a retry starts, and that the CV is saved once a write succeeds")
    func announcementsFollowTheOutcomesOfTheWrites() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let viewModel = await editor(of: existing, in: mockUseCase)
        let heard = Heard(viewModel)

        viewModel.cv.personalInfo.location = "Bologna"
        await viewModel.saveNow()
        #expect(heard.kinds == [.failed])

        await viewModel.retrySaving()
        #expect(heard.kinds == [.failed, .failed], "A retry that fails again is told again, and its start was not told as a success")

        await mockUseCase.setUpdateCVError(nil)
        await viewModel.retrySaving()
        #expect(heard.kinds == [.failed, .failed, .saved], "Saved is told once, when a write has succeeded")
    }

    @Test("A CV that never failed to save is saved without a word: there is nothing to recover from")
    func savingWithoutAFailureIsSilent() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        let viewModel = await editor(of: existing, in: mockUseCase)
        let heard = Heard(viewModel)

        viewModel.cv.personalInfo.location = "Bologna"
        await viewModel.saveNow()

        #expect(heard.kinds.isEmpty)
        #expect(viewModel.showsSavedOnDevice)
    }

    // MARK: - A failure that no longer matters

    @Test("A failure goes when the form returns to what the store holds, and the editor can be left again")
    func failureGoesWhenTheFormIsBackInTheStore() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let viewModel = await editor(of: existing, in: mockUseCase)
        let heard = Heard(viewModel)
        viewModel.cv.personalInfo.location = "Bologna"
        await viewModel.saveNow()
        #expect(viewModel.showsSaveFailure)

        viewModel.cv.personalInfo.location = existing.personalInfo.location

        #expect(!viewModel.showsSaveFailure, "The store holds what the form shows: there is nothing to retry")
        #expect(viewModel.showsSavedOnDevice)
        #expect(heard.kinds == [.failed, .saved])
        #expect(await viewModel.saveBeforeLeaving(), "Leaving, and opening a PDF over the editor, are allowed again")
        #expect(await mockUseCase.updatedCVs.isEmpty, "Nothing is written: the store already holds this")
    }

    @Test("A new CV emptied again after a failed first write needs nothing stored, and the failure goes")
    func failureGoesWhenANewCVIsEmptiedAgain() async {
        let mockUseCase = MockCVManagementUseCase()
        await mockUseCase.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "Jane Doe"
        await viewModel.saveNow()
        #expect(viewModel.showsSaveFailure)

        viewModel.cv.personalInfo.name = ""

        #expect(!viewModel.showsSaveFailure)
        #expect(await viewModel.saveBeforeLeaving())
        #expect(await mockUseCase.createdCVs.isEmpty)
    }

    // MARK: - Changes while a write runs

    @Test("A change that undoes the write in progress is stored too: leaving reports success only when the store holds the form")
    func changeUndoingTheWriteInProgressIsStored() async {
        let existing = storedCV()
        let useCase = GatedCVManagementUseCase(gating: .update, storedCV: existing)
        let viewModel = CVEditorViewModel(cvId: existing.id.uuidString, cvManagementUseCase: useCase)
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+39 333 1234567"

        let leaving = Task { await viewModel.saveBeforeLeaving() }
        await useCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.phone = existing.personalInfo.phone
        await useCase.openGate()

        #expect(await leaving.value, "Leaving returns once the store holds what the form shows")
        #expect(await useCase.updatedCVs.map(\.personalInfo.phone) == ["+39 333 1234567", existing.personalInfo.phone])
        #expect(viewModel.showsSavedOnDevice)
    }

    @Test("A change made while leaving writes is stored before leaving reports success")
    func changeMadeWhileLeavingIsStored() async {
        let existing = storedCV()
        let useCase = GatedCVManagementUseCase(gating: .update, storedCV: existing)
        let viewModel = CVEditorViewModel(cvId: existing.id.uuidString, cvManagementUseCase: useCase)
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+39 333 1234567"

        let leaving = Task { await viewModel.saveBeforeLeaving() }
        await useCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.location = "Bologna"
        await useCase.openGate()

        #expect(await leaving.value)
        #expect(await useCase.updatedCVs.last?.personalInfo.location == "Bologna", "What the person typed last is stored")
    }

    // MARK: - Why a write failed

    @Test("The cause of each failed write is reported, apart from the banner")
    func failedWritesAreReportedWithTheirCause() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let reports = SaveFailureLog()
        let viewModel = CVEditorViewModel(
            cvId: existing.id.uuidString, cvManagementUseCase: mockUseCase, reportSaveFailure: { reports.record($0) }
        )
        await viewModel.loadCV()
        viewModel.cv.personalInfo.location = "Bologna"

        await viewModel.saveNow()
        await viewModel.retrySaving()

        #expect(reports.causes == [AppError.fileSystemError("disk full"), AppError.fileSystemError("disk full")])
    }

    // MARK: - Reading after the editor before

    @Test("A stored CV is read only after the editors that were left have stored what they showed")
    func storedCVIsReadAfterTheLeftEditors() async {
        let existing = storedCV()
        let mockUseCase = MockCVManagementUseCase()
        await mockUseCase.storeCV(existing)
        let gate = Gate()
        let viewModel = CVEditorViewModel(
            cvId: existing.id.uuidString, cvManagementUseCase: mockUseCase, awaitLeftEditors: { await gate.wait() }
        )

        let loading = Task { await viewModel.loadCV() }
        await gate.waitUntilSomeoneWaits()
        #expect(await !mockUseCase.getCVCalled, "The CV is not read while an editor that was just left is storing it")

        await gate.open()
        await loading.value

        #expect(await mockUseCase.getCVCalled)
        #expect(viewModel.cv.id == existing.id)
    }

    // MARK: - When the editor can be left at once

    @Test("The edge swipe may leave at once only when the store holds what the form shows")
    func storeHoldsWhatTheFormShowsOnlyWhenNothingIsToStore() async {
        let mockUseCase = MockCVManagementUseCase()
        let existing = storedCV()
        await mockUseCase.storeCV(existing)
        let viewModel = await editor(of: existing, in: mockUseCase)
        #expect(viewModel.storeHoldsWhatTheFormShows, "Nothing changed")

        viewModel.cv.personalInfo.phone = "+39 333 1234567"
        #expect(!viewModel.storeHoldsWhatTheFormShows, "A change waits for its pause")

        await viewModel.saveNow()
        #expect(viewModel.storeHoldsWhatTheFormShows, "The change is stored")

        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        viewModel.cv.personalInfo.phone = "+39 333 7654321"
        await viewModel.saveNow()
        #expect(!viewModel.storeHoldsWhatTheFormShows, "The change could not be stored")
    }

    @Test("A blank new CV has nothing to store, so it may be left at once")
    func blankNewCVMayBeLeftAtOnce() {
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: MockCVManagementUseCase())
        #expect(viewModel.storeHoldsWhatTheFormShows)
    }

    // MARK: - Saves in progress

    @Test("Edits made while a save runs are kept, and stored after it under the same CV")
    func editsDuringASaveAreStoredAfterIt() async {
        let useCase = GatedCVManagementUseCase(gating: .create)
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: useCase)
        viewModel.cv.personalInfo.name = "Jane"

        let firstSave = Task { await viewModel.saveNow() }
        await useCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.name = "Jane Doe"
        #expect(viewModel.viewState.isLoaded, "The form stays in use while the store works")
        await useCase.openGate()
        await firstSave.value
        await viewModel.saveNow()

        #expect(await useCase.createCVCallCount == 1)
        #expect(await useCase.updatedCVs.map(\.personalInfo.name) == ["Jane Doe"])
        #expect(viewModel.cv.personalInfo.name == "Jane Doe")
    }

    // MARK: - Content

    @Test("An empty CV has no meaningful content, and one with personal details has")
    func meaningfulContent() {
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: MockCVManagementUseCase())
        #expect(!viewModel.hasMeaningfulContent)

        viewModel.cv.personalInfo.name = "John Doe"
        #expect(viewModel.hasMeaningfulContent)
    }

    @Test("A new CV is shown at once")
    func newCVStartsLoaded() async {
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: MockCVManagementUseCase())
        #expect(viewModel.viewState.isLoaded)

        await viewModel.loadCV()
        #expect(viewModel.viewState.isLoaded)
    }

    // MARK: - Loading

    @Test("Loading an existing CV twice reads it once and keeps the edits")
    func loadingExistingCVTwiceReadsOnce() async {
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = storedCV()
        await mockUseCase.storeCV(existingCV)
        let viewModel = CVEditorViewModel(cvId: existingCV.id.uuidString, cvManagementUseCase: mockUseCase)

        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"
        await viewModel.loadCV()

        #expect(await mockUseCase.getCVCallCount == 1, "A CV already loaded must not be read again")
        #expect(viewModel.cv.personalInfo.phone == "+1234567890", "A second load must not drop the edits")
    }

    @Test("A CV deleted before its editor opens is reported as not found")
    func deletedCVIsNotFound() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: UUID().uuidString, cvManagementUseCase: mockUseCase)

        await viewModel.loadCV()

        #expect(viewModel.viewState.errorMessage == AppError.notFound("error.subject.cv".localized).localizedDescription)
        #expect(await mockUseCase.getCVCallCount == 1)
    }

    @Test("A failed load shows the error and a retry reads the CV again")
    func failedLoadCanBeRetried() async {
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = storedCV()
        await mockUseCase.storeCV(existingCV)
        await mockUseCase.setGetCVResult(.failure(AppError.fileSystemError("unreadable")))
        let viewModel = CVEditorViewModel(cvId: existingCV.id.uuidString, cvManagementUseCase: mockUseCase)

        await viewModel.loadCV()
        #expect(viewModel.viewState.isError)
        await viewModel.saveNow()
        #expect(await !mockUseCase.updateCVCalled, "A CV that could not be read is never written")

        await mockUseCase.setGetCVResult(.success(nil))
        await viewModel.loadCV()

        #expect(viewModel.viewState.isLoaded)
        #expect(viewModel.cv.name == "Existing CV")
        #expect(await mockUseCase.getCVCallCount == 2)
    }
}

// MARK: - Test Helpers

/// The causes a view model was told of.
@MainActor
final class SaveFailureLog {
    private(set) var causes: [AppError] = []

    func record(_ cause: any Error) {
        causes.append(cause as? AppError ?? .unknown("\(cause)"))
    }
}

/// A wait that ends when a test opens it.
@MainActor
final class Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var arrivals: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        arrivals.forEach { $0.resume() }
        arrivals = []
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Returns once someone is waiting at the gate.
    func waitUntilSomeoneWaits() async {
        guard waiters.isEmpty else { return }
        await withCheckedContinuation { arrivals.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
