import Testing
import Foundation
@testable import TailoringModel

/// The English file against cv-giovanni at commit 6e28147, and the bundled files against the index.
@Suite("ADR 0013 / R13 · the bundled word lists (#136)")
struct EnglishWordListsTests {
    private func english() throws -> LanguageWordLists { try WordLists.load().forLanguage(.english) }

    @Test("the bundled lists load, and English is the one language with a file")
    func loads() throws {
        let lists = try WordLists.load()
        #expect(lists.languages == [.english])
        #expect(try lists.forLanguage(.english).language == .english)
    }

    @Test("every other language is unsupported until it has a file", arguments: TailoringLanguage.allCases.filter { $0 != .english })
    func unsupported(language: TailoringLanguage) throws {
        let lists = try WordLists.load()
        #expect(throws: TailoringModelError.unsupportedLanguage) { try lists.forLanguage(language) }
    }

    // MARK: - The directory and the index

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

    /// Every list of a language, by key, with what it states about itself. Naming all 28 here is the check that the
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

    @Test("the small English lists are exactly cv-giovanni's")
    func smallLists() throws {
        let lists = try english()
        #expect(lists.advert.genderMarkers.entries == ["all genders", "any gender"])
        #expect(lists.advert.plainWords.entries == ["new", "time", "set", "use", "get", "make", "keep", "drive", "after", "knowledge"])
        #expect(lists.advert.dimensions.entries == ["performance", "stability", "quality", "speed", "efficiency"])
        #expect(lists.advert.requirementHeadings.entries.first == "requirements" && lists.advert.requirementHeadings.entries.last == "we are looking for")
        #expect(lists.advert.offerHeadings.entries.first == "we offer" && lists.advert.offerHeadings.entries.last == "how we work")
        #expect(lists.advert.structuralHeadings.entries.first == "role" && lists.advert.structuralHeadings.entries.last == "location")
        #expect(lists.advert.streets.order == .after)
        #expect(lists.advert.streets.list.entries == ["street", "st.", "road", "rd.", "avenue", "ave.", "lane", "boulevard", "blvd."])
        #expect(lists.spans.floorLeadIns.entries == ["over", "more than", "at least"])
        #expect(lists.spans.yearWords.entries == ["year", "years"] && lists.spans.monthWords.entries == ["month", "months"])
        #expect(lists.spans.tiedCounts.entries == ["{count} of them at {employer}", "{count} of which at {employer}", "{count} of those at {employer}"])
        #expect(lists.spans.employerEndWords.entries == ["and"])
        #expect(lists.letter.statedTermWords.entries == ["is", "of", "range", "applies"])
    }

    @Test("the stopwords open and close as cv-giovanni's do")
    func stopwords() throws {
        let stopwords = try english().advert.stopwords.entries
        #expect(stopwords.first == "the" && stopwords.last == "optimise")
        #expect(stopwords.contains("hands-on") && stopwords.contains("please"))
    }

    @Test("the months, with and without an abbreviation, carry their numbers")
    func months() throws {
        let months = try english().dates.months.entries
        func month(_ name: String) -> Int? { months.first { $0.name == name }?.month }
        #expect(month("january") == 1 && month("jan") == 1 && month("may") == 5 && month("sept") == 9 && month("sep") == 9)
        #expect(month("december") == 12 && month("dec") == 12 && month("mai") == nil && month("marz") == nil)
        #expect(Set(months.map(\.month)) == Set(1...12))
    }

