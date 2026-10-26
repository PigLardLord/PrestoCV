import Testing
import PrestoCVDomain

@Suite("Whether a CV can be exported")
struct ExportReadinessTests {
    @Test("only the name of the person is required: without it the CV is not exported, and the name is the field to fix",
          arguments: ["", "  ", "\n"])
    func nameIsRequired(name: String) {
        let readiness = ExportReadiness(name: name, email: "ada@example.com", phone: "+39 06 1234567")

        #expect(!readiness.canExport)
        #expect(readiness.blockers == [.name])
        #expect(readiness.warnings.isEmpty)
    }

    @Test("a missing e-mail address or phone number only warns", arguments: [
        ("", "+39 06 1234567", [ExportReadiness.Field.email]),
        ("ada@example.com", " ", [.phone]),
        ("", "", [.email, .phone]),
    ])
    func contactsOnlyWarn(email: String, phone: String, warnings: [ExportReadiness.Field]) {
        let readiness = ExportReadiness(name: "Ada Lovelace", email: email, phone: phone)

        #expect(readiness.canExport)
        #expect(readiness.blockers.isEmpty)
        #expect(readiness.warnings == warnings)
    }

    @Test("a CV with nothing written says what blocks it and what is worth adding")
    func nothingWritten() {
        let readiness = ExportReadiness(name: "", email: "", phone: "")

        #expect(readiness.blockers == [.name] && readiness.warnings == [.email, .phone])
    }

    @Test("a CV with a name, an e-mail address and a phone number is ready, with nothing to say")
    func ready() {
        let readiness = ExportReadiness(name: "Ada Lovelace", email: "ada@example.com", phone: "+39 06 1234567")

        #expect(readiness.canExport && readiness.blockers.isEmpty && readiness.warnings.isEmpty)
    }

    @Test("the name is the one required field")
    func requiredFields() {
        #expect(ExportReadiness.requiredFields == [.name])
    }
}
