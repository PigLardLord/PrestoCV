import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("CVEditorViewModel Tests - Document Language")
struct CVEditorViewModelDocumentLanguageTests {

    private func makeViewModel(documentLanguage: String? = nil) -> CVEditorViewModel {
        CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(documentLanguage: documentLanguage),
            cvManagementUseCase: MockCVManagementUseCase()
        )
    }

    @Test("A CV with no document language has no selection")
    func noLanguageMeansAutomatic() {
        #expect(makeViewModel().documentLanguageSelection == nil)
    }

    @Test("The selection is the language set on the CV, region included", arguments: [
        ("it", DocumentLanguage.italian), ("pt-BR", .portuguese), ("DE", .german),
    ])
    func selectionShowsTheStoredLanguage(stored: String, expected: DocumentLanguage) {
        #expect(makeViewModel(documentLanguage: stored).documentLanguageSelection == expected)
    }

    @Test("A stored language the app does not support shows as automatic")
    func unsupportedLanguageShowsAsAutomatic() {
        #expect(makeViewModel(documentLanguage: "ja").documentLanguageSelection == nil)
    }

    @Test("Choosing a language stores its code on the CV")
    func choosingStoresTheCode() {
        let viewModel = makeViewModel()

        viewModel.documentLanguageSelection = .french

        #expect(viewModel.cv.documentLanguage == "fr")
    }

    @Test("Choosing automatic clears the language of the CV")
    func choosingAutomaticClearsTheLanguage() {
        let viewModel = makeViewModel(documentLanguage: "es")

        viewModel.documentLanguageSelection = nil

        #expect(viewModel.cv.documentLanguage == nil)
    }

    @Test("Changing the language of a saved CV is an unsaved change, and undoing it is not")
    func languageChangeIsTrackedAsUnsavedChange() async {
        // Given
        let saved = CVModel(name: "Backend", personalInfo: PersonalInfo(name: "Ada", email: "ada@example.com"))
        let useCase = MockCVManagementUseCase()
        await useCase.setGetCVResult(.success(saved))
        let viewModel = CVEditorViewModel(cvId: saved.id.uuidString, cvManagementUseCase: useCase)
        await viewModel.loadCV()
        #expect(!viewModel.hasUnsavedChanges)

        // When / Then
        viewModel.documentLanguageSelection = .german
        #expect(viewModel.hasUnsavedChanges)

        viewModel.documentLanguageSelection = nil
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("Saving a CV keeps the language that was chosen")
    func savingKeepsTheLanguage() async {
        // Given
        let saved = CVModel(name: "Backend", personalInfo: PersonalInfo(name: "Ada", email: "ada@example.com"))
        let useCase = MockCVManagementUseCase()
        await useCase.setGetCVResult(.success(saved))
        let viewModel = CVEditorViewModel(cvId: saved.id.uuidString, cvManagementUseCase: useCase)
        await viewModel.loadCV()
        viewModel.documentLanguageSelection = .spanish

        // When
        let didSave = await viewModel.saveCV()

        // Then
        #expect(didSave)
        #expect(await useCase.updatedCVs.last?.documentLanguage == "es")
    }
}
