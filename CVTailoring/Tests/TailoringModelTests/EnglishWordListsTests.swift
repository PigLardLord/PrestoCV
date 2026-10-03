import Testing
import Foundation
@testable import TailoringModel

/// The English file against cv-giovanni at commit 6e28147, and the bundled files against the index.
@Suite("ADR 0013 / R13 · the bundled word lists (#136)")
struct EnglishWordListsTests {
    private func english() throws -> LanguageWordLists { try WordLists.load().forLanguage(.english) }

    @Test("the bundled lists load, English has a file, and every language the index names has its lists")
    func loads() throws {
        let lists = try WordLists.load()
        #expect(lists.languages.contains(.english))
        for language in lists.languages { #expect(try lists.forLanguage(language).language == language) }
    }

    /// The languages that have no file: the six minus the ones that load. A failed load leaves all six, and the test below
    /// then fails for English.
    static let unsupportedCases: [TailoringLanguage] = {
        var loaded: [TailoringLanguage] = []
        do { loaded = try WordLists.load().languages } catch { loaded = [] }
        return TailoringLanguage.allCases.filter { !loaded.contains($0) }
    }()

    @Test("a language without a file is unsupported, until it has one", arguments: unsupportedCases)
    func unsupported(language: TailoringLanguage) throws {
        let lists = try WordLists.load()
        #expect(throws: TailoringModelError.unsupportedLanguage) { try lists.forLanguage(language) }
    }

    // MARK: - The directory and the index

    @Test("the resources give the index and the file of English, and name a file they do not have as corrupt")
    func resources() throws {
        #expect(try !WordListResources.data(named: "index", as: .index).isEmpty)
        #expect(try !WordListResources.data(named: "en", as: .language(.english)).isEmpty)
        #expect(throws: TailoringModelError.corruptWordList(.language(.german), nil)) {
            try WordListResources.data(named: "de", as: .language(.german))
        }
        #expect(throws: TailoringModelError.corruptWordList(.index, nil)) { try WordListResources.data(named: "none", as: .index) }
    }

