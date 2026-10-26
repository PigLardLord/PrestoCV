import Testing
import Foundation
import CVGeneratorAI

// A value of an entry (a job or a school) is the entry's own only when the sentence that names its employer or school says
// it. These tests move dates, titles and places between the entries of a draft, as the model does, and check where the
// counter puts them: a year of the sentence of another entry is invented, a title taken from the headline is a doubt for a
// reviewer, a title only the entry's own sentence says is a quote.

@Suite("Invented facts: a value belongs to the entry whose sentence says it")
struct InventedFactsEntryTests {
    // MARK: - The sentences

    @Test("A description is cut at . ! ? ; … and at a new line, and an email or a decimal stays whole")
    func sentences() {
        let text = "Mail me at a.b@x.com. Pay 4.5 euro! Really? Yes; no… ok\nnew line"

        #expect(InventedFacts.sentences(of: text) == [
            ["mail", "me", "at", "a", "b", "x", "com"], ["pay", "4", "5", "euro"], ["really"], ["yes"], ["no"], ["ok"],
            ["new", "line"],
        ])
    }

    @Test("Each employer and school of an input is named by one sentence of its own", arguments: DraftingInputs.languages)
    func everyEntryHasASentence(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            let sentences = InventedFacts.sentences(of: input.description)
            let entries = input.facts.filter { $0.kind == .employer || $0.kind == .school }
            var named: [Int] = []
            for fact in entries {
                let holding = sentences.indices.filter { index in
                    fact.forms.contains { InventedFacts.holds(sentences[index], run: InventedFacts.words(of: $0)) }
                }
                #expect(holding.count == 1, "\(input.id): \(fact) is named by \(holding.count) sentences")
                named += holding
            }
            #expect(Set(named).count == named.count, "\(input.id): two entries share a sentence")
        }
    }

    // MARK: - Dates

    @Test("The dates of the entry's own sentence are quotes, and the present of a job that began is derived",
          arguments: EntryYears.all)
    func datesOfTheEntry(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[0] = Experience(company: draft.experience[0].company, startDate: years.since, endDate: years.present)
        draft.experience[1] = Experience(company: draft.experience[1].company, startDate: years.from, endDate: years.until)
        draft.education = [Education(institution: draft.education[0].institution, endDate: years.graduated)]

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.toReview.isEmpty, "\(report.toReview)")
        #expect(report.finding(at: "experience[0].startDate")?.kind == .quote)
        #expect(report.finding(at: "experience[0].endDate")?.kind == .derived)
        #expect(report.finding(at: "experience[1].startDate")?.kind == .quote)
        #expect(report.finding(at: "experience[1].endDate")?.kind == .quote)
        #expect(report.finding(at: "education[0].endDate")?.kind == .quote)
    }

    @Test("A year the description gives to another entry is invented in this one", arguments: EntryYears.all)
    func yearOfAnotherEntry(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[0] = Experience(company: draft.experience[0].company, startDate: years.from, endDate: years.graduated)

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.map(\.path) == ["experience[0].startDate", "experience[0].endDate"], "\(report.findings)")
        #expect(report.invented.allSatisfy { $0.reason.contains("another entry") }, "\(report.invented)")
    }

    @Test("A job that starts after it ends is invented, in both of its dates", arguments: EntryYears.all)
    func swappedDates(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[1] = Experience(company: draft.experience[1].company, startDate: years.until, endDate: years.from)

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.map(\.path) == ["experience[1].startDate", "experience[1].endDate"], "\(report.findings)")
        #expect(report.invented.allSatisfy { $0.reason.contains("starts after") }, "\(report.invented)")
    }

    @Test("A year the description lacks is invented, on a job and on a school", arguments: EntryYears.all)
    func yearTheDescriptionLacks(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[0] = Experience(company: draft.experience[0].company, startDate: years.missing)
        draft.education = [Education(institution: draft.education[0].institution, endDate: years.missing)]

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.map(\.path) == ["experience[0].startDate", "education[0].endDate"], "\(report.findings)")
        #expect(report.invented.allSatisfy { $0.reason.contains("a year the description lacks") }, "\(report.invented)")
    }

    @Test("A month or a day the entry's sentence does not give is invented, even under a year it gives",
          arguments: EntryYears.all)
    func monthsAndDaysAreNotInvented(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[0] = Experience(company: draft.experience[0].company, startDate: "\(years.since)-03")
        draft.experience[1] = Experience(
            company: draft.experience[1].company, startDate: "\(years.from)-01-01", endDate: "\(years.until)-06-30"
        )
        draft.education = [Education(
            institution: draft.education[0].institution, startDate: "09/\(years.graduated)", endDate: "\(years.graduated)-03"
        )]

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.map(\.path) == [
            "experience[0].startDate", "experience[1].startDate", "experience[1].endDate", "education[0].startDate",
            "education[0].endDate",
        ], "\(report.findings)")
    }

    @Test("A year of the school's sentence with a month is invented in a job that never says it", arguments: EntryYears.all)
    func monthOfAnotherEntry(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[0] = Experience(company: draft.experience[0].company, startDate: "\(years.graduated)-03")

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.map(\.path) == ["experience[0].startDate"], "\(report.findings)")
    }

    @Test("A month named by the sentence, in words or in figures, makes the ISO date derived; another month is invented")
    func monthNamedByTheSentence() {
        let named = "I worked at Acme Foods from March 2019 to May 2021."
        let figures = "I worked at Acme Foods from 03/2019 to 05/2021."
        for description in [named, figures] {
            func report(_ start: String, _ end: String) -> InventedFacts.Report {
                InventedFacts.count(
                    CVData(experience: [Experience(company: "Acme Foods", startDate: start, endDate: end)]),
                    description: description
                )
            }

            let right = report("2019-03", "2021-05")
            #expect(right.finding(at: "experience[0].startDate")?.kind == .derived, "\(description): \(right.findings)")
            #expect(right.finding(at: "experience[0].endDate")?.kind == .derived, "\(description): \(right.findings)")

            let wrong = report("2019-04", "2021-05-15")
            #expect(wrong.finding(at: "experience[0].startDate")?.kind == .invented, "\(description): \(wrong.findings)")
            #expect(wrong.finding(at: "experience[0].endDate")?.kind == .invented, "\(description): \(wrong.findings)")

            let years = report("2019", "2021")
            #expect(years.finding(at: "experience[0].startDate")?.kind == .quote, "\(description): \(years.findings)")
            #expect(years.finding(at: "experience[0].endDate")?.kind == .quote, "\(description): \(years.findings)")
        }
    }

    @Test("The present is derived for a job whose sentence gives one year, and a doubt for any other entry",
          arguments: EntryYears.all)
    func presentNeedsOneYear(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[0] = Experience(company: draft.experience[0].company, endDate: years.present)
        draft.experience[1] = Experience(company: draft.experience[1].company, startDate: years.present, endDate: years.present)
        draft.education = [Education(institution: draft.education[0].institution, endDate: years.present)]

        let report = InventedFacts.count(draft.cv, for: try InventedFactsTests.input(years.input))

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.finding(at: "experience[0].endDate")?.kind == .derived)
        #expect(report.finding(at: "experience[1].startDate")?.kind == .review)
        #expect(report.finding(at: "experience[1].endDate")?.kind == .review)
        #expect(report.finding(at: "education[0].endDate")?.kind == .review)
    }

    @Test("The present is a quote for the entry whose sentence says it, and not for another entry", arguments: PresentCase.all)
    func presentOfTheEntry(_ item: PresentCase) {
        let report = InventedFacts.count(item.cv, description: item.description)

        let finding = report.finding(at: item.path)
        #expect(finding?.kind == item.kind, "\(item): \(report.findings)")
        #expect(finding?.reason.contains(item.reason) == true, "\(item): \(finding?.reason ?? "no finding")")
    }

    @Test("The later year of a job as its start, or the earlier as its end, is a doubt", arguments: EntryYears.all)
    func yearInTheWrongRole(_ years: EntryYears) throws {
        var draft = try years.draft()
        draft.experience[1] = Experience(company: draft.experience[1].company, startDate: years.until)
        draft.education = []
        var other = draft
        other.experience[1] = Experience(company: other.experience[1].company, endDate: years.from)
        let input = try InventedFactsTests.input(years.input)

        let start = InventedFacts.count(draft.cv, for: input)
        let end = InventedFacts.count(other.cv, for: input)

        #expect(start.invented.isEmpty, "\(start.invented)")
        #expect(start.finding(at: "experience[1].startDate")?.kind == .review)
        #expect(end.invented.isEmpty, "\(end.invented)")
        #expect(end.finding(at: "experience[1].endDate")?.kind == .review)
    }

    @Test("A date of a certification, which no sentence owns, is a quote or a year of the description")
    func certificationDate() {
        let description = "I passed the Safety Exam in 2021 and the Forklift Exam in March 2019."
        func finding(_ date: String) -> InventedFacts.Finding? {
            InventedFacts.count(
                CVData(certifications: [Certification(name: "Safety Exam", date: date)]), description: description
            ).finding(at: "certifications[0].date")
        }

        #expect(finding("2021")?.kind == .quote)
        #expect(finding("2019-03")?.kind == .derived)
        #expect(finding("2019-01")?.kind == .invented)
        #expect(finding("2018")?.kind == .invented)
    }

    // MARK: - Titles and places

    @Test("A job title the sentence of another job gives is invented; the job's own is a quote",
          arguments: [
              ("en-plain", "forklift driver"), ("it-plain", "aiuto cuoco"), ("de-plain", "Monteur"),
              ("es-plain", "maquetadora"), ("fr-plain", "vendeuse"),
          ])
    func titleOfAnotherJob(_ id: String, _ title: String) throws {
        let input = try InventedFactsTests.input(id)
        var draft = Draft(faithfulTo: input)
        draft.experience[1] = Experience(title: title, company: draft.experience[1].company)

        let own = InventedFacts.count(draft.cv, for: input)
        #expect(own.finding(at: "experience[1].title")?.kind == .quote, "\(own.findings)")

        draft.experience[0] = Experience(title: title, company: draft.experience[0].company)
        let moved = InventedFacts.count(draft.cv, for: input)

        #expect(moved.invented.map(\.path) == ["experience[0].title"], "\(moved.findings)")
        #expect(moved.invented.first?.reason.contains("another entry") == true, "\(moved.invented)")
    }

    @Test("The title of the headline on a job whose sentence lacks it is a doubt, named with its job",
          arguments: DraftingInputs.written)
    func headlineTitleOnAJob(_ input: DraftingInput) throws {
        let title = try #require(input.facts.first { $0.kind == .title }).forms[0]
        var draft = Draft(faithfulTo: input)
        draft.experience[0] = Experience(title: title, company: draft.experience[0].company)

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        let finding = try #require(report.finding(at: "experience[0].title"))
        #expect(finding.kind == .review, "\(finding)")
        #expect(finding.context?.contains(draft.experience[0].company) == true, "\(finding)")
    }

    @Test("A place of the sentence of another job is invented; one taken from the employer's name is a doubt")
    func placeOfAJob() {
        let description = "Since 2019 I have worked at Northfield Logistics in Leeds. From 2014 to 2019 I was a driver at Kestrel Foods in York."
        func finding(_ location: String, job: Int) -> InventedFacts.Finding? {
            InventedFacts.count(
                CVData(experience: [Experience(company: "Northfield Logistics"), Experience(company: "Kestrel Foods")]
                    .enumerated().map { index, entry in
                        index == job ? Experience(company: entry.company, location: location) : entry
                    }),
                description: description
            ).finding(at: "experience[\(job)].location")
        }

        #expect(finding("Leeds", job: 0)?.kind == .quote)
        #expect(finding("York", job: 1)?.kind == .quote)
        #expect(finding("York", job: 0)?.kind == .invented)
        #expect(finding("Leeds", job: 1)?.kind == .invented)
        #expect(finding("Logistics", job: 0)?.kind == .review)
        #expect(finding("Atlantis", job: 0)?.kind == .invented)
    }

    @Test("A job no sentence names has no owner: what it holds is a doubt, and its title does not keep the person's title",
          arguments: DraftingInputs.written)
    func jobWithoutOwner(_ input: DraftingInput) throws {
        let title = try #require(input.facts.first { $0.kind == .title }).forms[0]
        var draft = Draft(faithfulTo: input)
        draft.title = nil
        draft.experience = [Experience(title: title, company: "Harbour Freight", startDate: "2001")]

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path) == ["experience[0].company", "experience[0].startDate"], "\(report.findings)")
        #expect(report.finding(at: "experience[0].title")?.kind == .review)
        #expect(!report.keeps(.title))
        #expect(report.titleAt.isEmpty)
    }

    // MARK: - Where the title is kept

    @Test("The title is kept in the headline or on a job of the description, and the report says which",
          arguments: DraftingInputs.written)
    func titleKeptWhere(_ input: DraftingInput) throws {
        let title = try #require(input.facts.first { $0.kind == .title }).forms[0]
        var draft = Draft(faithfulTo: input)

        draft.title = title
        let headline = InventedFacts.count(draft.cv, for: input)
        #expect(headline.keeps(.title))
        #expect(headline.titleInHeadline)
        #expect(headline.titleAt == ["personalInfo.title"])

        draft.title = nil
        draft.experience[0] = Experience(title: title, company: draft.experience[0].company)
        let job = InventedFacts.count(draft.cv, for: input)
        #expect(job.keeps(.title))
        #expect(!job.titleInHeadline)
        #expect(job.titleAt == ["experience[0].title"])

        draft.experience[0] = Experience(company: draft.experience[0].company)
        let none = InventedFacts.count(draft.cv, for: input)
        #expect(!none.keeps(.title))
        #expect(none.titleAt.isEmpty)
    }

    // MARK: - Lost dates

    @Test("The years a job or a school gives that the draft does not hold are counted as lost",
          arguments: DraftingInputs.written)
    func lostYears(_ input: DraftingInput) throws {
        var draft = Draft(faithfulTo: input)
        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.lostYears.count == 4, "\(report.lostYears)")
        #expect(Set(report.lostYears.map(\.entry)).count == 3, "\(report.lostYears)")

        let kestrel = try #require(report.lostYears.filter { $0.entry == draft.experience[1].company }.map(\.year).sorted().first)
        draft.experience[1] = Experience(company: draft.experience[1].company, startDate: kestrel)
        let some = InventedFacts.count(draft.cv, for: input)
        #expect(some.lostYears.count == 3, "\(some.lostYears)")
        #expect(!some.lostYears.contains(LostYear(entry: draft.experience[1].company, year: kestrel)), "\(some.lostYears)")
    }
}

