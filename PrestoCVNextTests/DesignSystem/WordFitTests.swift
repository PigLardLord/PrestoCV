import Testing
@testable import PrestoCV

@Suite("WordFit: a text is measured in the pieces between which a line surely may break")
struct WordFitTests {
    @Test("A line may break at a space, a tab or a line break, and after a hyphen between two letters", arguments: [
        ("Document language", ["Document", "language"]),
        ("Error code: launchFixturesRejected", ["Error", "code:", "launchFixturesRejected"]),
        ("Social-Media-Profile", ["Social-", "Media-", "Profile"]),
        ("one\ttwo\nthree", ["one", "two", "three"]),
        ("  two  spaces  ", ["two", "spaces"]),
    ])
    func breakPoints(text: String, pieces: [String]) {
        #expect(WordFit.words(in: text) == pieces)
    }

    @Test("A no-break space joins the words around it, as the French code line does before its colon", arguments: [
        ("Code d’erreur\u{00A0}: 42", ["Code", "d’erreur\u{00A0}:", "42"]),
        ("Code d’erreur\u{202F}: 42", ["Code", "d’erreur\u{202F}:", "42"]),
        ("Seite\u{2007}12", ["Seite\u{2007}12"]),
    ])
    func noBreakSpacesJoin(text: String, pieces: [String]) {
        #expect(WordFit.words(in: text) == pieces)
    }

    @Test("A hyphen before a digit, or at the start of a word, is no break point", arguments: [
        ("pages 1-5", ["pages", "1-5"]),
        ("version-2", ["version-2"]),
        ("-5 degrees", ["-5", "degrees"]),
        ("-Profile", ["-Profile"]),
    ])
    func hyphensThatDoNotBreak(text: String, pieces: [String]) {
        #expect(WordFit.words(in: text) == pieces)
    }
}
