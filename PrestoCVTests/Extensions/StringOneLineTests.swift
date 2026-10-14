import Testing
@testable import PrestoCV

@Suite("String Tests - One Line")
struct StringOneLineTests {

    @Test("Text without a line break is unchanged")
    func textWithoutLineBreakIsUnchanged() {
        #expect("Ward Nurse".onOneLine == "Ward Nurse")
        #expect("".onOneLine == "")
    }

    @Test("A line break at the end goes away")
    func lineBreakAtTheEndGoesAway() {
        #expect("Ward Nurse\n".onOneLine == "Ward Nurse")
    }

    @Test("A line break at the start goes away")
    func lineBreakAtTheStartGoesAway() {
        #expect("\nWard Nurse".onOneLine == "Ward Nurse")
    }

    @Test("A line break inside the text becomes a space")
    func lineBreakInsideBecomesASpace() {
        #expect("Ward\nNurse".onOneLine == "Ward Nurse")
        #expect("Ward\r\nNurse".onOneLine == "Ward Nurse")
    }

    @Test("Several line breaks in a row become one space")
    func severalLineBreaksBecomeOneSpace() {
        #expect("Ward\n\n\nNurse".onOneLine == "Ward Nurse")
    }
}
