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
        #expect(lists.dates.presentWords.entries == ["alpha", "beta"] && lists.dates.durationUnitWords.entries == ["alpha", "beta"])
        #expect(lists.dates.sinceWords.entries == ["alpha", "beta"] && lists.dates.rangeSeparatorWords.entries == ["alpha", "beta"])
        #expect(lists.numbers.words.entries == [NumberWord(word: "two", value: 2), NumberWord(word: "three", value: 3)])
        #expect(lists.spans.countWords.entries == [NumberWord(word: "two", value: 2), NumberWord(word: "three", value: 3)])
        #expect(lists.spans.tiedCounts.entries == ["{count} of them at {employer}"])
        #expect(lists.spans.employerEndWords.entries == ["alpha", "beta"])
        #expect(lists.letter.valedictions.entries == ["alpha", "beta"])
        #expect(lists.letter.formsOfAddress.entries == [FormOfAddressWord(form: .ms, word: "alpha"), FormOfAddressWord(form: .mr, word: "beta")])
        #expect(lists.provenance.notPlurals.entries == ["alpha", "beta"] && lists.provenance.legalForms.entries == ["alpha", "beta"])
        #expect(lists.provenance.firstPerson.entries == ["alpha", "beta"])
        #expect(lists.provenance.ranks.entries == [RankWord(word: "alpha", ranks: [.senior]), RankWord(word: "beta", ranks: [.lead, .head])])
        #expect(lists.letter.academicTitles.entries == ["alpha", "beta"] && lists.letter.notGivenNames.entries == ["alpha", "beta"])
        #expect(lists.technologies.entries == ["alpha", "beta"])
    }

    static let notAnObjectCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", "nope", "[]", "\"en\""])
        values.append(contentsOf: ["null", "{"])
        return values
    }()

    @Test("a file that is not a JSON object is corrupt", arguments: notAnObjectCases)
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

    @Test("a missing group is incomplete, named by its first list, whichever group it is", arguments: unknownGroupKeyCases)
    func missingEachGroup(group: String) throws {
        let first = try #require(WordListKey.allCases.first { $0.group == group })
        let data = try WordListFixture.data { $0[group] = nil }
        #expect(throws: TailoringModelError.incompleteWordList(.english, first)) { try decode(data) }
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

    static let unknownGroupKeyCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["advert", "dates", "numbers", "spans"])
        values.append(contentsOf: ["letter", "provenance", "fields"])
        return values
    }()

    @Test("a key the format does not know in a group is corrupt", arguments: unknownGroupKeyCases)
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

    static let unknownEntryKeyCases: [WordListKey] = {
        var values: [WordListKey] = []
        values.append(contentsOf: [.datesMonths, .numbersWords, .spansCountWords, .advertSynonyms])
        values.append(contentsOf: [.letterFormsOfAddress, .provenanceRanks])
        return values
    }()

    @Test("a key the format does not know in an entry is corrupt", arguments: unknownEntryKeyCases)
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

    static let otherVersionCases: [Int] = {
        var values: [Int] = []
        values.append(contentsOf: [0, 2, 3, -1])
        values.append(contentsOf: [100])
        return values
    }()

    @Test("a version other than 1 is corrupt", arguments: otherVersionCases)
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

    static let blankSourceOrLicenceCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", " ", " ISC", "ISC "])
        values.append(contentsOf: ["\n", "ISC\n"])
        values.append(contentsOf: ["IS\u{0007}C", "IS\u{202E}C", "IS\u{E0041}C", "IS\u{200F}C"])
        return values
    }()

    @Test("a source or a licence that is empty, hidden or not trimmed is corrupt", arguments: blankSourceOrLicenceCases)
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

    private static let badEntries: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", " ", " a", "a "])
        values.append(contentsOf: ["\n", "a\n", "\t", "\u{00A0}"])
        values.append(contentsOf: ["\u{FEFF}", "\u{200B}", "\u{200B}a", "a\u{200B}"])
        values.append(contentsOf: ["\u{2060}", "\u{2060}a", "a\u{2060}", "\u{200D}a"])
        values.append(contentsOf: ["a\u{0007}b", "a\u{0000}b", "a\nb", "a\u{202E}b"])
        values.append(contentsOf: ["a\u{E0041}b", "a\u{200F}b", "\u{0301}"])
        return values
    }()

    @Test("an entry that is empty, hidden or not trimmed is corrupt", arguments: WordListFixture.textKeys)
    func badText(key: WordListKey) throws {
        for entry in Self.badEntries {
            let data = try WordListFixture.data(editing: key) { $0["entries"] = ["alpha", entry] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a month name, a number word and a synonym form that is empty, hidden or not trimmed is corrupt")
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

    static let repeatedTextCases: [[String]] = {
        var values: [[String]] = []
        values.append(["Café", "cafe"])
        values.append(["Straße", "STRASSE"])
        values.append(["A", "a"])
        values.append(["a  b", "A b"])
        values.append(["Zoë", "zoe"])
        return values
    }()

    @Test("an entry repeated once folded is corrupt, however it is written", arguments: repeatedTextCases)
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

    // MARK: - Rules of one kind of list

    private func months(_ edit: @escaping ([WordListFixture.Object]) -> [WordListFixture.Object]) throws -> Data {
        try WordListFixture.data(editing: .datesMonths) { list in
            list["entries"] = edit(list["entries"] as? [WordListFixture.Object] ?? [])
        }
    }

    static let monthOutOfRangeCases: [Int] = {
        var values: [Int] = []
        values.append(contentsOf: [0, 13, -1, 100])
        return values
    }()

    @Test("a month outside 1 to 12 is corrupt", arguments: monthOutOfRangeCases)
    func monthOutOfRange(month: Int) throws {
        let data = try months { entries in
            var entries = entries
            entries[0]["month"] = month
            return entries
        }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a month that is not a whole number is corrupt")
    func monthNotANumber() throws {
        var values: [Any] = ["1"]
        values.append(1.5)
        values.append(NSNull())
        for value in values {
            let data = try months { entries in
                var entries = entries
                entries[0]["month"] = value
                return entries
            }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a language that names no month for each of the twelve is incomplete", arguments: Array(1...12))
    func monthMissing(month: Int) throws {
        let data = try months { $0.filter { ($0["month"] as? Int) != month } }
        #expect(throws: TailoringModelError.incompleteWordList(.english, .datesMonths)) { try decode(data) }
    }

    @Test("a month may be named several times, by its name and by its abbreviation")
    func monthNamedTwice() throws {
        let data = try months { entries in
            var entries = entries
            entries.append(["name": "m1", "month": 1])
            return entries
        }
        let lists = try decode(data)
        #expect(lists.dates.months.entries.filter { $0.month == 1 }.map(\.name) == ["month1", "m1"])
    }

    static let numberValueCases: [WordListKey] = {
        var values: [WordListKey] = []
        values.append(contentsOf: [.numbersWords, .spansCountWords])
        return values
    }()

    @Test("a number word with a value below 0, or that is not a whole number, is corrupt", arguments: numberValueCases)
    func numberValue(key: WordListKey) throws {
        var values: [Any] = [-1]
        values.append("2")
        values.append(2.5)
        values.append(NSNull())
        for value in values {
            let data = try WordListFixture.data(editing: key) { list in
                var entries = list["entries"] as? [WordListFixture.Object] ?? []
                entries[0]["value"] = value
                list["entries"] = entries
            }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    static let shortSynonymGroupCases: [[String]] = {
        var values: [[String]] = []
        values.append([])
        values.append(["ui"])
        return values
    }()

    @Test("a group of synonyms with fewer than two forms is corrupt", arguments: shortSynonymGroupCases)
    func shortSynonymGroup(forms: [String]) throws {
        let data = try WordListFixture.data(editing: .advertSynonyms) { $0["entries"] = [["forms": ["a", "b"]], ["forms": forms]] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    static let tiedCountPlaceholdersCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["of them at", "{count} of them at", "of them at {employer}", "{count} {count} at {employer}"])
        values.append(contentsOf: ["{count} at {employer} {employer}", "{count} at {employer} {unit}", "{count at {employer}", "{count} at {employer}}"])
        values.append(contentsOf: ["{employer} of {count}{"])
        return values
    }()

    @Test("a tied count holds {count} and {employer} once each, and no other braces", arguments: tiedCountPlaceholdersCases)
    func tiedCountPlaceholders(template: String) throws {
        let data = try WordListFixture.data(editing: .spansTiedCounts) { $0["entries"] = [template] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    static let tiedCountShapesCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["{count} of them at {employer}", "davon {count} bei {employer}", "{employer}: {count}", "{count}{employer}"])
        return values
    }()

    @Test("a tied count may put the count before or after the employer, and say more", arguments: tiedCountShapesCases)
    func tiedCountShapes(template: String) throws {
        let data = try WordListFixture.data(editing: .spansTiedCounts) { $0["entries"] = [template] }
        #expect(try decode(data).spans.tiedCounts.entries == [template])
    }

    @Test("the street order is joined, after or before, and a list of streets must say it", arguments: StreetOrder.allCases)
    func streetOrder(order: StreetOrder) throws {
        let data = try WordListFixture.data(editing: .advertStreets) { $0["order"] = order.rawValue }
        #expect(try decode(data).advert.streets.order == order)
    }

    static let streetOrderUnknownCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["middle", "", "After", "joined "])
        return values
    }()

    @Test("a street order that is unknown or empty is corrupt", arguments: streetOrderUnknownCases)
    func streetOrderUnknown(order: String) throws {
        let data = try WordListFixture.data(editing: .advertStreets) { $0["order"] = order }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a list of streets without an order is corrupt")
    func streetOrderMissing() throws {
        let data = try WordListFixture.data(editing: .advertStreets) { $0["order"] = nil }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    // MARK: - Forms of address

    static let unknownFormCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["neutral", "", "MS", "Mr", "x", " ms"])
        return values
    }()

    @Test("a form of address that is not ms or mr is corrupt", arguments: unknownFormCases)
    func unknownForm(form: String) throws {
        let data = try WordListFixture.data(editing: .letterFormsOfAddress) { $0["entries"] = [["form": form, "word": "alpha"]] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a form of address that is not a string, or has no word, is corrupt")
    func formNotAString() throws {
        var forms: [Any] = [1]
        forms.append(NSNull())
        forms.append(["ms"])
        for form in forms {
            let data = try WordListFixture.data(editing: .letterFormsOfAddress) { $0["entries"] = [["form": form, "word": "alpha"]] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
        let noWord = try WordListFixture.data(editing: .letterFormsOfAddress) { $0["entries"] = [["form": "ms"]] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(noWord) }
    }

    @Test("a word of a form of address that is empty, hidden or not trimmed is corrupt")
    func badFormWord() throws {
        for word in Self.badEntries {
            let data = try WordListFixture.data(editing: .letterFormsOfAddress) { $0["entries"] = [["form": "ms", "word": word]] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a word that is two forms of address once folded is corrupt")
    func wordUnderTwoForms() throws {
        let data = try WordListFixture.data(editing: .letterFormsOfAddress) {
            $0["entries"] = [["form": "ms", "word": "alpha"], ["form": "mr", "word": "ALPHA"]]
        }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("one form of address may have several words")
    func severalWordsForOneForm() throws {
        let data = try WordListFixture.data(editing: .letterFormsOfAddress) {
            $0["entries"] = [["form": "ms", "word": "ms"], ["form": "ms", "word": "mrs"], ["form": "mr", "word": "mr"]]
        }
        #expect(try decode(data).letter.formsOfAddress.entries.map(\.word) == ["ms", "mrs", "mr"])
    }

    // MARK: - Ranks

    @Test("the ranks of the format are the ones the check knows")
    func ranksOfTheFormat() {
        #expect(Rank.allCases.map(\.rawValue) == ["senior", "lead", "principal", "staff", "head", "director", "manager", "architect"])
    }

    static let unknownRankCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", "Senior", "seniorr", " senior", "chief", "junior"])
        return values
    }()

    @Test("a rank the format does not know is corrupt", arguments: unknownRankCases)
    func unknownRank(rank: String) throws {
        let data = try WordListFixture.data(editing: .provenanceRanks) { $0["entries"] = [["word": "alpha", "ranks": ["senior", rank]]] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a word that claims no rank, or one rank twice, is corrupt")
    func noRankOrTwice() throws {
        var lists: [[String]] = [[]]
        lists.append(["lead", "lead"])
        for ranks in lists {
            let data = try WordListFixture.data(editing: .provenanceRanks) { $0["entries"] = [["word": "alpha", "ranks": ranks]] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("ranks that are not an array of strings, or are missing, are corrupt")
    func ranksNotAnArray() throws {
        var values: [Any] = ["senior"]
        values.append(1)
        values.append(NSNull())
        values.append([1])
        for ranks in values {
            let data = try WordListFixture.data(editing: .provenanceRanks) { $0["entries"] = [["word": "alpha", "ranks": ranks]] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
        let missing = try WordListFixture.data(editing: .provenanceRanks) { $0["entries"] = [["word": "alpha"]] }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(missing) }
    }

    @Test("a word of a rank that is empty, hidden or not trimmed is corrupt")
    func badRankWord() throws {
        for word in Self.badEntries {
            let data = try WordListFixture.data(editing: .provenanceRanks) { $0["entries"] = [["word": word, "ranks": ["lead"]]] }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }

    @Test("a word that is two entries once folded is corrupt, though it claims two ranks")
    func rankWordRepeated() throws {
        let data = try WordListFixture.data(editing: .provenanceRanks) {
            $0["entries"] = [["word": "lead", "ranks": ["lead"]], ["word": "LEAD", "ranks": ["head"]]]
        }
        #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
    }

    @Test("a word may claim several ranks, in the order the file writes them")
    func severalRanks() throws {
        let data = try WordListFixture.data(editing: .provenanceRanks) {
            $0["entries"] = [["word": "leiter", "ranks": ["lead", "head", "manager", "director"]]]
        }
        #expect(try decode(data).provenance.ranks.entries == [RankWord(word: "leiter", ranks: [.lead, .head, .manager, .director])])
    }

    // MARK: - Licences

    @Test("the licences a list may carry are ISC alone, and widening the set is a reviewed change")
    func allowedLicences() {
        #expect(WordListFormat.allowedLicences == ["ISC"])
    }

    static let otherLicenceCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["MIT", "isc", "ISC OR MIT", "GPL-3.0-only"])
        values.append(contentsOf: ["Apache-2.0", "proprietary", "ISC-like"])
        return values
    }()

    @Test("a licence that is not in the allowed set is corrupt, however well formed", arguments: otherLicenceCases)
    func licenceNotAllowed(licence: String) throws {
        for key in WordListKey.allCases {
            let data = try WordListFixture.data(editing: key) { $0["licence"] = licence }
            #expect(throws: TailoringModelError.corruptWordList(.language(.english))) { try decode(data) }
        }
    }
}
