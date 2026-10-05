import Testing
@testable import CVRendering

@Suite("LanguageTag · the shape of a BCP 47 tag")
struct LanguageTagTests {
    @Test("a primary language of two or three letters, with up to three subtags of two to eight letters or digits", arguments: [
        "en", "EN", "eng", "en-GB", "en-gb", "es-419", "de-CH-1996", "zh-Hant-TW", "en-a1-b2-c3", "en-12345678", "en-ab-cd-ef",
    ])
    func wellFormed(tag: String) {
        #expect(LanguageTag.isWellFormed(tag))
    }

    @Test("anything else is refused, at each edge of the shape", arguments: [
        "", "e", "engl", "e1", "en-", "en--GB", "en-G", "en-123456789", "en-GB-US-x1-yy", "en_GB", "-en", "en GB", "en-GB ",
        "en-GB\n", "en\u{2028}", "en-é", "é", "en\"onload=\"x", "en-GB-x", "1n",
    ])
    func malformed(tag: String) {
        #expect(!LanguageTag.isWellFormed(tag))
    }

    @Test("a document language that is not well formed is printed as undetermined")
    func undetermined() {
        #expect(LanguageTag.printable("en-GB") == "en-GB")
        #expect(LanguageTag.printable("en-GB-US-x1-yy") == "und")
        #expect(LanguageTag.printable("") == "und")
    }
}
