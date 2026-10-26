import Testing
@testable import PrestoCV
@testable import PrestoCVCore

/// When the editor offers the export of its CV.
@MainActor
@Suite("CVEditorViewModel Tests - whether the CV can be exported")
struct CVEditorCanExportTests {

    private func editor(_ cv: CVModel) -> CVEditorViewModel {
        CVEditorViewModel(cvId: nil, initialCV: cv, cvManagementUseCase: MockCVManagementUseCase())
    }

    @Test("A CV with nothing in it cannot be exported, even with a name of its own")
    func emptyCVCannotBeExported() {
        #expect(!editor(CVModel()).canExport)
        #expect(!editor(CVModel(name: "Backend Engineer")).canExport)
    }

    @Test("A CV with something in it can be exported before it is saved", arguments: [
        CVModel(personalInfo: PersonalInfo(name: "Ada Lovelace")),
        CVModel(skills: [Skill(name: "Swift")]),
        CVModel(interests: ["Chess"]),
    ])
    func filledCVCanBeExported(cv: CVModel) {
        let viewModel = editor(cv)

        #expect(viewModel.canExport)
    }

    @Test("Emptying the form takes the export away")
    func emptyingTheFormTakesTheExportAway() {
        let viewModel = editor(CVModel(personalInfo: PersonalInfo(name: "Ada Lovelace")))

        viewModel.cv.personalInfo.name = "  "

        #expect(!viewModel.canExport)
    }
}
