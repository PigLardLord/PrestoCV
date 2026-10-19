import Testing
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("CVListViewModel Tests - the name a CV is listed under")
struct CVListTitleTests {

    private let viewModel = CVListViewModel(cvManagementUseCase: MockCVManagementUseCase())

    @Test("A CV is listed under its name")
    func namedCVIsListedUnderItsName() {
        #expect(viewModel.title(of: CVModel(name: "Backend Engineer")) == "Backend Engineer")
    }

    @Test("A CV without a name, or with only white space, is listed as Untitled CV", arguments: ["", "   ", " \n "])
    func unnamedCVIsListedAsUntitled(name: String) {
        #expect(viewModel.title(of: CVModel(name: name)) == "cv.untitled".localized)
    }
}