typealias LostYear = InventedFacts.LostYear

// MARK: - Cases

/// The years the plain description of an input gives: the first job began in `since`, the second ran from `from` to `until`,
/// the school ended in `graduated`; `missing` is a year the description lacks.
struct EntryYears: Sendable, CustomTestStringConvertible {
    let input: String
    let since: String
    let from: String
    let until: String
    let graduated: String
    let missing: String
    let present: String

    var testDescription: String { input }

    func draft() throws -> Draft { Draft(faithfulTo: try InventedFactsTests.input(input)) }

    static let all: [EntryYears] = [
        EntryYears(input: "en-plain", since: "2019", from: "2014", until: "2019", graduated: "2013", missing: "2015", present: "Present"),
        EntryYears(input: "it-plain", since: "2020", from: "2016", until: "2020", graduated: "2016", missing: "2015", present: "Presente"),
        EntryYears(input: "de-plain", since: "2018", from: "2014", until: "2018", graduated: "2014", missing: "2013", present: "heute"),
        EntryYears(input: "es-plain", since: "2021", from: "2017", until: "2021", graduated: "2017", missing: "2016", present: "Actualidad"),
        EntryYears(input: "fr-plain", since: "2019", from: "2015", until: "2019", graduated: "2015", missing: "2014", present: "Aujourd'hui"),
        EntryYears(input: "pt-plain", since: "2018", from: "2014", until: "2018", graduated: "2014", missing: "2013", present: "Atual"),
    ]
}

