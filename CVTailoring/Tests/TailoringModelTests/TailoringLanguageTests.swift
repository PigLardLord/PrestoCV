import Testing
import TailoringModel

@Suite("ADR 0013 / R13 · the six languages")
struct TailoringLanguageTests {
    @Test("each of the six codes names its language", arguments: [
        ("en", TailoringLanguage.english), ("de", .german), ("es", .spanish),
        ("fr", .french), ("it", .italian), ("pt", .portuguese),
    ])
    func codes(code: String, language: TailoringLanguage) throws {
        #expect(try TailoringLanguage(bcp47: code) == language)
        #expect(language.code == code)
    }

    @Test("there are exactly six languages")
    func closedSet() {
        #expect(TailoringLanguage.allCases.map(\.code) == ["en", "de", "es", "fr", "it", "pt"])
    }

    @Test("a regional tag is read by its primary language subtag", arguments: [
        ("en-GB", TailoringLanguage.english), ("pt-BR", .portuguese), ("de-AT", .german),
        ("es-419", .spanish), ("fr-CA", .french), ("it-CH", .italian), ("en-Latn-US", .english),
    ])
    func regional(tag: String, language: TailoringLanguage) throws {
        #expect(try TailoringLanguage(bcp47: tag) == language)
    }

    @Test("case does not matter", arguments: ["EN", "En", "eN-gb", "PT-br", "DE"])
    func caseInsensitive(tag: String) throws {
        _ = try TailoringLanguage(bcp47: tag)
    }

    @Test("anything else is an unsupported language, never English", arguments: [
        "", " ", "und", "eng", "e", "ja", "zh-Hans", "nl", "pt_BR", "en_GB", "en-", "-en", "en--GB", "en-GB-", " en", "en ",
        "en-\u{00E9}", "\u{0435}n", "en-toolongsubtag", "english", "x-en",
    ])
    func unsupported(tag: String) {
        #expect(throws: TailoringModelError.unsupportedLanguage) { try TailoringLanguage(bcp47: tag) }
    }
}
