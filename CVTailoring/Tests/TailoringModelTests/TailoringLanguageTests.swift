import Testing
import TailoringModel

@Suite("ADR 0013 / R13 · the six languages")
struct TailoringLanguageTests {
    static let codeCases: [(String, TailoringLanguage)] = {
        var cases: [(String, TailoringLanguage)] = []
        cases.append(("en", .english))
        cases.append(("de", .german))
        cases.append(("es", .spanish))
        cases.append(("fr", .french))
        cases.append(("it", .italian))
        cases.append(("pt", .portuguese))
        return cases
    }()

    @Test("each of the six codes names its language", arguments: codeCases)
    func codes(code: String, language: TailoringLanguage) throws {
        #expect(try TailoringLanguage(bcp47: code) == language)
        #expect(language.code == code)
    }

    @Test("there are exactly six languages")
    func closedSet() {
        #expect(TailoringLanguage.allCases.map(\.code) == ["en", "de", "es", "fr", "it", "pt"])
    }

    static let regionalCases: [(String, TailoringLanguage)] = {
        var cases: [(String, TailoringLanguage)] = []
        cases.append(("en-GB", .english))
        cases.append(("pt-BR", .portuguese))
        cases.append(("de-AT", .german))
        cases.append(("es-419", .spanish))
        cases.append(("fr-CA", .french))
        cases.append(("it-CH", .italian))
        cases.append(("en-Latn-US", .english))
        return cases
    }()

    @Test("a regional tag is read by its primary language subtag", arguments: regionalCases)
    func regional(tag: String, language: TailoringLanguage) throws {
        #expect(try TailoringLanguage(bcp47: tag) == language)
    }

    static let caseVariants: [String] = {
        var tags: [String] = []
        tags.append(contentsOf: ["EN", "En", "eN-gb", "PT-br", "DE"])
        return tags
    }()

    @Test("case does not matter", arguments: caseVariants)
    func caseInsensitive(tag: String) throws {
        _ = try TailoringLanguage(bcp47: tag)
    }

    static let unsupportedTags: [String] = {
        var tags: [String] = []
        tags.append(contentsOf: ["", " ", "und", "eng", "e", "ja", "zh-Hans", "nl"])
        tags.append(contentsOf: ["pt_BR", "en_GB", "en-", "-en", "en--GB", "en-GB-", " en", "en "])
        tags.append(contentsOf: ["en-\u{00E9}", "\u{0435}n", "en-toolongsubtag", "english", "x-en"])
        return tags
    }()

    @Test("anything else is an unsupported language, never English", arguments: unsupportedTags)
    func unsupported(tag: String) {
        #expect(throws: TailoringModelError.unsupportedLanguage) { try TailoringLanguage(bcp47: tag) }
    }
}