/// The word of the present, put in a field of an entry, in a description that says it of one entry, of two, or of none.
struct PresentCase: Sendable, CustomTestStringConvertible {
    let label: String
    let description: String
    /// The field that holds the present: `experience[0].endDate`, `experience[1].endDate` or `education[0].endDate`.
    let path: String
    let present: String
    let kind: InventedFacts.Class
    let reason: String

    var testDescription: String { label }

    var cv: CVData {
        func end(_ target: String) -> String? { path == target ? present : nil }
        return CVData(
            experience: [
                Experience(company: "Alpha Corp", endDate: end("experience[0].endDate")),
                Experience(company: "Beta Ltd", endDate: end("experience[1].endDate")),
            ],
            education: [Education(institution: "Gamma University", endDate: end("education[0].endDate"))]
        )
    }

    private static let split = "I worked at Alpha Corp until 2020. Since 2021 I work at Beta Ltd, up to the present. I studied at Gamma University and graduated in 2015."
    private static let shared = "I worked at Alpha Corp until 2020 and at Beta Ltd up to the present. I studied at Gamma University and graduated in 2015."
    private static let nobody = "I worked at Alpha Corp until 2020. I worked at Beta Ltd from 2021. I am present at every conference. I studied at Gamma University and graduated in 2015."
    private static let italian = "Ho lavorato in Alpha Corp fino al 2020. Dal 2021 lavoro in Beta Ltd, ad oggi. Mi sono laureato alla Gamma University nel 2015."
    private static let german = "Ich arbeitete bei Alpha Corp bis 2020. Seit 2021 arbeite ich bei Beta Ltd, bis heute. Ich studierte an der Gamma University bis 2015."

