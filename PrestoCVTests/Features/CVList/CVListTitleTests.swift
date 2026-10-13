import Testing
@testable import PrestoCV
@testable import PrestoCVCore

@Suite("CVModel list title Tests")
struct CVListTitleTests {

    @Test("A CV is listed under its name")
    func namedCVIsListedUnderItsName() {
        #expect(CVModel(name: "Backend Engineer").listTitle == "Backend Engineer")
    }

    @Test("A CV without a name, or with only white space, is listed as Untitled CV", arguments: ["", "   ", " \n "])
    func unnamedCVIsListedAsUntitled(name: String) {
        #expect(CVModel(name: name).listTitle == "cv.untitled".localized)
    }
}
