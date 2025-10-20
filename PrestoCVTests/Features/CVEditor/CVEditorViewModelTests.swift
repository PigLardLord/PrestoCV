import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Mock CVManagementUseCase

actor MockCVManagementUseCase: CVManagementUseCaseProtocol {
    private(set) var createCVCalled = false
    private(set) var updateCVCalled = false
    private(set) var getCVCalled = false
    private(set) var deleteCVCalled = false
    private(set) var getAllCVsCalled = false

    private(set) var createdCVs: [CVModel] = []
    private(set) var updatedCVs: [CVModel] = []

    private var storedCVs: [UUID: CVModel] = [:]
    private var createCVResult: Result<CVModel, Error> = .success(CVModel())
    private var getCVResult: Result<CVModel?, Error> = .success(nil)

    // Configuration methods
    func setCreateCVResult(_ result: Result<CVModel, Error>) {
        self.createCVResult = result
    }

    func setGetCVResult(_ result: Result<CVModel?, Error>) {
        self.getCVResult = result
    }

    func storeCV(_ cv: CVModel) {
        storedCVs[cv.id] = cv
    }

    // Protocol implementation
    func createCV(from model: CVModel) async throws -> CVModel {
        createCVCalled = true

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

    func updateCV(_ model: CVModel) async throws -> CVModel {
        updateCVCalled = true
        updatedCVs.append(model)
        storedCVs[model.id] = model
        return model
    }

    func getCV(by id: UUID) async throws -> CVModel? {
        getCVCalled = true

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

    @Test("handleCancelButtonTap returns true when no unsaved changes")
    func handleCancelWithNoChanges() {
        // Given
        let mockUseCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: mockUseCase
        )

        // When - CV is empty (no meaningful content)
        let shouldNavigate = viewModel.handleCancelButtonTap()

        // Then - Should return true (navigate immediately) and not show confirmation
        #expect(shouldNavigate == true, "Should navigate immediately when no changes")
        #expect(viewModel.showingCancelConfirmation == false, "Should not show confirmation dialog")
    }

    @Test("handleCancelButtonTap shows confirmation when there are unsaved changes")
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
        let shouldNavigate = viewModel.handleCancelButtonTap()

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
}
