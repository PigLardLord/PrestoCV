import Testing
import Foundation
@testable import TailoringModel

@Suite("ADR 0013 / R8 · one language's word-list file is decoded into typed groups (#136)")
struct LanguageWordListsTests {
    private func decode(_ data: Data, as language: TailoringLanguage = .english) throws(TailoringModelError) -> LanguageWordLists {
        try LanguageWordLists(decoding: data, language: language)
    }

    @Test("a complete file becomes the typed groups of its language")
    func complete() throws {
        let lists = try decode(WordListFixture.data(), as: .italian)
        #expect(lists.language == .italian)
        #expect(lists.advert.stopwords.entries == ["alpha", "beta"])
        #expect(lists.advert.stopwords.source == "a test" && lists.advert.stopwords.licence == "ISC")
        #expect(lists.advert.synonyms.entries == [SynonymGroup(forms: ["ui", "user interface"])])
        #expect(lists.advert.streets.order == .after)
        #expect(lists.advert.streets.list.entries == ["alpha", "beta"])
        #expect(lists.dates.months.entries.count == 12)
        #expect(lists.dates.months.entries.first == MonthName(name: "month1", month: 1))
        #expect(lists.numbers.words.entries == [NumberWord(word: "two", value: 2), NumberWord(word: "three", value: 3)])
        #expect(lists.spans.countWords.entries == [NumberWord(word: "two", value: 2), NumberWord(word: "three", value: 3)])
        #expect(lists.spans.tiedCounts.entries == ["{count} of them at {employer}"])
        #expect(lists.letter.valedictions.entries == ["alpha", "beta"])
        #expect(lists.technologies.entries == ["alpha", "beta"])
    }

    @Test("a file that is not a JSON object is corrupt", arguments: ["", "nope", "[]", "\"en\"", "null", "{"])
    func notAnObject(text: String) {
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(Data(text.utf8)) }
    }

    @Test("a missing list is incomplete, and the key names it", arguments: WordListKey.allCases)
    func missingList(key: WordListKey) throws {
        let data = try WordListFixture.data { object in
            var group = object[key.group] as? WordListFixture.Object ?? [:]
            group[key.name] = nil
            object[key.group] = group
        }
        #expect(throws: TailoringModelError.incompleteWordList(.english, key)) { try decode(data) }
    }

    @Test("a missing group is incomplete, and the key names the first list the group should hold")
    func missingGroup() throws {
        let data = try WordListFixture.data { $0["letter"] = nil }
        #expect(throws: TailoringModelError.incompleteWordList(.english, .letterGreetings)) { try decode(data) }
    }

    @Test("the error names the language the file was read for")
    func errorNamesTheLanguage() {
        #expect(throws: TailoringModelError.corruptWordList(.language(.french))) { try decode(Data("nope".utf8), as: .french) }
    }

    // MARK: - Keys the format does not know

    @Test("a key the format does not know at the top of the file is corrupt")
    func unknownRootKey() throws {
        let data = try WordListFixture.data { $0["extra"] = 1 }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a key the format does not know in a group is corrupt", arguments: ["advert", "dates", "numbers", "spans", "letter", "fields"])
    func unknownGroupKey(group: String) throws {
        let data = try WordListFixture.data { object in
            var members = object[group] as? WordListFixture.Object ?? [:]
            members["extra"] = WordListFixture.list(for: .advertStopwords)
            object[group] = members
        }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a key the format does not know in a list is corrupt", arguments: WordListKey.allCases)
    func unknownListKey(key: WordListKey) throws {
        let data = try WordListFixture.data(editing: key) { $0["extra"] = 1 }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a key the format does not know in an entry is corrupt", arguments: [
        WordListKey.datesMonths, .numbersWords, .spansCountWords, .advertSynonyms,
    ])
    func unknownEntryKey(key: WordListKey) throws {
        let data = try WordListFixture.data(editing: key) { list in
            var entries = list["entries"] as? [WordListFixture.Object] ?? []
            entries[0]["extra"] = 1
            list["entries"] = entries
        }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("an entry of a list of words that is an object is corrupt")
    func objectInAListOfWords() throws {
        let data = try WordListFixture.data(editing: .advertStopwords) { $0["entries"] = [["word": "the"]] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }
}
