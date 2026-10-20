import Testing
import Foundation
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

    func duplicateCV(id: UUID) async throws -> CVModel {
        guard let original = storedCVs[id] else {
            throw AppError.notFound("CV with id \(id)")
        }
        var duplicate = original
        duplicate.id = UUID()
        duplicate.name = "\(original.name) Copy"
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
    func duplicateCV(id: UUID) async throws -> CVModel { throw AppError.notFound("CV with id \(id)") }
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
@Suite("CVEditorViewModel Tests - CV Creation and Discard")
struct CVEditorViewModelTests {

    // MARK: - Bug Fix: CV Not Created on Discard

    @Test("New CV with empty template is not created until explicitly saved")
    func newCVNotCreatedUntilSaved() async throws {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When - User opens editor but doesn't save
        await viewModel.loadCV()

        // Then - createCV should NOT have been called
        #expect(await !mockUseCase.createCVCalled, "createCV should not be called until user explicitly saves")
        #expect(await mockUseCase.createdCVs.isEmpty, "No CVs should be created without explicit save")
    }

    @Test("New CV with template is not created until explicitly saved")
    func newCVFromTemplateNotCreatedUntilSaved() async throws {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let template = CVModel(
            name: "Sample Template",
            personalInfo: PersonalInfo(name: "John Doe", email: "john@example.com")
        )

        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: template,
            cvManagementUseCase: mockUseCase
        )

        // When - User opens editor with template but doesn't save
        await viewModel.loadCV()

        // Then - createCV should NOT have been called
        #expect(await !mockUseCase.createCVCalled, "createCV should not be called until user explicitly saves")
        #expect(await mockUseCase.createdCVs.isEmpty, "No CVs should be created without explicit save")
    }

    @Test("CV is created only when user explicitly saves")
    func cvCreatedOnExplicitSave() async throws {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // Add some content to make it saveable
        viewModel.cv.personalInfo.name = "John Doe"
        viewModel.cv.personalInfo.email = "john@example.com"

        // When - User explicitly saves
        let saved = await viewModel.saveCV()

        // Then - CV should be created
        #expect(saved == true, "Save should succeed")
        #expect(await mockUseCase.createCVCalled, "createCV should be called on save")
        #expect(await mockUseCase.createdCVs.count == 1, "Exactly one CV should be created")
    }

    @Test("Discarding empty CV does not create CV in storage")
    func discardEmptyCVDoesNotCreate() async throws {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        await viewModel.loadCV()

        // When - User cancels/discards (simulating the discard flow)
        viewModel.confirmCancel()

        // Then - No CV should be created
        #expect(await !mockUseCase.createCVCalled, "createCV should never be called on discard")
        #expect(await mockUseCase.createdCVs.isEmpty, "No CVs should exist after discard")
    }

    @Test("Discarding CV with changes does not create CV in storage")
    func discardCVWithChangesDoesNotCreate() async throws {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // Add some changes
        viewModel.cv.personalInfo.name = "Jane Doe"
        viewModel.cv.personalInfo.email = "jane@example.com"

        // When - User discards changes
        viewModel.confirmCancel()

        // Then - No CV should be created
        #expect(await !mockUseCase.createCVCalled, "createCV should not be called even with changes")
        #expect(await mockUseCase.createdCVs.isEmpty, "No CVs should exist after discard with changes")
    }

    // MARK: - Cancel Behavior Tests

    @Test("requestLeaving returns true when no unsaved changes")
    func handleCancelWithNoChanges() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When - CV is empty (no meaningful content)
        let shouldNavigate = viewModel.requestLeaving()

        // Then - Should return true (navigate immediately) and not show confirmation
        #expect(shouldNavigate == true, "Should navigate immediately when no changes")
        #expect(viewModel.showingCancelConfirmation == false, "Should not show confirmation dialog")
    }

    @Test("requestLeaving shows confirmation when there are unsaved changes")
    func handleCancelWithChanges() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // Add meaningful content
        viewModel.cv.personalInfo.name = "John Doe"

        // When
        let shouldNavigate = viewModel.requestLeaving()

        // Then - Should show confirmation and not navigate immediately
        #expect(shouldNavigate == false, "Should not navigate immediately with changes")
        #expect(viewModel.showingCancelConfirmation == true, "Should show confirmation dialog")
    }

    // MARK: - CV Update Tests (Existing CV)

    @Test("Existing CV is updated, not created")
    func existingCVIsUpdated() async throws {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // Load the existing CV
        await viewModel.loadCV()

        // When - User modifies and saves
        viewModel.cv.personalInfo.email = "jane@example.com"
        let saved = await viewModel.saveCV()

        // Then - CV should be updated, not created
        #expect(saved == true)
        #expect(await mockUseCase.updateCVCalled, "updateCV should be called for existing CV")
        #expect(await !mockUseCase.createCVCalled, "createCV should not be called for existing CV")
    }

    // MARK: - Meaningful Content Tests

    @Test("Empty CV has no meaningful content")
    func emptyCVHasNoMeaningfulContent() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // Then
        #expect(viewModel.hasMeaningfulContent == false)
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("CV with personal info has meaningful content")
    func cvWithPersonalInfoHasMeaningfulContent() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When
        viewModel.cv.personalInfo.name = "John Doe"

        // Then
        #expect(viewModel.hasMeaningfulContent == true)
        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test("Cannot save CV without meaningful content")
    func cannotSaveWithoutMeaningfulContent() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When - Try to save empty CV
        let saved = await viewModel.saveCV()

        // Then
        #expect(saved == false, "Should not save CV without meaningful content")
        #expect(await !mockUseCase.createCVCalled, "createCV should not be called")
    }

    // MARK: - View State Tests

    @Test("New CV starts in loaded state")
    func newCVStartsInLoadedState() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When
        await viewModel.loadCV()

        // Then
        if case .loaded = viewModel.viewState {
            // Success
        } else {
            Issue.record("Expected loaded state for new CV")
        }
    }

    @Test("Save button is disabled without meaningful content")
    func saveButtonDisabledWithoutContent() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // Then
        #expect(viewModel.isSaveButtonEnabled == false)
    }

    @Test("Save button is enabled with meaningful content")
    func saveButtonEnabledWithContent() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When
        viewModel.cv.personalInfo.name = "John Doe"

        // Then
        #expect(viewModel.isSaveButtonEnabled == true)
    }

    // MARK: - No Changes Save Behavior Tests

    @Test("Existing CV without changes - save button is disabled")
    func existingCVWithoutChanges_SaveButtonDisabled() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load existing CV without making changes
        await viewModel.loadCV()

        // Then - Save button should be disabled
        #expect(viewModel.hasUnsavedChanges == false, "Should have no unsaved changes")
        #expect(viewModel.hasMeaningfulContent == true, "Should have meaningful content")
        #expect(viewModel.isSaveButtonEnabled == false, "Save button should be disabled without changes")
    }

    @Test("Existing CV without changes - saveCV returns false")
    func existingCVWithoutChanges_SaveCVReturnsFalse() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load existing CV and try to save without changes
        await viewModel.loadCV()
        let saved = await viewModel.saveCV()

        // Then - Save should return false
        #expect(saved == false, "saveCV should return false when there are no changes")
        #expect(await !mockUseCase.updateCVCalled, "updateCV should not be called when there are no changes")
    }

    @Test("Existing CV without changes - no save confirmation")
    func existingCVWithoutChanges_NoSaveConfirmation() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load existing CV and tap save without changes
        await viewModel.loadCV()
        await viewModel.handleSaveButtonTap()

        // Then - Confirmation should NOT be shown
        #expect(viewModel.showsSavedConfirmation == false, "Save confirmation should not be shown without changes")
    }

    @Test("Existing CV with changes - save button is enabled")
    func existingCVWithChanges_SaveButtonEnabled() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load existing CV and make changes
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"

        // Then - Save button should be enabled
        #expect(viewModel.hasUnsavedChanges == true, "Should have unsaved changes")
        #expect(viewModel.isSaveButtonEnabled == true, "Save button should be enabled with changes")
    }

    @Test("Existing CV with changes - saveCV returns true and shows confirmation")
    func existingCVWithChanges_SaveCVReturnsTrue() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load existing CV, make changes, and save
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"
        let saved = await viewModel.saveCV()

        // Then - Save should succeed
        #expect(saved == true, "saveCV should return true when there are changes")
        #expect(await mockUseCase.updateCVCalled, "updateCV should be called when there are changes")
    }

    @Test("Existing CV with changes - save confirmation is shown")
    func existingCVWithChanges_SaveConfirmationShown() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load existing CV, make changes, and tap save
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"
        await viewModel.handleSaveButtonTap()

        // Then - Confirmation SHOULD be shown
        #expect(viewModel.showsSavedConfirmation == true, "Save confirmation should be shown with changes")
    }

    @Test("After saving - no unsaved changes and save button disabled")
    func afterSaving_NoUnsavedChanges() async {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)

        let viewModel = CVEditorViewModel(
            cvId: existingCV.id.uuidString,
            cvManagementUseCase: mockUseCase
        )

        // When - Load, modify, save, then check state
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"
        _ = await viewModel.saveCV()

        // Then - After save, no unsaved changes and save button disabled
        #expect(viewModel.hasUnsavedChanges == false, "Should have no unsaved changes after save")
        #expect(viewModel.isSaveButtonEnabled == false, "Save button should be disabled after save")
    }

    // MARK: - Saving a new CV more than once

    @Test("Saving a new CV twice creates it once and then updates the same CV")
    func savingNewCVTwiceCreatesOnceThenUpdates() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        let firstSaved = await viewModel.saveCV()
        viewModel.cv.personalInfo.email = "john@example.com"
        let secondSaved = await viewModel.saveCV()

        #expect(firstSaved == true)
        #expect(secondSaved == true)
        #expect(await mockUseCase.createCVCallCount == 1, "The second save must not create another CV")
        #expect(await mockUseCase.updateCVCallCount == 1, "The second save updates the CV the first one created")
        let createdId = await mockUseCase.createdCVs.first?.id
        #expect(await mockUseCase.updatedCVs.first?.id == createdId, "Both saves must target the same CV")
        #expect(await mockUseCase.updatedCVs.first?.personalInfo.email == "john@example.com")
    }

    @Test("A new CV has no unsaved changes after it is saved")
    func newCVHasNoUnsavedChangesAfterSave() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        _ = await viewModel.saveCV()

        #expect(viewModel.hasUnsavedChanges == false)
        #expect(viewModel.isSaveButtonEnabled == false)
    }

    @Test("Editing a saved new CV makes the changes unsaved again")
    func editingSavedNewCVMakesChangesUnsavedAgain() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"
        _ = await viewModel.saveCV()

        viewModel.cv.personalInfo.phone = "+1234567890"

        #expect(viewModel.hasUnsavedChanges == true)
        #expect(viewModel.isSaveButtonEnabled == true)
    }

    @Test("Saving a new CV again without edits does nothing")
    func savingSavedNewCVWithoutEditsDoesNothing() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"
        _ = await viewModel.saveCV()

        let saved = await viewModel.saveCV()

        #expect(saved == false)
        #expect(await mockUseCase.createCVCallCount == 1)
        #expect(await mockUseCase.updateCVCallCount == 0)
    }

    // MARK: - Save in progress

    @Test("A save in progress keeps the editor loaded, disables Save and ignores a second save")
    func saveInProgressKeepsEditorAndIgnoresSecondSave() async {
        let gatedUseCase = GatedCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: gatedUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        let firstSave = Task { await viewModel.saveCV() }
        await gatedUseCase.waitUntilGatedCallStarts()

        #expect(viewModel.isSaving == true)
        #expect(viewModel.viewState.isLoaded, "The editor must not be replaced by a spinner while saving")
        #expect(viewModel.isSaveButtonEnabled == false)

        let secondSave = await viewModel.saveCV()
        #expect(secondSave == false, "A save started while another is running must be ignored")

        await gatedUseCase.openGate()
        #expect(await firstSave.value == true)
        #expect(viewModel.isSaving == false)
        #expect(await gatedUseCase.createCVCallCount == 1, "The CV must be created once")
    }

    @Test("Edits made while a new CV is being created are kept, unsaved, and the next save updates the same CV")
    func editsDuringCreateAreKept() async {
        let gatedUseCase = GatedCVManagementUseCase(gating: .create)
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: gatedUseCase)
        viewModel.cv.personalInfo.name = "John Doe"
        viewModel.cv.skills = [Skill(name: "Swift"), Skill(name: "Kotlin")]

        let saving = Task { await viewModel.saveCV() }
        await gatedUseCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.email = "john@example.com"
        viewModel.removeSkill(at: 1)
        await gatedUseCase.openGate()
        #expect(await saving.value == true)

        let createdId = await gatedUseCase.createdCVs.first?.id
        #expect(viewModel.cv.personalInfo.email == "john@example.com", "An edit made during the save must survive it")
        #expect(viewModel.cv.skills.map(\.name) == ["Swift"], "A row deleted during the save must stay deleted")
        #expect(viewModel.cv.id == createdId, "The form adopts the id the store gave the new CV")
        #expect(viewModel.hasUnsavedChanges == true, "What was not submitted is not saved")

        #expect(await viewModel.saveCV() == true)
        #expect(await gatedUseCase.createCVCallCount == 1, "The next save must not create the CV again")
        #expect(await gatedUseCase.updatedCVs.map(\.id) == [createdId], "The next save updates the CV that was created")
        #expect(await gatedUseCase.updatedCVs.first?.personalInfo.email == "john@example.com")
        #expect(await gatedUseCase.updatedCVs.first?.skills.map(\.name) == ["Swift"])
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("Edits made while a stored CV is being updated are kept, unsaved, and the next save updates the same CV")
    func editsDuringUpdateAreKept() async {
        let storedCV = CVModel(
            id: UUID(),
            name: "Stored CV",
            personalInfo: PersonalInfo(name: "Jane Doe"),
            skills: [Skill(name: "Swift"), Skill(name: "Kotlin")]
        )
        let gatedUseCase = GatedCVManagementUseCase(gating: .update, storedCV: storedCV)
        let viewModel = CVEditorViewModel(cvId: storedCV.id.uuidString, cvManagementUseCase: gatedUseCase)
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"

        let saving = Task { await viewModel.saveCV() }
        await gatedUseCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.email = "jane@example.com"
        viewModel.removeSkill(at: 0)
        await gatedUseCase.openGate()
        #expect(await saving.value == true)

        #expect(viewModel.cv.personalInfo.email == "jane@example.com", "An edit made during the save must survive it")
        #expect(viewModel.cv.skills.map(\.name) == ["Kotlin"], "A row deleted during the save must stay deleted")
        #expect(viewModel.cv.id == storedCV.id)
        #expect(viewModel.hasUnsavedChanges == true, "What was not submitted is not saved")

        #expect(await viewModel.saveCV() == true)
        #expect(await gatedUseCase.createCVCallCount == 0)
        #expect(await gatedUseCase.updatedCVs.map(\.id) == [storedCV.id, storedCV.id], "Both saves update the stored CV")
        #expect(await gatedUseCase.updatedCVs.first?.personalInfo.phone == "+1234567890")
        #expect(await gatedUseCase.updatedCVs.first?.personalInfo.email == "", "The first save submitted what was on screen then")
        #expect(await gatedUseCase.updatedCVs.last?.personalInfo.email == "jane@example.com")
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("An edit made during a save and undone before it returns leaves nothing unsaved")
    func undoneEditDuringSaveLeavesNothingUnsaved() async {
        let gatedUseCase = GatedCVManagementUseCase(gating: .create)
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: gatedUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        let saving = Task { await viewModel.saveCV() }
        await gatedUseCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.email = "john@example.com"
        viewModel.cv.personalInfo.email = ""
        await gatedUseCase.openGate()
        #expect(await saving.value == true)

        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test("A save that returns after edits were made confirms nothing, and leaving asks first")
    func editsDuringCreateOfferNoSuccessDialog() async {
        let gatedUseCase = GatedCVManagementUseCase(gating: .create)
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: gatedUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        let saving = Task { await viewModel.handleSaveButtonTap() }
        await gatedUseCase.waitUntilGatedCallStarts()
        viewModel.cv.personalInfo.email = "john@example.com"
        await gatedUseCase.openGate()
        await saving.value

        #expect(viewModel.showsSavedConfirmation == false, "Saying the CV is saved would hide the edit made during the save")
        #expect(viewModel.hasUnsavedChanges == true)
        #expect(viewModel.isSaveButtonEnabled == true, "Save stays available for what was not stored")
        #expect(viewModel.requestLeaving() == false, "Leaving must ask first")
        #expect(viewModel.showingCancelConfirmation == true)

        viewModel.showingCancelConfirmation = false
        await viewModel.handleSaveButtonTap()

        #expect(await gatedUseCase.updatedCVs.last?.personalInfo.email == "john@example.com", "Saving again stores the edit")
        #expect(viewModel.showsSavedConfirmation == true, "The confirmation is shown once the form is clean")
        #expect(viewModel.requestLeaving() == true)
    }

    @Test("Updating a stored CV that is edited meanwhile confirms nothing, and leaving asks first")
    func editsDuringUpdateOfferNoSuccessDialog() async {
        let storedCV = CVModel(id: UUID(), name: "Stored CV", personalInfo: PersonalInfo(name: "Jane Doe"))
        let gatedUseCase = GatedCVManagementUseCase(gating: .update, storedCV: storedCV)
        let viewModel = CVEditorViewModel(cvId: storedCV.id.uuidString, cvManagementUseCase: gatedUseCase)
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"

        let saving = Task { await viewModel.handleSaveButtonTap() }
        await gatedUseCase.waitUntilGatedCallStarts()
        viewModel.cv.skills = [Skill(name: "Swift")]
        await gatedUseCase.openGate()
        await saving.value

        #expect(viewModel.showsSavedConfirmation == false)
        #expect(viewModel.isSaveButtonEnabled == true)
        #expect(viewModel.requestLeaving() == false)
        #expect(viewModel.showingCancelConfirmation == true)

        viewModel.showingCancelConfirmation = false
        await viewModel.handleSaveButtonTap()

        #expect(await gatedUseCase.updatedCVs.last?.skills.map(\.name) == ["Swift"], "Saving again stores the edit")
        #expect(viewModel.showsSavedConfirmation == true)
    }

    @Test("A save with no edits meanwhile confirms it and Done leaves without asking")
    func cleanSaveOffersSuccessDialogAndLeaves() async {
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        await viewModel.handleSaveButtonTap()

        #expect(viewModel.showsSavedConfirmation == true)
        #expect(viewModel.requestLeaving() == true)
        #expect(viewModel.showingCancelConfirmation == false)
    }

    @Test("Leaving is refused, without a dialog, while a save is running")
    func leavingIsRefusedDuringASave() async {
        let gatedUseCase = GatedCVManagementUseCase(gating: .create)
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: gatedUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        let saving = Task { await viewModel.saveCV() }
        await gatedUseCase.waitUntilGatedCallStarts()

        #expect(viewModel.requestLeaving() == false, "The save would finish after the editor was left")
        #expect(viewModel.showingCancelConfirmation == false)

        await gatedUseCase.openGate()
        #expect(await saving.value == true)
        #expect(viewModel.requestLeaving() == true)
    }

    // MARK: - Failed saves

    @Test("A failed create keeps the CV and reports the error")
    func failedCreateKeepsCVAndReportsError() async {
        let mockUseCase = MockCVManagementUseCase()
        await mockUseCase.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"

        let saved = await viewModel.saveCV()

        #expect(saved == false)
        #expect(viewModel.saveError != nil)
        #expect(viewModel.isShowingError == true)
        #expect(viewModel.cv.personalInfo.name == "John Doe", "The edits must survive a failed save")
        #expect(viewModel.hasUnsavedChanges == true)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.viewState.isLoaded)
        #expect(viewModel.showsSavedConfirmation == false)
    }

    @Test("The error alert tells why the save failed, and has nothing to tell before")
    func errorAlertTellsWhyTheSaveFailed() async {
        let mockUseCase = MockCVManagementUseCase()
        let failure = AppError.fileSystemError("disk full")
        await mockUseCase.setCreateCVResult(.failure(failure))
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"
        #expect(viewModel.errorMessage.isEmpty)

        _ = await viewModel.saveCV()

        #expect(viewModel.errorMessage == failure.localizedDescription)
    }

    @Test("After a failed create the next save creates the CV")
    func saveAfterFailedCreateCreatesCV() async {
        let mockUseCase = MockCVManagementUseCase()
        await mockUseCase.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: mockUseCase)
        viewModel.cv.personalInfo.name = "John Doe"
        _ = await viewModel.saveCV()

        await mockUseCase.setCreateCVResult(.success(CVModel()))
        let saved = await viewModel.saveCV()

        #expect(saved == true)
        #expect(viewModel.saveError == nil, "A new save attempt starts without the previous error")
        #expect(await mockUseCase.createdCVs.count == 1)
        #expect(await mockUseCase.updateCVCallCount == 0)
    }

    @Test("A failed update followed by clearError keeps the edits and the loaded editor")
    func failedUpdateThenClearErrorKeepsEdits() async {
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
        await mockUseCase.storeCV(existingCV)
        await mockUseCase.setUpdateCVError(AppError.fileSystemError("disk full"))
        let viewModel = CVEditorViewModel(cvId: existingCV.id.uuidString, cvManagementUseCase: mockUseCase)
        await viewModel.loadCV()
        viewModel.cv.personalInfo.phone = "+1234567890"

        let saved = await viewModel.saveCV()
        viewModel.clearError()

        #expect(saved == false)
        #expect(viewModel.saveError == nil)
        #expect(viewModel.isShowingError == false)
        #expect(viewModel.cv.personalInfo.phone == "+1234567890", "The edits must survive the error alert")
        #expect(viewModel.hasUnsavedChanges == true)
        #expect(viewModel.viewState.isLoaded)
        #expect(await mockUseCase.getCVCallCount == 1, "Dismissing the error must not reload the CV from storage")
    }

    // MARK: - Loading

    @Test("Loading an existing CV twice reads it once and keeps the edits")
    func loadingExistingCVTwiceReadsOnce() async {
        let mockUseCase = MockCVManagementUseCase()
        let existingCV = CVModel(
            id: UUID(),
            name: "Existing CV",
            personalInfo: PersonalInfo(name: "Jane Doe", email: "jane@example.com")
        )
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
        let existingCV = CVModel(id: UUID(), name: "Existing CV", personalInfo: PersonalInfo(name: "Jane Doe"))
        await mockUseCase.storeCV(existingCV)
        await mockUseCase.setGetCVResult(.failure(AppError.fileSystemError("unreadable")))
        let viewModel = CVEditorViewModel(cvId: existingCV.id.uuidString, cvManagementUseCase: mockUseCase)

        await viewModel.loadCV()
        #expect(viewModel.viewState.isError)

        await mockUseCase.setGetCVResult(.success(nil))
        await viewModel.loadCV()

        #expect(viewModel.viewState.isLoaded)
        #expect(viewModel.cv.name == "Existing CV")
        #expect(await mockUseCase.getCVCallCount == 2)
    }
}
