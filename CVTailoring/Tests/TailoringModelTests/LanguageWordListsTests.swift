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

    // MARK: - Version and size

    @Test("the format version is 1, and only 1 is read")
    func versionOne() {
        #expect(WordListFormat.version == 1)
    }

    @Test("a version other than 1 is corrupt", arguments: [0, 2, 3, -1, 100])
    func otherVersion(version: Int) throws {
        let data = try WordListFixture.data { $0["version"] = version }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a version that is not a whole number is corrupt")
    func versionNotANumber() throws {
        var versions: [Any] = ["1"]
        versions.append(1.5)
        versions.append(NSNull())
        versions.append(true)
        versions.append([1])
        versions.append("")
        for version in versions {
            let data = try WordListFixture.data { $0["version"] = version }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a file without a version is corrupt")
    func noVersion() throws {
        let data = try WordListFixture.data { $0["version"] = nil }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a file of the largest size is read, and one byte more is corrupt")
    func sizeCap() throws {
        let complete = try WordListFixture.data()
        let padding = WordListFormat.maxFileBytes - complete.count
        let atTheCap = complete + Data(repeating: UInt8(ascii: " "), count: padding)
        #expect(atTheCap.count == WordListFormat.maxFileBytes)
        _ = try decode(atTheCap)
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(atTheCap + Data(" ".utf8)) }
    }

    @Test("the largest size is 1 MiB")
    func capValue() {
        #expect(WordListFormat.maxFileBytes == 1_048_576)
    }

    // MARK: - Source and licence

    @Test("a list without a source or a licence is corrupt", arguments: WordListKey.allCases)
    func noSourceOrLicence(key: WordListKey) throws {
        for field in ["source", "licence"] {
            let data = try WordListFixture.data(editing: key) { $0[field] = nil }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a source or a licence that is empty or not trimmed is corrupt", arguments: ["", " ", " ISC", "ISC ", "\n", "ISC\n"])
    func blankSourceOrLicence(text: String) throws {
        for key in WordListKey.allCases {
            for field in ["source", "licence"] {
                let data = try WordListFixture.data(editing: key) { $0[field] = text }
                #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
            }
        }
    }

    // MARK: - Entries

    @Test("a list with no entry is incomplete", arguments: WordListKey.allCases)
    func noEntries(key: WordListKey) throws {
        let data = try WordListFixture.data(editing: key) { $0["entries"] = [Any]() }
        #expect(throws: TailoringModelError.incompleteWordList(.english, key)) { try decode(data) }
    }

    private static let badEntries = ["", " ", " a", "a ", "\n", "a\n", "\t", "\u{00A0}", "\u{FEFF}"]

    @Test("an entry that is empty or not trimmed is corrupt", arguments: WordListFixture.textKeys)
    func badText(key: WordListKey) throws {
        for entry in Self.badEntries {
            let data = try WordListFixture.data(editing: key) { $0["entries"] = ["alpha", entry] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a month name, a number word and a synonym form that is empty or not trimmed is corrupt")
    func badEntriesOfOtherShapes() throws {
        for entry in Self.badEntries {
            let month = try WordListFixture.data(editing: .datesMonths) { list in
                var months = list["entries"] as? [WordListFixture.Object] ?? []
                months[0]["name"] = entry
                list["entries"] = months
            }
            let number = try WordListFixture.data(editing: .numbersWords) { list in
                var numbers = list["entries"] as? [WordListFixture.Object] ?? []
                numbers[0]["word"] = entry
                list["entries"] = numbers
            }
            let count = try WordListFixture.data(editing: .spansCountWords) { list in
                var numbers = list["entries"] as? [WordListFixture.Object] ?? []
                numbers[0]["word"] = entry
                list["entries"] = numbers
            }
            let synonym = try WordListFixture.data(editing: .advertSynonyms) { $0["entries"] = [["forms": ["ui", entry]]] }
            let tied = try WordListFixture.data(editing: .spansTiedCounts) { $0["entries"] = [entry] }
            for data in [month, number, count, synonym, tied] {
                #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
            }
        }
    }

    @Test("an entry repeated once folded is corrupt, however it is written", arguments: [
        ["Café", "cafe"], ["Straße", "STRASSE"], ["A", "a"], ["a  b", "A b"], ["Zoë", "zoe"],
    ])
    func repeatedText(entries: [String]) throws {
        for key in WordListFixture.textKeys {
            let data = try WordListFixture.data(editing: key) { $0["entries"] = ["alpha"] + entries }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a month name, a number word and a synonym form repeated once folded is corrupt")
    func repeatedOfOtherShapes() throws {
        let month = try WordListFixture.data(editing: .datesMonths) { list in
            var months = list["entries"] as? [WordListFixture.Object] ?? []
            months.append(["name": "MONTH1", "month": 1])
            list["entries"] = months
        }
        let number = try WordListFixture.data(editing: .numbersWords) { list in
            var numbers = list["entries"] as? [WordListFixture.Object] ?? []
            numbers.append(["word": "Two", "value": 2])
            list["entries"] = numbers
        }
        let count = try WordListFixture.data(editing: .spansCountWords) { list in
            var numbers = list["entries"] as? [WordListFixture.Object] ?? []
            numbers.append(["word": "Two", "value": 2])
            list["entries"] = numbers
        }
        let withinAGroup = try WordListFixture.data(editing: .advertSynonyms) { $0["entries"] = [["forms": ["ui", "UI"]]] }
        let acrossGroups = try WordListFixture.data(editing: .advertSynonyms) {
            $0["entries"] = [["forms": ["ui", "user interface"]], ["forms": ["gui", "User Interface"]]]
        }
        let tied = try WordListFixture.data(editing: .spansTiedCounts) {
            $0["entries"] = ["{count} of them at {employer}", "{COUNT} OF THEM AT {employer}"]
        }
        for data in [month, number, count, withinAGroup, acrossGroups, tied] {
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("the same entry in two different lists is fine")
    func sameEntryInTwoLists() throws {
        _ = try decode(WordListFixture.data())
        let stopwords = try #require(try decode(WordListFixture.data()).advert.stopwords.entries.first)
        #expect(try decode(WordListFixture.data()).advert.plainWords.entries.contains(stopwords))
    }
}
