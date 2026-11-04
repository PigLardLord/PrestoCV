import Testing
import PrestoCVDomain

@Suite("A draft started from an example")
struct ExampleDraftTests {
    @Test("it leaves blank who the example's person is and how to reach them, and the CV's own name",
          arguments: [CVField.title, .fullName, .email, .phone, .location, .website, .profileLinks])
    func cleared(field: CVField) {
        #expect(ExampleDraft.clearedFields.contains(field))
    }

    @Test("it keeps what the example says of the work", arguments: [CVField.professionalTitle, .summary])
    func kept(field: CVField) {
        #expect(!ExampleDraft.clearedFields.contains(field))
    }

    @Test("every field is either cleared or kept")
    func everyField() {
        #expect(ExampleDraft.clearedFields.isSubset(of: Set(CVField.allCases)))
        #expect(CVField.allCases.count == 9)
    }
}
