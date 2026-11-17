import Testing
@testable import PrestoCVNext

/// A CV's PDF is named in the language of its document, whatever language the app shows (R13).
@Suite("ExportTitlePattern: the title of a CV's PDF in the language of its document")
struct ExportTitlePatternTests {
    @Test("Each language of the catalog gives its own pattern, with the placeholder of the title kept as it is", arguments: [
        ("de", "%@ – Lebenslauf"),
        ("en", "%@ – CV"),
        ("es", "%@ – CV"),
        ("fr", "%@ – CV"),
        ("it", "%@ – CV"),
        ("pt", "%@ – Currículo"),
    ])
    func patternInEachLanguage(tag: String, pattern: String) {
        #expect(ExportTitlePattern.pattern(inLanguageTagged: tag) == pattern)
    }

    @Test("A region of a language takes the language's pattern")
    func regionTakesTheLanguage() {
        #expect(ExportTitlePattern.pattern(inLanguageTagged: "de-AT") == "%@ – Lebenslauf")
    }
}
