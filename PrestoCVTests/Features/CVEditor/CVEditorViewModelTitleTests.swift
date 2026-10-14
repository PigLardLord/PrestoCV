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

    @Test("A CV that was never stored is called New CV until it is named")
    func newCVIsCalledNewCV() {
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: MockCVManagementUseCase())
        viewModel.cv.personalInfo.name = "Ada Lovelace"

        #expect(viewModel.screenTitle == "editor.new_cv".localized)

        viewModel.cv.name = "Backend engineer"
        #expect(viewModel.screenTitle == "Backend engineer")
    }

    @Test("A stored CV shows its name")
    func storedCVShowsItsName() async {
        let viewModel = await loadedViewModel(storing: CVModel(name: "Backend engineer", personalInfo: PersonalInfo(name: "Ada Lovelace")))

        #expect(viewModel.screenTitle == "Backend engineer")
    }

    @Test("A stored CV without a name shows the name of the person")
    func storedCVWithoutNameShowsThePerson() async {
        let viewModel = await loadedViewModel(storing: CVModel(name: "", personalInfo: PersonalInfo(name: "Ada Lovelace")))

        #expect(viewModel.screenTitle == "Ada Lovelace")
    }

    @Test("A stored CV with neither name is Untitled CV, not New CV")
    func storedCVWithNeitherNameIsUntitled() async {
        let viewModel = await loadedViewModel(storing: CVModel(name: "  ", personalInfo: PersonalInfo(name: " ", email: "ada@example.com")))

        #expect(viewModel.screenTitle == "cv.untitled".localized)
        #expect(viewModel.screenTitle != "editor.new_cv".localized)
    }
}
