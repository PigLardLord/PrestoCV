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

    @Test("Automatic names the language it stands for as the CV is typed: the app's, then the one the CV is written in")
    func automaticNamesTheLanguageItStandsFor() {
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(personalInfo: PersonalInfo(name: "Luca Ferrari", title: "Sales Manager")),
            cvManagementUseCase: MockCVManagementUseCase(),
            documentLanguageDetector: DocumentLanguageDetector(preferredLanguages: ["it-IT"], read: NaturalLanguageReader.read)
        )
        let automatic = { (name: String) in String(format: String(localized: "language.automatic"), name) }
        #expect(viewModel.automaticDocumentLanguageTitle == automatic("Italiano"), "Too few words to tell: the app's language")

        viewModel.cv.personalInfo.profile = "Sales and operations manager with over 20 years of experience in industrial "
            + "distribution. Built and led teams of up to 15 people and managed key accounts."

        #expect(viewModel.automaticDocumentLanguageTitle == automatic("English"))
        #expect(viewModel.documentLanguageSelection == nil, "Naming the language does not choose it")
    }

    @Test("The row shows the language chosen, or what automatic stands for")
    func rowShowsTheChosenOrTheAutomaticLanguage() {
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(),
            cvManagementUseCase: MockCVManagementUseCase(),
            documentLanguageDetector: DocumentLanguageDetector(preferredLanguages: ["it-IT"], read: NaturalLanguageReader.read)
        )
        #expect(viewModel.documentLanguageTitle == viewModel.automaticDocumentLanguageTitle)

        viewModel.documentLanguageSelection = .german

        #expect(viewModel.documentLanguageTitle == "Deutsch")
    }

    @Test("Changing the language of a saved CV and undoing it before the save stores nothing")
    func languageChangeUndoneStoresNothing() async {
        // Given
        let saved = CVModel(name: "Backend", personalInfo: PersonalInfo(name: "Ada", email: "ada@example.com"))
        let useCase = MockCVManagementUseCase()
        await useCase.setGetCVResult(.success(saved))
        let viewModel = CVEditorViewModel(cvId: saved.id.uuidString, cvManagementUseCase: useCase)
        await viewModel.loadCV()

        // When
        viewModel.documentLanguageSelection = .german
        viewModel.documentLanguageSelection = nil
        await viewModel.saveNow()

        // Then
        #expect(await !useCase.updateCVCalled)
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
        await viewModel.saveNow()

        // Then
        #expect(await useCase.updatedCVs.last?.documentLanguage == "es")
    }
}