    private func filesOnDisk() throws -> [String] {
        let directory = try #require(WordListResources.directory())
        return try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    @Test("every language in the index has a file, and every file but the index is in the index")
    func parity() throws {
        let indexed = try WordLists.load().languages.map { "\($0.code).json" }.sorted()
        let files = try filesOnDisk()
        #expect(files.contains("index.json"))
        #expect(files.filter { $0 != "index.json" } == indexed)
    }

    @Test("each file is named for a language code")
    func fileNames() throws {
        let codes = Set(TailoringLanguage.allCases.map(\.code))
        for file in try filesOnDisk() where file != "index.json" {
            #expect(codes.contains(String(file.dropLast(".json".count))), "\(file) is no language")
            #expect(file.hasSuffix(".json"), "\(file) is no JSON file")
        }
    }

    // MARK: - Source and licence

    /// Every list of a language, by key, with what it states about itself. Naming every list here is the check that the
    /// table below, and the format, leave none out.
    private func summary(of lists: LanguageWordLists) -> [WordListKey: (source: String, licence: String, count: Int)] {
        func row<Entry>(_ list: WordList<Entry>) -> (source: String, licence: String, count: Int) { (list.source, list.licence, list.entries.count) }
        var rows: [WordListKey: (source: String, licence: String, count: Int)] = [:]
        rows[.advertStopwords] = row(lists.advert.stopwords)
        rows[.advertPlainWords] = row(lists.advert.plainWords)
        rows[.advertDimensions] = row(lists.advert.dimensions)
        rows[.advertBoilerplate] = row(lists.advert.boilerplate)
        rows[.advertGenderMarkers] = row(lists.advert.genderMarkers)
        rows[.advertInstructions] = row(lists.advert.instructions)
        rows[.advertStreets] = row(lists.advert.streets.list)
        rows[.advertNames] = row(lists.advert.names)
        rows[.advertSynonyms] = row(lists.advert.synonyms)
        rows[.advertRequirementHeadings] = row(lists.advert.requirementHeadings)
        rows[.advertOfferHeadings] = row(lists.advert.offerHeadings)
        rows[.advertStructuralHeadings] = row(lists.advert.structuralHeadings)
        rows[.datesMonths] = row(lists.dates.months)
        rows[.datesPresentWords] = row(lists.dates.presentWords)
        rows[.datesSinceWords] = row(lists.dates.sinceWords)
        rows[.datesRangeSeparatorWords] = row(lists.dates.rangeSeparatorWords)
        rows[.datesDurationUnitWords] = row(lists.dates.durationUnitWords)
        rows[.numbersWords] = row(lists.numbers.words)
        rows[.spansFloorLeadIns] = row(lists.spans.floorLeadIns)
        rows[.spansYearWords] = row(lists.spans.yearWords)
        rows[.spansMonthWords] = row(lists.spans.monthWords)
        rows[.spansCountWords] = row(lists.spans.countWords)
        rows[.spansTiedCounts] = row(lists.spans.tiedCounts)
        rows[.spansEmployerEndWords] = row(lists.spans.employerEndWords)
        rows[.letterGreetings] = row(lists.letter.greetings)
        rows[.letterSalutations] = row(lists.letter.salutations)
        rows[.letterAddressees] = row(lists.letter.addressees)
        rows[.letterAddresseesAtClauseEnd] = row(lists.letter.addresseesAtClauseEnd)
        rows[.letterAddresseeNouns] = row(lists.letter.addresseeNouns)
        rows[.letterValedictions] = row(lists.letter.valedictions)
        rows[.letterSalaryExpectationAsks] = row(lists.letter.salaryExpectationAsks)
        rows[.letterStartDateAsks] = row(lists.letter.startDateAsks)
        rows[.letterStatedTermWords] = row(lists.letter.statedTermWords)
        rows[.letterFormsOfAddress] = row(lists.letter.formsOfAddress)
        rows[.letterAcademicTitles] = row(lists.letter.academicTitles)
        rows[.letterNotGivenNames] = row(lists.letter.notGivenNames)
        rows[.provenanceNotPlurals] = row(lists.provenance.notPlurals)
        rows[.provenanceLegalForms] = row(lists.provenance.legalForms)
        rows[.provenanceFirstPerson] = row(lists.provenance.firstPerson)
        rows[.provenanceRanks] = row(lists.provenance.ranks)
        rows[.fieldsTechnologies] = row(lists.technologies)
        return rows
    }

    @Test("every list of every language states a source and a licence from the allowed set")
    func sourceAndLicence() throws {
        let lists = try WordLists.load()
        for language in lists.languages {
            let rows = summary(of: try lists.forLanguage(language))
            #expect(Set(rows.keys) == Set(WordListKey.allCases), "\(language) is missing a list in this test")
            for (key, row) in rows {
                #expect(!row.source.isEmpty, "\(language) \(key.rawValue) has no source")
                #expect(WordListFormat.allowedLicences.contains(row.licence), "\(language) \(key.rawValue) is under \(row.licence)")
            }
        }
    }

    // MARK: - English holds what cv-giovanni holds

    /// The number of entries of each list in cv-giovanni at commit 6e28147, counted from the source. Every list of the
    /// English file is ported from it, so a list that loses an entry, or one that is not ported, fails here.
    private static let countsAtSource: [WordListKey: Int] = {
        var counts: [WordListKey: Int] = [:]
        counts[.advertStopwords] = 159  // domain/AdvertLexicon.js ADVERT.stopwords.en
        counts[.advertPlainWords] = 10  // ADVERT.plainWords.en
        counts[.advertDimensions] = 5  // ADVERT.dimensions.en
        counts[.advertBoilerplate] = 28  // ADVERT.boilerplate.en
        counts[.advertGenderMarkers] = 2  // ADVERT.genderMarkers.en
        counts[.advertInstructions] = 8  // ADVERT.instructions.en
        counts[.advertStreets] = 9  // ADVERT.streets.en
        counts[.advertNames] = 25  // ADVERT.names.en
        counts[.advertSynonyms] = 16  // ADVERT.synonyms: 17 groups, and "architecture" has one English form, so no synonym
        counts[.advertRequirementHeadings] = 10  // ADVERT.requirementHeadings.en
        counts[.advertOfferHeadings] = 8  // ADVERT.offerHeadings.en
        counts[.advertStructuralHeadings] = 12  // ADVERT.structuralHeadings.en
        counts[.datesMonths] = 24  // domain/DateRange.js MONTHS.en: 12 names and 12 abbreviations
        counts[.datesPresentWords] = 4  // PRESENT: present, now, current, ongoing; the other seven words are German and Italian
        counts[.datesSinceWords] = 1  // SINCE: since; seit, dal and da are German and Italian
        counts[.datesRangeSeparatorWords] = 1  // SEPARATOR: to; bis and al are German and Italian
        counts[.datesDurationUnitWords] = 8  // DateRange.parse, the unit after a length: years?, yrs?, months?, mos?, expanded
        counts[.numbersWords] = 30  // core/ProvenanceCheck.js NUMBERS: two to nine, ten to nineteen, the tens, dozen, hundred, thousand, million
        counts[.spansFloorLeadIns] = 3  // domain/StatedSpans.js FLOOR: over, more than, at least
        counts[.spansYearWords] = 2  // UNIT: year, years
        counts[.spansMonthWords] = 2  // UNIT: month, months
        counts[.spansCountWords] = 12  // WORDS: one to twelve
        counts[.spansTiedCounts] = 3  // TIED: "of them at", "of which at", "of those at"
        counts[.spansEmployerEndWords] = 1  // EMPLOYER: and; und is German
        counts[.letterGreetings] = 3  // core/ProvenanceCheck.js GREETING: dear, hello, hi
        counts[.letterSalutations] = 1  // SALUTATION: to whom it may concern
        counts[.letterAddressees] = 13  // WHOM: ms, mrs, mr, dr, prof, sir, madam, all, everyone, friends, recruiter(s), colleagues; the other six words are German
        counts[.letterAddresseesAtClauseEnd] = 1  // WHOM: there, which is read only before a comma, a "!" or the end of the text
        counts[.letterAddresseeNouns] = 4  // WHOM: team, manager, committee, department
        counts[.letterValedictions] = 14  // CLOSING: {kind, best, warm, warmest} regards with or without "with", best wishes, 3 yours, 2 sincerely
        counts[.letterSalaryExpectationAsks] = 6  // core/Tailor.js ASKS.salaryExpectation, expanded
        counts[.letterStartDateAsks] = 13  // ASKS.startDate, expanded
        counts[.letterStatedTermWords] = 4  // ASKS: the lookahead's English words, is, of, range, applies
        counts[.letterFormsOfAddress] = 3  // core/ProvenanceCheck.js letterFailures, recipient.form: ms and mrs for ms, mr for mr; frau and herr are German
        counts[.letterAcademicTitles] = 2  // the titles between a form and a name: dr, prof
        counts[.letterNotGivenNames] = 6  // the words that are no given name: ms, mrs, miss, mr, and, or; frau, herr, und, oder and sowie are German
        counts[.provenanceNotPlurals] = 9  // core/ProvenanceCheck.js NOT_PLURALS
        counts[.provenanceLegalForms] = 25  // LEGAL_FORM: its 16 alternatives written out, with and without the optional dots and space
        counts[.provenanceFirstPerson] = 9  // ProvenanceCheck.names: "I" and I'm, I've, I'd, I'll with either apostrophe
        counts[.provenanceRanks] = 10  // RANKS: 8 of its 14 patterns are English, senior, lead|leading, principal, staff, head|chief, director, manager, architect
        counts[.fieldsTechnologies] = 49  // domain/TechnologyLexicon.js TECHNOLOGIES
        return counts
    }()

    @Test("the English file holds as many entries of each list as cv-giovanni does", arguments: WordListKey.allCases)
    func countsMatchTheSource(key: WordListKey) throws {
        let rows = summary(of: try english())
        let row = try #require(rows[key])
        #expect(row.count == Self.countsAtSource[key], "\(key.rawValue)")
    }

    @Test("the table of counts names every list of the format")
    func countsNameEveryList() {
        #expect(Set(Self.countsAtSource.keys) == Set(WordListKey.allCases))
    }

    // MARK: - Every list of at most 50 entries, written out

    @Test("the advert lists are exactly cv-giovanni's")
    func advertLists() throws {
        let lists = try english()
        #expect(lists.advert.plainWords.entries == EnglishExpected.advertPlainWords, "advertPlainWords")
        #expect(lists.advert.dimensions.entries == EnglishExpected.advertDimensions, "advertDimensions")
        #expect(lists.advert.boilerplate.entries == EnglishExpected.advertBoilerplate, "advertBoilerplate")
        #expect(lists.advert.genderMarkers.entries == EnglishExpected.advertGenderMarkers, "advertGenderMarkers")
        #expect(lists.advert.instructions.entries == EnglishExpected.advertInstructions, "advertInstructions")
        #expect(lists.advert.streets.list.entries == EnglishExpected.advertStreets, "advertStreets")
        #expect(lists.advert.names.entries == EnglishExpected.advertNames, "advertNames")
        #expect(lists.advert.synonyms.entries.map(\.forms) == EnglishExpected.advertSynonyms, "advertSynonyms")
        #expect(lists.advert.requirementHeadings.entries == EnglishExpected.advertRequirementHeadings, "advertRequirementHeadings")
        #expect(lists.advert.offerHeadings.entries == EnglishExpected.advertOfferHeadings, "advertOfferHeadings")
        #expect(lists.advert.structuralHeadings.entries == EnglishExpected.advertStructuralHeadings, "advertStructuralHeadings")
    }

    @Test("the date, number and span lists are exactly cv-giovanni's")
    func dateNumberAndSpanLists() throws {
        let lists = try english()
        #expect(lists.dates.months.entries == EnglishExpected.datesMonths, "datesMonths")
        #expect(lists.dates.presentWords.entries == EnglishExpected.datesPresentWords, "datesPresentWords")
        #expect(lists.dates.sinceWords.entries == EnglishExpected.datesSinceWords, "datesSinceWords")
        #expect(lists.dates.rangeSeparatorWords.entries == EnglishExpected.datesRangeSeparatorWords, "datesRangeSeparatorWords")
        #expect(lists.dates.durationUnitWords.entries == EnglishExpected.datesDurationUnitWords, "datesDurationUnitWords")
        #expect(lists.numbers.words.entries == EnglishExpected.numbersWords, "numbersWords")
        #expect(lists.spans.floorLeadIns.entries == EnglishExpected.spansFloorLeadIns, "spansFloorLeadIns")
        #expect(lists.spans.yearWords.entries == EnglishExpected.spansYearWords, "spansYearWords")
        #expect(lists.spans.monthWords.entries == EnglishExpected.spansMonthWords, "spansMonthWords")
        #expect(lists.spans.countWords.entries == EnglishExpected.spansCountWords, "spansCountWords")
        #expect(lists.spans.tiedCounts.entries == EnglishExpected.spansTiedCounts, "spansTiedCounts")
        #expect(lists.spans.employerEndWords.entries == EnglishExpected.spansEmployerEndWords, "spansEmployerEndWords")
    }

    @Test("the letter lists are exactly cv-giovanni's")
    func letterLists() throws {
        let lists = try english()
        #expect(lists.letter.greetings.entries == EnglishExpected.letterGreetings, "letterGreetings")
        #expect(lists.letter.salutations.entries == EnglishExpected.letterSalutations, "letterSalutations")
        #expect(lists.letter.addressees.entries == EnglishExpected.letterAddressees, "letterAddressees")
        #expect(lists.letter.addresseesAtClauseEnd.entries == EnglishExpected.letterAddresseesAtClauseEnd, "letterAddresseesAtClauseEnd")
        #expect(lists.letter.addresseeNouns.entries == EnglishExpected.letterAddresseeNouns, "letterAddresseeNouns")
        #expect(lists.letter.valedictions.entries == EnglishExpected.letterValedictions, "letterValedictions")
        #expect(lists.letter.salaryExpectationAsks.entries == EnglishExpected.letterSalaryExpectationAsks, "letterSalaryExpectationAsks")
        #expect(lists.letter.startDateAsks.entries == EnglishExpected.letterStartDateAsks, "letterStartDateAsks")
        #expect(lists.letter.statedTermWords.entries == EnglishExpected.letterStatedTermWords, "letterStatedTermWords")
        #expect(lists.letter.formsOfAddress.entries == EnglishExpected.letterFormsOfAddress, "letterFormsOfAddress")
        #expect(lists.letter.academicTitles.entries == EnglishExpected.letterAcademicTitles, "letterAcademicTitles")
        #expect(lists.letter.notGivenNames.entries == EnglishExpected.letterNotGivenNames, "letterNotGivenNames")
    }

    @Test("the provenance lists and the technologies are exactly cv-giovanni's")
    func provenanceAndTechnologyLists() throws {
        let lists = try english()
        #expect(lists.provenance.ranks.entries == EnglishExpected.provenanceRanks, "provenanceRanks")
        #expect(lists.provenance.notPlurals.entries == EnglishExpected.provenanceNotPlurals, "provenanceNotPlurals")
        #expect(lists.provenance.legalForms.entries == EnglishExpected.provenanceLegalForms, "provenanceLegalForms")
        #expect(lists.provenance.firstPerson.entries == EnglishExpected.provenanceFirstPerson, "provenanceFirstPerson")
        #expect(lists.technologies.entries == EnglishExpected.fieldsTechnologies, "fieldsTechnologies")
    }

    /// FNV-1a 64 over the UTF-8 bytes: a stable digest the test can compute without a library.
    private func fnv1a64(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// The 159 stopwords are too many to write out. Their digest is that of `ADVERT.stopwords.en` of cv-giovanni at 6e28147,
    /// joined by a line feed. With `domain/AdvertLexicon.js` and `domain/fold.js` saved from `git show 6e28147:<path>` in
    /// one directory, run in it:
    ///
    ///     node --input-type=module -e "import {ADVERT} from './AdvertLexicon.js'; let h=0xcbf29ce484222325n; for (const b of Buffer.from(ADVERT.stopwords.en.join('\n'))) h=((h^BigInt(b))*0x100000001b3n)&0xffffffffffffffffn; console.log(h.toString(16))"
    @Test("the stopwords are exactly cv-giovanni's, by their count, their first and last and their digest")
    func stopwords() throws {
        let stopwords = try english().advert.stopwords.entries
        #expect(stopwords.count == 159)
        #expect(stopwords.first == "the" && stopwords.last == "optimise")
        #expect(fnv1a64(stopwords.joined(separator: "\n")) == 0x9ebb_4a5a_802e_5cf6)
    }

    @Test("the months, with and without an abbreviation, carry their numbers")
    func months() throws {
        let months = try english().dates.months.entries
        func month(_ name: String) -> Int? { months.first { $0.name == name }?.month }
        #expect(month("january") == 1 && month("jan") == 1 && month("may") == 5 && month("sept") == 9 && month("sep") == 9)
        #expect(month("december") == 12 && month("dec") == 12 && month("mai") == nil && month("marz") == nil)
        #expect(Set(months.map(\.month)) == Set(1...12))
    }

    @Test("the number words carry their values, and one is not among them")
    func numberWords() throws {
        let words = try english().numbers.words.entries
        func value(_ word: String) -> Int? { words.first { $0.word == word }?.value }
        #expect(value("two") == 2 && value("nineteen") == 19 && value("twenty") == 20 && value("ninety") == 90)
        #expect(value("dozen") == 12 && value("hundred") == 100 && value("thousand") == 1000 && value("million") == 1_000_000)
        #expect(value("one") == nil)
        let counts = try english().spans.countWords.entries
        #expect(counts.first == NumberWord(word: "one", value: 1) && counts.last == NumberWord(word: "twelve", value: 12))
    }

    static let ordinaryWordsStayOutCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["Swift", "React", "Combine", "Room"])
        values.append(contentsOf: ["Realm", "Go", "Rust", "Flutter"])
        values.append(contentsOf: ["Espresso"])
        return values
    }()

    @Test("a technology that is also an ordinary word stays out, as the source's lexicon explains", arguments: ordinaryWordsStayOutCases)
    func ordinaryWordsStayOut(name: String) throws {
        let technologies = try english().technologies.entries.map(TextFold.fold)
        #expect(!technologies.contains(TextFold.fold(name)))
    }

}