    static let all: [PresentCase] = [
        PresentCase(label: "the job that ended takes the present of the other job", description: split, path: "experience[0].endDate", present: "Present", kind: .invented, reason: "another entry"),
        PresentCase(label: "the job whose sentence says it", description: split, path: "experience[1].endDate", present: "Present", kind: .quote, reason: "sentence of the entry"),
        PresentCase(label: "the school takes the present of a job", description: split, path: "education[0].endDate", present: "Present", kind: .invented, reason: "another entry"),
        PresentCase(label: "a present said of two jobs in one sentence, the first job", description: shared, path: "experience[0].endDate", present: "Present", kind: .review, reason: "several entries"),
        PresentCase(label: "a present said of two jobs in one sentence, the second job", description: shared, path: "experience[1].endDate", present: "Present", kind: .review, reason: "several entries"),
        PresentCase(label: "a present in a sentence of no employer or school", description: nobody, path: "experience[0].endDate", present: "Present", kind: .review, reason: "names no employer or school"),
        PresentCase(label: "Italian: the job that ended", description: italian, path: "experience[0].endDate", present: "Ad oggi", kind: .invented, reason: "another entry"),
        PresentCase(label: "Italian: the job whose sentence says it", description: italian, path: "experience[1].endDate", present: "Ad oggi", kind: .quote, reason: "sentence of the entry"),
        PresentCase(label: "German: the job that ended", description: german, path: "experience[0].endDate", present: "Bis heute", kind: .invented, reason: "another entry"),
        PresentCase(label: "German: the job whose sentence says it", description: german, path: "experience[1].endDate", present: "Bis heute", kind: .quote, reason: "sentence of the entry"),
    ]
}
