import Testing
import Foundation
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

    @Test("A CV without a name is listed under the name of its person, before the role it is for", arguments: ["", "   ", " \n "])
    func unnamedCVIsListedUnderItsPerson(name: String) {
        let cv = CVModel(name: name, personalInfo: PersonalInfo(name: "Lena Hartmann", title: "Pflegefachkraft"))
        #expect(viewModel.title(of: cv) == "Lena Hartmann")
    }

    @Test("A CV without a name or a person is listed under the role it is for", arguments: ["", "   ", " \n "])
    func unnamedCVIsListedUnderItsRole(name: String) {
        #expect(viewModel.title(of: CVModel(name: name, personalInfo: PersonalInfo(name: name, title: "Infermiera"))) == "Infermiera")
    }

    @Test("A CV with none of a name, a person and a role, or only white space, is listed as Untitled CV", arguments: ["", "   ", " \n "])
    func unnamedCVIsListedAsUntitled(name: String) {
        #expect(viewModel.title(of: CVModel(name: name, personalInfo: PersonalInfo(name: name, title: name))) == "cv.untitled".localized)
    }

    @Test("Rows whose titles read alike are numbered, so that no two read the same; untitled ones as untitled documents are")
    func alikeRowsAreNumbered() async {
        let ids = ["00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002",
                   "00000000-0000-0000-0000-000000000003"].compactMap(UUID.init(uuidString:))
        let first = CVModel(id: ids[0]), second = CVModel(id: ids[1])
        let named = CVModel(id: ids[2], name: "Backend Engineer")
        let useCase = MockCVManagementUseCase()
        for cv in [second, named, first] {
            await useCase.storeCV(cv)
        }
        let list = CVListViewModel(cvManagementUseCase: useCase)
        await list.loadCVs()

        #expect(list.title(of: first) == "cv.untitled".localized)
        #expect(list.title(of: second) == "\("cv.untitled".localized) 2", "Untitled CV 2, as the platform numbers an untitled document")
        #expect(list.title(of: named) == "Backend Engineer")
    }

    @Test("No two rows read the same: a number skips a title the list shows, and an untitled CV is told from one named like it")
    func rowLabelsAreUnique() async {
        let ids = (1...5).compactMap { UUID(uuidString: "00000000-0000-0000-0000-00000000000\($0)") }
        let untitled = "cv.untitled".localized
        let cvs = [
            CVModel(id: ids[0], name: "Backend"), CVModel(id: ids[1], name: "Backend"),
            CVModel(id: ids[2], name: "cv.title.numbered".localizedWithArgs("Backend", 2)),
            CVModel(id: ids[3]), CVModel(id: ids[4], name: untitled),
        ]
        let useCase = MockCVManagementUseCase()
        for cv in cvs {
            await useCase.storeCV(cv)
        }
        let list = CVListViewModel(cvManagementUseCase: useCase)
        await list.loadCVs()

        #expect(cvs.map(list.title(of:)) == [
            "Backend", "cv.title.numbered".localizedWithArgs("Backend", 3), "cv.title.numbered".localizedWithArgs("Backend", 2),
            untitled, "cv.title.numbered".localizedWithArgs(untitled, 2),
        ])
    }
}
