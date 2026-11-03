import Testing
@testable import CVGeneratorAI

/// The characters the reader of a CV cannot see (ADR 0031): the description is read without them, and a sentence the model writes
/// holds none. All text is invented.
@Suite("The characters that the reader cannot see")
struct HiddenCharactersTests {
    struct CleanRow: Sendable, CustomTestStringConvertible {
        let name: String
        let text: String
        let cleaned: String
        var testDescription: String { name }
    }

    static let cleanRows: [CleanRow] = [
        CleanRow(name: "plain text is kept", text: "I repair scales in Leeds.", cleaned: "I repair scales in Leeds."),
        CleanRow(name: "a control character is dropped", text: "I repair\u{0007} scales.", cleaned: "I repair scales."),
        CleanRow(name: "a tab is a space", text: "I repair\tscales.", cleaned: "I repair scales."),
        CleanRow(name: "a line break stays one", text: "I repair scales.\nI like it.", cleaned: "I repair scales.\nI like it."),
        CleanRow(name: "a carriage return and a line feed are one line break", text: "One.\r\nTwo.", cleaned: "One.\nTwo."),
        CleanRow(name: "a lone carriage return is a line break", text: "One.\rTwo.", cleaned: "One.\nTwo."),
        CleanRow(name: "the next line character is a line break", text: "One.\u{0085}Two.", cleaned: "One.\nTwo."),
        CleanRow(name: "the line separator is a line break", text: "One.\u{2028}Two.", cleaned: "One.\nTwo."),
        CleanRow(name: "the paragraph separator is a line break", text: "One.\u{2029}Two.", cleaned: "One.\nTwo."),
        CleanRow(name: "a soft hyphen is dropped", text: "cali\u{00AD}brate", cleaned: "calibrate"),
        CleanRow(name: "a zero-width space is dropped", text: "cali\u{200B}brate", cleaned: "calibrate"),
        CleanRow(name: "a bidirectional mark is dropped", text: "a\u{202E}b\u{200F}c", cleaned: "abc"),
        CleanRow(name: "a private-use scalar is dropped", text: "a\u{E000}b", cleaned: "ab"),
        CleanRow(name: "a no-break space is seen", text: "10\u{00A0}000 euros", cleaned: "10\u{00A0}000 euros"),
        CleanRow(name: "a narrow no-break space is seen", text: "10\u{202F}000 euros", cleaned: "10\u{202F}000 euros"),
        CleanRow(name: "an accent and an emoji are seen", text: "caf\u{00E9} \u{1F600}", cleaned: "caf\u{00E9} \u{1F600}"),
    ]

    @Test("The description is read without the characters that the reader cannot see", arguments: cleanRows)
    func cleaned(row: CleanRow) {
        #expect(HiddenCharacters.cleaned(row.text) == row.cleaned)
    }

    @Test("A cleaned description holds no hidden character but its line breaks", arguments: cleanRows)
    func cleanedHoldsNone(row: CleanRow) {
        let kept = HiddenCharacters.cleaned(row.text).unicodeScalars.filter { $0 != "\n" }

        #expect(!kept.contains(where: HiddenCharacters.hides))
    }

    struct ScalarRow: Sendable, CustomTestStringConvertible {
        let name: String
        let scalar: Unicode.Scalar
        let hidden: Bool
        var testDescription: String { name }
    }

    static let scalars: [ScalarRow] = [
        ScalarRow(name: "letter", scalar: "a", hidden: false),
        ScalarRow(name: "digit", scalar: "7", hidden: false),
        ScalarRow(name: "space", scalar: " ", hidden: false),
        ScalarRow(name: "no-break space", scalar: "\u{00A0}", hidden: false),
        ScalarRow(name: "narrow no-break space", scalar: "\u{202F}", hidden: false),
        ScalarRow(name: "emoji", scalar: "\u{1F600}", hidden: false),
        ScalarRow(name: "control", scalar: "\u{0001}", hidden: true),
        ScalarRow(name: "tab", scalar: "\t", hidden: true),
        ScalarRow(name: "line feed", scalar: "\n", hidden: true),
        ScalarRow(name: "soft hyphen", scalar: "\u{00AD}", hidden: true),
        ScalarRow(name: "zero-width space", scalar: "\u{200B}", hidden: true),
        ScalarRow(name: "zero-width joiner", scalar: "\u{200D}", hidden: true),
        ScalarRow(name: "byte order mark", scalar: "\u{FEFF}", hidden: true),
        ScalarRow(name: "right-to-left override", scalar: "\u{202E}", hidden: true),
        ScalarRow(name: "line separator", scalar: "\u{2028}", hidden: true),
        ScalarRow(name: "paragraph separator", scalar: "\u{2029}", hidden: true),
        ScalarRow(name: "private use", scalar: "\u{E000}", hidden: true),
        ScalarRow(name: "unassigned", scalar: "\u{0378}", hidden: true),
    ]

    @Test("A scalar is hidden when it is a control, a format, a line separator, a private-use or an unassigned scalar", arguments: scalars)
    func hides(row: ScalarRow) {
        #expect(HiddenCharacters.hides(row.scalar) == row.hidden)
    }

    @Test("A text holds a hidden character when one of its scalars is hidden")
    func occur() {
        #expect(HiddenCharacters.occur(in: "I repair sca\u{00AD}les."))
        #expect(!HiddenCharacters.occur(in: "I repair scales for 10\u{00A0}000 euros."))
        #expect(!HiddenCharacters.occur(in: ""))
    }
}
