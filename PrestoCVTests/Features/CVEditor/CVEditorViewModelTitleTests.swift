import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("CVEditorViewModel Tests - Screen Title")
struct CVEditorViewModelTitleTests {

    private func loadedViewModel(storing cv: CVModel) async -> CVEditorViewModel {
        let useCase = MockCVManagementUseCase()
        await useCase.setGetCVResult(.success(cv))
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase)
        await viewModel.loadCV()
        return viewModel
    }

    @Test("A CV that was never stored is called New CV until it has a title, then by the name of its person or its own")
    func newCVIsCalledNewCV() {
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: MockCVManagementUseCase())
        #expect(viewModel.screenTitle == "editor.new_cv".localized)

        viewModel.cv.personalInfo.name = "Ada Lovelace"
        #expect(viewModel.screenTitle == "Ada Lovelace")

        viewModel.cv.name = "Backend engineer"
        #expect(viewModel.screenTitle == "Backend engineer")
    }

    @Test("A stored CV shows its name")
    func storedCVShowsItsName() async {
        let viewModel = await loadedViewModel(storing: CVModel(name: "Backend engineer", personalInfo: PersonalInfo(name: "Ada Lovelace")))

        #expect(viewModel.screenTitle == "Backend engineer")
    }

    @Test("A CV without a name shows the name of its person before the role it is for, stored or not")
    func cvWithoutNameShowsItsPerson() async {
        let stored = await loadedViewModel(storing: CVModel(name: "", personalInfo: PersonalInfo(name: "Ada Lovelace", title: "Data Analyst")))
        let new = CVEditorViewModel(cvId: nil, initialCV: CVModel(personalInfo: PersonalInfo(name: "Giulia Rossi", title: "Infermiera")),
                                    cvManagementUseCase: MockCVManagementUseCase())

        #expect(stored.screenTitle == "Ada Lovelace")
        #expect(new.screenTitle == "Giulia Rossi")
    }

    @Test("A CV without a name or a person shows the role it is for, stored or not")
    func cvWithoutNameOrPersonShowsItsRole() async {
        let stored = await loadedViewModel(storing: CVModel(name: "", personalInfo: PersonalInfo(title: "Data Analyst")))
        let new = CVEditorViewModel(cvId: nil, initialCV: CVModel(personalInfo: PersonalInfo(title: "Infermiera")), cvManagementUseCase: MockCVManagementUseCase())

        #expect(stored.screenTitle == "Data Analyst")
        #expect(new.screenTitle == "Infermiera")
    }

    @Test("A stored CV with none of a name, a person and a role is Untitled CV, not New CV")
    func storedCVWithNeitherNameIsUntitled() async {
        let viewModel = await loadedViewModel(storing: CVModel(name: "  ", personalInfo: PersonalInfo(name: " ", email: "ada@example.com")))

        #expect(viewModel.screenTitle == "cv.untitled".localized)
        #expect(viewModel.screenTitle != "editor.new_cv".localized)
    }
}
