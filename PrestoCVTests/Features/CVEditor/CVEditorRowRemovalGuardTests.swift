import Testing
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Row Removal Guard Tests

@MainActor
@Suite("CVEditorViewModel Tests - removing rows that are not there")
struct CVEditorRowRemovalGuardTests {

    private func makeViewModelWithOneRowPerSection() -> CVEditorViewModel {
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: MockCVManagementUseCase())
        viewModel.addSkill()
        viewModel.addExperience()
        viewModel.addEducation()
        viewModel.addLanguage()
        viewModel.addCertification()
        viewModel.addSocial()
        viewModel.addInterest()
        return viewModel
    }

    private func removeRows(of viewModel: CVEditorViewModel, at index: Int) {
        viewModel.removeSkill(at: index)
        viewModel.removeExperience(at: index)
        viewModel.removeEducation(at: index)
        viewModel.removeLanguage(at: index)
        viewModel.removeCertification(at: index)
        viewModel.removeSocial(at: index)
        viewModel.removeInterest(at: index)
    }

    @Test("Removing a row that is not there leaves every section alone", arguments: [-1, 1, 5])
    func removingMissingRowLeavesSectionsAlone(index: Int) {
        let viewModel = makeViewModelWithOneRowPerSection()
        let before = viewModel.cv

        removeRows(of: viewModel, at: index)

        #expect(viewModel.cv == before)
    }

    @Test("Removing the only row of every section empties it")
    func removingTheOnlyRowEmptiesEverySection() {
        let viewModel = makeViewModelWithOneRowPerSection()

        removeRows(of: viewModel, at: 0)

        #expect(viewModel.cv.skills.isEmpty)
        #expect(viewModel.cv.relevant_experience.isEmpty)
        #expect(viewModel.cv.education.isEmpty)
        #expect(viewModel.cv.languages.isEmpty)
        #expect(viewModel.cv.certifications.isEmpty)
        #expect(viewModel.cv.social.isEmpty)
        #expect(viewModel.cv.interests.isEmpty)
    }

    @Test("Removing a row from an empty section does nothing")
    func removingFromEmptySectionDoesNothing() {
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: MockCVManagementUseCase())
        let before = viewModel.cv

        removeRows(of: viewModel, at: 0)

        #expect(viewModel.cv == before)
    }
}
