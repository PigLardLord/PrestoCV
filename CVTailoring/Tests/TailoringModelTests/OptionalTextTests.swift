import Testing
import TailoringModel

@Suite("ADR 0013 / R6 · an absent text is nil, not blank")
struct OptionalTextTests {
    static let optionalFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.email) { _ = try SourcePersonalDetails(fullName: "A", email: $0) })
        cases.append(TextFieldCase(.phone) { _ = try SourcePersonalDetails(fullName: "A", phone: $0) })
        cases.append(TextFieldCase(.website) { _ = try SourcePersonalDetails(fullName: "A", website: $0) })
        cases.append(TextFieldCase(.link) { _ = try SourceCertification(name: "x", issuer: "x", link: $0) })
        cases.append(TextFieldCase(.salaryExpectation) { _ = try LetterDefaults(salaryExpectation: $0) })
        cases.append(TextFieldCase(.startDate) { _ = try LetterDefaults(startDate: $0) })
        cases.append(TextFieldCase(.note) { _ = try LetterDefaults(note: $0) })
        return cases
    }()

    @Test("a text that is present but blank is refused", arguments: optionalFields, blankStrings)
    func blankIsRefused(field: TextFieldCase, blank: String) {
        #expect(throws: TailoringModelError.emptyField(field.field)) { try field.build(blank) }
    }

    @Test("a text that says something is accepted as written", arguments: optionalFields)
    func presentIsAccepted(field: TextFieldCase) throws {
        try field.build(" something ")
        try field.build(markedSpace)
    }

    @Test("a text that is absent is nil")
    func absentIsNil() throws {
        let details = try SourcePersonalDetails(fullName: "A")
        #expect(details.email == nil && details.phone == nil && details.website == nil)
        #expect(try SourceCertification(name: "x", issuer: "x").link == nil)
        let defaults = try LetterDefaults()
        #expect(defaults.salaryExpectation == nil && defaults.startDate == nil && defaults.note == nil)
    }

    @Test("the size is checked before the text is read for something to say")
    func sizeFirst() {
        #expect(throws: TailoringModelError.tooLarge(.note)) { try LetterDefaults(note: String(repeating: " ", count: 10_001)) }
    }
}