    @Test("the words of a period written in text are cv-giovanni's")
    func periodWords() throws {
        let dates = try english().dates
        #expect(dates.presentWords.entries == ["present", "now", "current", "ongoing"])
        #expect(dates.sinceWords.entries == ["since"])
        #expect(dates.rangeSeparatorWords.entries == ["to"])
        #expect(dates.durationUnitWords.entries == ["year", "years", "yr", "yrs", "month", "months", "mo", "mos"])
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

    @Test("the synonyms are the English forms of cv-giovanni's groups")
    func synonyms() throws {
        let groups = try english().advert.synonyms.entries.map(\.forms)
        #expect(groups.first == ["mdm", "mobile device management"])
        #expect(groups.contains(["ci/cd", "continuous integration", "continuous delivery", "continuous deployment"]))
        #expect(groups.contains(["developer", "developers", "engineer", "engineers"]))
        #expect(groups.last == ["mobile development", "mobile app development"])
        #expect(groups.allSatisfy { $0.count >= 2 })
    }

    @Test("the valedictions are the forms the regular expression allows, written out")
    func valedictions() throws {
        let valedictions = try english().letter.valedictions.entries
        #expect(valedictions.contains("kind regards") && valedictions.contains("with warmest regards") && valedictions.contains("yours faithfully"))
        #expect(valedictions.contains("sincerely") && valedictions.contains("sincerely yours") && valedictions.contains("best wishes"))
    }

    @Test("the asks are the phrases the regular expressions allow, written out")
    func asks() throws {
        let letter = try english().letter
        #expect(letter.salaryExpectationAsks.entries == [
            "salary expectation", "salary expectations", "salary requirement", "salary requirements", "expected salary", "desired salary",
        ])
        #expect(letter.startDateAsks.entries.contains("earliest possible start date") && letter.startDateAsks.entries.contains("notice period"))
        #expect(letter.startDateAsks.entries.contains("when you could start") && letter.startDateAsks.entries.contains("availability date"))
    }

    static let ordinaryWordsStayOutCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["Swift", "React", "Combine", "Room"])
        values.append(contentsOf: ["Realm", "Go", "Rust", "Flutter"])
        values.append(contentsOf: ["Espresso"])
        return values
    }()

    @Test("the words that follow a greeting are split by how they are read")
    func addressees() throws {
        let letter = try english().letter
        #expect(letter.addresseesAtClauseEnd.entries == ["there"])
        #expect(!letter.addressees.entries.contains("there"))
        #expect(letter.addressees.entries == ["ms", "mrs", "mr", "dr", "prof", "sir", "madam", "all", "everyone", "friends", "recruiter", "recruiters", "colleagues"])
    }

    @Test("the words of the form of address check are cv-giovanni's")
    func formsOfAddress() throws {
        let letter = try english().letter
        #expect(letter.formsOfAddress.entries == [
            FormOfAddressWord(form: .ms, word: "ms"), FormOfAddressWord(form: .ms, word: "mrs"), FormOfAddressWord(form: .mr, word: "mr"),
        ])
        #expect(letter.academicTitles.entries == ["dr", "prof"])
        #expect(letter.notGivenNames.entries == ["ms", "mrs", "miss", "mr", "and", "or"])
    }

    @Test("the words the provenance check reads for English are cv-giovanni's")
    func provenanceWords() throws {
        let provenance = try english().provenance
        #expect(provenance.notPlurals.entries == ["news", "goods", "means", "series", "species", "lens", "gas", "bus", "sales"])
        #expect(provenance.ranks.entries.map(\.word) == ["senior", "lead", "leading", "principal", "staff", "head", "chief", "director", "manager", "architect"])
        #expect(provenance.ranks.entries.first == RankWord(word: "senior", ranks: [.senior]))
        #expect(provenance.ranks.entries.first { $0.word == "chief" }?.ranks == [.head])
        #expect(provenance.ranks.entries.first { $0.word == "leading" }?.ranks == [.lead])
        #expect(provenance.firstPerson.entries == ["I", "I'm", "I've", "I'd", "I'll", "I\u{2019}m", "I\u{2019}ve", "I\u{2019}d", "I\u{2019}ll"])
        let forms = provenance.legalForms.entries
        for form in ["gmbh", "ggmbh", "ag", "ltd", "ltd.", "limited", "inc", "inc.", "llc", "plc", "e.v.", "e. v.", "s.a.", "b.v."] {
            #expect(forms.contains(form), "\(form)")
        }
        #expect(forms.contains("gmbh & co. kg") && forms.contains("gmbh & co kgaa") && forms.contains("ug (haftungsbeschr\u{00E4}nkt)"))
    }

    @Test("a technology that is also an ordinary word stays out, as the source's lexicon explains", arguments: ordinaryWordsStayOutCases)
    func ordinaryWordsStayOut(name: String) throws {
        let technologies = try english().technologies.entries.map(TextFold.fold)
        #expect(!technologies.contains(TextFold.fold(name)))
    }

    @Test("the technologies hold names that no other word has")
    func technologies() throws {
        let technologies = try english().technologies.entries
        #expect(technologies.first == "Kotlin" && technologies.last == "PyTorch")
        #expect(technologies.contains("SwiftUI") && technologies.contains("fastlane") && technologies.contains("Node.js"))
    }
}
