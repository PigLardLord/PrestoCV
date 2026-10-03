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

    static let caseVariants: [(String, TailoringLanguage)] = {
        var cases: [(String, TailoringLanguage)] = []
        cases.append(("EN", .english))
        cases.append(("En", .english))
        cases.append(("eN-gb", .english))
        cases.append(("PT-br", .portuguese))
        cases.append(("DE", .german))
        cases.append(("eS", .spanish))
        cases.append(("FR-ca", .french))
        cases.append(("iT-CH", .italian))
        return cases
    }()

    @Test("case does not matter", arguments: caseVariants)
    func caseInsensitive(tag: String, language: TailoringLanguage) throws {
        #expect(try TailoringLanguage(bcp47: tag) == language)
    }

    @Test("a subtag of eight characters is a subtag, one of nine is not")
    func subtagLength() throws {
        #expect(try TailoringLanguage(bcp47: "en-abcdefgh") == .english)
        #expect(throws: TailoringModelError.unsupportedLanguage) { try TailoringLanguage(bcp47: "en-abcdefghi") }
        #expect(try TailoringLanguage(bcp47: "en-a") == .english)
    }

    /// A tag of the given length whose every subtag is well formed, so only its length can refuse it.
    private func wellFormedTag(bytes: Int) -> String {
        var tag = "en"
        while tag.utf8.count + 9 <= bytes { tag += "-abcdefgh" }
        let rest = bytes - tag.utf8.count
        if rest >= 2 { tag += "-" + String(repeating: "a", count: rest - 1) }
        return tag
    }

    @Test("a tag of 64 UTF-8 bytes is read, one of 65 is refused before it is split")
    func tagLength() throws {
        #expect(wellFormedTag(bytes: 64).utf8.count == 64)
        #expect(wellFormedTag(bytes: 65).utf8.count == 65)
        #expect(try TailoringLanguage(bcp47: wellFormedTag(bytes: 64)) == .english)
        #expect(throws: TailoringModelError.unsupportedLanguage) { try TailoringLanguage(bcp47: wellFormedTag(bytes: 65)) }
        #expect(throws: TailoringModelError.unsupportedLanguage) { try TailoringLanguage(bcp47: wellFormedTag(bytes: 1_000_000)) }
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
