import Testing
import TailoringModel

/// The targets that read word lists (AdvertAnalysis, ContentChecks, Provenance) build small lists in their tests without a
/// file. This file imports the module without `@testable`, as such a target does, so only `package` access is in reach.
@Suite("ADR 0013 · word lists built without files, for the tests of the other targets of the package (#136)")
struct PackageInitialisersTests {
    private func words(_ entries: String...) -> WordList<String> {
        WordList(source: "a test", licence: "ISC", entries: entries)
    }

    private func months() -> WordList<MonthName> {
        var entries: [MonthName] = []
        for month in 1...12 { entries.append(MonthName(name: "month\(month)", month: month)) }
        return WordList(source: "a test", licence: "ISC", entries: entries)
    }

    private func numbers() -> WordList<NumberWord> {
        WordList(source: "a test", licence: "ISC", entries: [NumberWord(word: "two", value: 2)])
    }

    private func smallLists(language: TailoringLanguage = .english) -> LanguageWordLists {
        let advert = AdvertWords(
            stopwords: words("the"), plainWords: words("new"), dimensions: words("speed"), boilerplate: words("full time"),
            genderMarkers: words("all genders"), instructions: words("please state"),
            streets: StreetWords(list: words("street"), order: .after), names: words("github actions"),
            synonyms: WordList(source: "a test", licence: "ISC", entries: [SynonymGroup(forms: ["ui", "user interface"])]),
            requirementHeadings: words("requirements"), offerHeadings: words("we offer"), structuralHeadings: words("role")
        )
        let dates = DateWords(
            months: months(), presentWords: words("present"), sinceWords: words("since"), rangeSeparatorWords: words("to"),
            durationUnitWords: words("years")
        )
        let spans = SpanWords(
            floorLeadIns: words("over"), yearWords: words("year"), monthWords: words("month"),
            countWords: WordList(source: "a test", licence: "ISC", entries: [NumberWord(word: "one", value: 1)]),
            tiedCounts: words("{count} of them at {employer}"), employerEndWords: words("and")
        )
        let letter = LetterWords(
            greetings: words("dear"), salutations: words("to whom it may concern"), addressees: words("mr"),
            addresseesAtClauseEnd: words("there"), addresseeNouns: words("team"), valedictions: words("kind regards"),
            salaryExpectationAsks: words("salary expectation"), startDateAsks: words("start date"), statedTermWords: words("is"),
            formsOfAddress: WordList(source: "a test", licence: "ISC", entries: [FormOfAddressWord(form: .mr, word: "mr")]),
            academicTitles: words("dr"), notGivenNames: words("and")
        )
        let provenance = ProvenanceWords(
            notPlurals: words("news"), legalForms: words("ltd"), firstPerson: words("I"),
            ranks: WordList(source: "a test", licence: "ISC", entries: [RankWord(word: "senior", ranks: [.senior])])
        )
        return LanguageWordLists(
            language: language, advert: advert, dates: dates, numbers: NumberWords(words: numbers()), spans: spans, letter: letter,
            provenance: provenance, technologies: words("Kotlin")
        )
    }

    @Test("a small set of word lists is built from the package's initialisers, and reads back as it was built")
    func builds() {
        let lists = smallLists()
        #expect(lists.language == .english)
        #expect(lists.advert.stopwords.entries == ["the"] && lists.advert.streets.order == .after)
        #expect(lists.dates.months.entries.count == 12 && lists.numbers.words.entries == [NumberWord(word: "two", value: 2)])
        #expect(lists.spans.tiedCounts.entries == ["{count} of them at {employer}"])
        #expect(lists.letter.formsOfAddress.entries == [FormOfAddressWord(form: .mr, word: "mr")])
        #expect(lists.provenance.ranks.entries == [RankWord(word: "senior", ranks: [.senior])])
        #expect(lists.technologies.entries == ["Kotlin"])
    }

    @Test("two sets built alike are equal, and one built for another language is not")
    func equality() {
        #expect(smallLists() == smallLists())
        #expect(smallLists() != smallLists(language: .german))
    }
}
