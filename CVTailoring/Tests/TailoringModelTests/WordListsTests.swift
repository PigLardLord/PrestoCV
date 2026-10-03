import Testing
import Foundation
@testable import TailoringModel

@Suite("ADR 0013 / R13 · the languages with a word-list file are the ones in the index (#136)")
struct WordListsTests {
    private func index(_ codes: [String]) throws -> Data { try JSONSerialization.data(withJSONObject: codes) }

    /// A complete file. Building it cannot fail; the error only keeps the closures below typed.
    private static func complete(
        _ language: TailoringLanguage = .english, _ edit: ((inout WordListFixture.Object) -> Void)? = nil
    ) throws(TailoringModelError) -> Data {
        var object = WordListFixture.object(language: language)
        edit?(&object)
        do { return try WordListFixture.data(object) } catch { throw .corruptWordList(.index, nil) }
    }

    /// Files for the languages named, each a complete file; a language without one is the error the resources give.
    private func files(for available: [TailoringLanguage]) -> (TailoringLanguage) throws(TailoringModelError) -> Data {
        return { language throws(TailoringModelError) in
            guard available.contains(language) else { throw .corruptWordList(.language(language), nil) }
            return try Self.complete(language)
        }
    }

    private func lists(_ codes: [String], available: [TailoringLanguage]) throws(TailoringModelError) -> WordLists {
        let data: Data
        do { data = try index(codes) } catch { throw .corruptWordList(.index, nil) }
        return try WordLists(index: data, files: files(for: available))
    }

    @Test("the languages are the ones in the index, in its order, each with its own lists")
    func languages() throws {
        let lists = try lists(["fr", "en"], available: [.english, .french])
        #expect(lists.languages == [.french, .english])
        #expect(try lists.forLanguage(.english).language == .english)
        #expect(try lists.forLanguage(.french).language == .french)
    }

    @Test("a language without a file is unsupported, never English", arguments: TailoringLanguage.allCases.filter { $0 != .english })
    func unsupported(language: TailoringLanguage) throws {
        let lists = try lists(["en"], available: [.english])
        #expect(throws: TailoringModelError.unsupportedLanguage) { try lists.forLanguage(language) }
    }

    @Test("a language in the index without a file is corrupt, and names the language")
    func listedWithoutAFile() {
        #expect(throws: TailoringModelError.corruptWordList(.language(.german), nil)) { try lists(["en", "de"], available: [.english]) }
    }

    @Test("a file that names another language than the index lists it for is corrupt, and names the language the index gave")
    func fileOfAnotherLanguage() throws {
        let data = try index(["en"])
        #expect(throws: TailoringModelError.corruptWordList(.language(.english), nil)) {
            try WordLists(index: data) { _ throws(TailoringModelError) in try Self.complete(.german) }
        }
    }

    @Test("a file that cannot be read is corrupt, and names its language")
    func corruptFile() throws {
        let data = try index(["en", "it"])
        #expect(throws: TailoringModelError.corruptWordList(.language(.italian), nil)) {
            try WordLists(index: data) { language throws(TailoringModelError) in language == .english ? try Self.complete(language) : Data("nope".utf8) }
        }
    }

    @Test("a file that is incomplete names its language and the list")
    func incompleteFile() throws {
        let data = try index(["it"])
        #expect(throws: TailoringModelError.incompleteWordList(.italian, .letterGreetings)) {
            try WordLists(index: data) { language throws(TailoringModelError) in try Self.complete(language) { $0["letter"] = nil } }
        }
    }

    static let notAnIndexCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", "nope", "{}", "null"])
        values.append(contentsOf: ["\"en\"", "[1]", "[null]", "[[\"en\"]]"])
        values.append(contentsOf: ["[\"en\",", "{\"en\":true}"])
        return values
    }()

    @Test("an index that is not an array of language codes is corrupt", arguments: notAnIndexCases)
    func notAnIndex(text: String) {
        #expect(throws: TailoringModelError.corruptWordList(.index, nil)) {
            try WordLists(index: Data(text.utf8), files: files(for: TailoringLanguage.allCases))
        }
    }

    @Test("an index with no language is corrupt: nothing could be tailored")
    func emptyIndex() {
        #expect(throws: TailoringModelError.corruptWordList(.index, nil)) { try lists([], available: TailoringLanguage.allCases) }
    }

    static let unknownCodeCases: [[String]] = {
        var values: [[String]] = []
        values.append(["xx"])
        values.append(["en", "ja"])
        values.append(["EN"])
        values.append(["en-GB"])
        values.append([" en"])
        values.append(["eng"])
        values.append([""])
        values.append(["pt_BR"])
        return values
    }()

    @Test("an index code that is not one of the six, or not written as one, is corrupt", arguments: unknownCodeCases)
    func unknownCode(codes: [String]) {
        #expect(throws: TailoringModelError.corruptWordList(.index, nil)) { try lists(codes, available: TailoringLanguage.allCases) }
    }

    @Test("a language listed twice is corrupt")
    func listedTwice() {
        #expect(throws: TailoringModelError.corruptWordList(.index, nil)) { try lists(["en", "de", "en"], available: TailoringLanguage.allCases) }
    }

    @Test("an index over 1 MiB is corrupt")
    func largeIndex() {
        let padded = Data("[\"en\"]".utf8) + Data(repeating: UInt8(ascii: " "), count: WordListFormat.maxFileBytes)
        #expect(throws: TailoringModelError.corruptWordList(.index, nil)) { try WordLists(index: padded, files: files(for: [.english])) }
    }

    @Test("every one of the six can be listed")
    func allSix() throws {
        let lists = try lists(TailoringLanguage.allCases.map(\.code), available: TailoringLanguage.allCases)
        #expect(lists.languages == TailoringLanguage.allCases)
        for language in TailoringLanguage.allCases { #expect(try lists.forLanguage(language).language == language) }
    }
}
