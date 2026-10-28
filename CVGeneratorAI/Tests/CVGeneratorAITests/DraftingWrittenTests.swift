import Testing
import Foundation
import CVGeneratorAI

// What a draft writes around the facts (ADR 0031) is measured against the thresholds of #354: a summary, a description of each kept
// job, enough technologies and soft skills, every sentence in the description's language, no tool of another trade.

@Suite("Drafting evaluation: what the draft writes around the facts")
struct DraftingWrittenTests {
    // MARK: - One draft

    @Test("A summary counts with 2 to 4 sentences and 120 characters or more", arguments: SummaryCase.all)
    func summary(_ item: SummaryCase) throws {
        let measure = try Self.measure("en-plain", CVData(summary: item.summary))

        #expect(measure.hasSummary == item.counts, "\(item): \(measure.summarySentences) sentences, \(measure.summaryCharacters)")
    }

    @Test("A kept job counts as described with a sentence of 40 characters or more")
    func describedJobs() throws {
        let job = try #require(WrittenLayer.texts["en"]?.job)
        let cv = CVData(experience: [
            Experience(company: "A", description: "Cook."), Experience(company: "B", description: job), Experience(company: "C"),
        ])

        let measure = try Self.measure("en-plain", cv)

        #expect(measure.keptJobs == 3)
        #expect(measure.describedJobs == 1)
    }

    @Test("The skills count by kind, and a sparse description needs fewer")
    func skills() throws {
        let cv = CVData(skills: [
            Skill(name: "Pipe fitting"), Skill(name: "Drain cleaning"), Skill(name: "Leak detection"),
            Skill(name: "Punctuality", kind: .softSkill), Skill(name: "Patience", kind: .softSkill),
        ])

        let measure = try Self.measure("en-sparse", cv)

        #expect(measure.technologies == 3)
        #expect(measure.softSkills == 2)
        #expect(measure.hasSkills(sparse: true))
        #expect(!measure.hasSkills(sparse: false))
    }

    @Test("A written sentence in another language than the description's is listed with its path")
    func otherLanguage() throws {
        let english = try #require(WrittenLayer.texts["en"]?.summary)
        let italian = try #require(WrittenLayer.texts["it"]?.summary)

        let wrong = try Self.measure("it-plain", CVData(summary: english))
        let right = try Self.measure("it-plain", CVData(summary: italian))

        #expect(wrong.sentences == 2)
        #expect(wrong.otherLanguage.count == 2)
        #expect(wrong.otherLanguage.first?.hasPrefix("summary (en): Reliable and careful") == true)
        #expect(right.otherLanguage.isEmpty)
    }

    @Test("A tool of another trade is an off-field hit as a whole word, and the trade's own tools are not")
    func offField() throws {
        let cv = CVData(skills: [Skill(name: "Java"), Skill(name: "JavaScript"), Skill(name: "SAP")])

        let measure = try Self.measure("en-plain", cv)

        #expect(measure.offField == ["skills[0].name \"Java\" (a tool of another trade: Java)"])
    }

    @Test("Whatever a draft writes around a description with no role is an off-field hit")
    func noRole() throws {
        let summary = try #require(WrittenLayer.texts["en"]?.summary)

        let measure = try Self.measure("en-norole", CVData(summary: summary, skills: [Skill(name: "Teamwork", kind: .softSkill)]))

        #expect(measure.offField.count == 2)
        #expect(measure.offField.allSatisfy { $0.hasSuffix("(written around a description with no role)") })
    }

    // MARK: - The reader's classes

    @Test("A quality listed as a technology is a soft skill as a technology, and a quality listed as a soft skill is not")
    func softAsTechnology() throws {
        let cv = CVData(skills: [
            Skill(name: "Teamwork"), Skill(name: "Mixing consoles"), Skill(name: "Communication skills", kind: .softSkill),
        ])

        let measure = try Self.measure("en-plain", cv)

        #expect(measure.readerFindings == [ReaderFinding(kind: .softAsTechnology, path: "skills[0].name", value: "Teamwork")])
    }

    @Test("A technology that is a word for anything, or a lone word for an activity, is no tool of the trade; an acronym and a machine are")
    func noToolOfTheTrade() throws {
        let cv = CVData(skills: [
            Skill(name: "Manutenzione"), Skill(name: "documenti"), Skill(name: "PLC"), Skill(name: "Saldatrice a filo"),
        ])

        let measure = try Self.measure("it-plain", cv)

        #expect(measure.readerFindings.map(\.kind) == [.noToolOfTheTrade, .noToolOfTheTrade])
        #expect(measure.readerFindings.map(\.value) == ["Manutenzione", "documenti"])
    }

    @Test("A job whose duties start in two forms is counted once, and a word that joins the duties is not their form")
    func twoForms() throws {
        let cv = CVData(experience: [
            Experience(company: "A", description: "I mix the evening shows. Rigging the speakers before the doors open."),
            Experience(company: "B", description: "I mix the evening shows. Then I rig the speakers before the doors open."),
            Experience(company: "C", description: "Mixing the evening shows. Rigging the speakers before the doors open."),
        ])

        let measure = try Self.measure("en-plain", cv)

        #expect(measure.readerFindings.map(\.kind) == [.twoForms])
        #expect(measure.readerFindings.map(\.path) == ["experience[0].description"])
    }

    @Test("A skill of English words in a draft of another language is counted, and in an English draft it is not")
    func skillInAnotherLanguage() throws {
        let cv = CVData(skills: [
            Skill(name: "Preventive maintenance"), Skill(name: "Problem solving", kind: .softSkill),
            Skill(name: "Manutenzione preventiva"), Skill(name: "PLC"),
        ])

        let italian = try Self.measure("it-plain", cv)
        let english = try Self.measure("en-plain", cv)

        #expect(italian.readerFindings.filter { $0.kind == .skillInAnotherLanguage }.map(\.value) == [
            "Preventive maintenance", "Problem solving",
        ])
        #expect(!english.readerFindings.contains { $0.kind == .skillInAnotherLanguage })
    }

    @Test("A run set counts the reader's classes over its distinct drafts, with no threshold")
    func readerCounts() throws {
        let teamwork = Tweak(edit: { $0.skills.append(Skill(name: "Teamwork")) })
        let measured = try DraftMeasures.set(["en-plain", "it-plain"], runs: 2, tweak: DraftMeasures.tweak(teamwork, for: "en-plain"))

        let counts = WrittenCounts(measured)

        #expect(counts.reader == ReaderCounts(softAsTechnology: 1, noToolOfTheTrade: 0, twoForms: 0, skillInAnotherLanguage: 0))
        #expect(counts.shortfalls(p95Seconds: 10).isEmpty)
    }

    // MARK: - The fixture

    @Test("The fixture's written layer is inferred or quoted, never invented or sent to review, in every input with a role")
    func fixtureLayer() throws {
        for input in try DraftingInputs.all() where input.kind != .noRole {
            let report = try DraftMeasures.measure(input.id).report
            let text = try #require(WrittenLayer.texts[input.language], "\(input.id): no written layer for \(input.language)")
            let written = Set([text.summary, text.job] + text.technologies + text.softSkills)

            let wrong = report.findings.filter {
                $0.kind == .invented || (written.contains($0.value) && $0.kind != .inferred && $0.kind != .quote)
            }

            #expect(wrong.isEmpty, "\(input.id): \(wrong.map { "\($0.path) \($0.kind): \($0.reason)" })")
        }
    }

    // MARK: - A run set

    @Test("The counts take an input's identical drafts once and leave out a description with no role")
    func distinctDrafts() throws {
        let measured = try DraftMeasures.set(["en-plain", "it-plain", "en-norole"], runs: 3)

        let counts = WrittenCounts(measured)

        #expect(counts.drafts == 2)
        #expect(counts.withSummary == 2)
        #expect(counts.withSkills == 2)
        #expect(counts.keptJobs > 0)
        #expect(counts.describedJobs == counts.keptJobs)
        #expect(counts.sentences == 4 + counts.keptJobs)
        #expect(counts.otherLanguage == 0)
        #expect(counts.shortfalls(p95Seconds: 10).isEmpty)
    }

    @Test("Nine drafts in ten with a summary is enough, eight is a shortfall", arguments: [(1, false), (2, true)])
    func ninetyPercent(_ missing: Int, _ short: Bool) throws {
        let ids = try DraftingInputs.all().filter { $0.kind == .plain || $0.kind == .traps }.prefix(10).map(\.id)
        let measured = try DraftMeasures.set(ids) { id, _ in
            ids.prefix(missing).contains(id) ? Tweak(edit: { $0.summary = nil }) : Tweak()
        }

        let shortfalls = WrittenCounts(measured).shortfalls(p95Seconds: 10)

        #expect(ids.count == 10)
        #expect(shortfalls == (short ? ["a summary in 8 of 10 distinct drafts (90% needed)"] : []))
    }

    @Test("Every draft of an example needs a summary")
    func exampleSummary() throws {
        let ids = try ["example-en"] + DraftingInputs.all().filter { $0.kind == .plain || $0.kind == .traps }.map(\.id)
        let measured = try DraftMeasures.set(ids, tweak: DraftMeasures.tweak(Tweak(edit: { $0.summary = nil }), for: "example-en"))

        let shortfalls = WrittenCounts(measured).shortfalls(p95Seconds: 10)

        #expect(shortfalls == ["a summary in 0 of 1 distinct drafts of the examples (all needed)"])
    }

    @Test("A sparse description needs 3 technologies and 2 soft skills, the others 4 and 3")
    func sparseSkills() throws {
        let fewer = Tweak(edit: { draft in
            draft.skills = Array(draft.skills.filter { $0.kind == .technology }.prefix(3))
                + Array(draft.skills.filter { $0.kind == .softSkill }.prefix(2))
        })

        let counts = WrittenCounts(try DraftMeasures.set(["en-sparse", "en-plain"]) { _, _ in fewer })

        #expect(counts.drafts == 2)
        #expect(counts.withSkills == 1)
    }

    @Test("A written sentence in another language is a shortfall")
    func otherLanguageShortfall() throws {
        let english = Tweak(edit: { $0.summary = WrittenLayer.texts["en"]?.summary })
        let counts = WrittenCounts(try DraftMeasures.set(["it-plain"], tweak: DraftMeasures.tweak(english, for: "it-plain")))

        #expect(counts.shortfalls(p95Seconds: 10) == ["2 of \(counts.sentences) written sentences in another language (none allowed)"])
    }

    @Test("More than 90 seconds a draft at the 95th percentile is a shortfall", arguments: [(90.0, false), (90.5, true)])
    func time(_ seconds: Double, _ short: Bool) throws {
        let counts = WrittenCounts(try DraftMeasures.set(["en-plain"]))

        #expect(counts.shortfalls(p95Seconds: seconds) == (short ? ["p95 90.5 s per draft (at most 90 s)"] : []))
    }

    // MARK: - Helpers

    private static func measure(_ id: String, _ cv: CVData) throws -> WrittenMeasure {
        let input = try InventedFactsTests.input(id)
        return WrittenMeasure(cv, for: input, report: InventedFacts.count(cv, for: input))
    }
}

// MARK: - Cases

struct SummaryCase: Sendable, CustomTestStringConvertible {
    let label: String
    let summary: String
    let counts: Bool

    var testDescription: String { label }

    static let all: [SummaryCase] = [
        SummaryCase(label: "two sentences of 120 characters or more", summary: WrittenLayer.texts["en"]?.summary ?? "", counts: true),
        SummaryCase(
            label: "one long sentence",
            summary: "Reliable and careful worker who plans each task and keeps the place safe, tidy and well organised, friendly with "
                + "colleagues and calm when the day gets busy.",
            counts: false
        ),
        SummaryCase(label: "two short sentences", summary: "Reliable and careful worker. Friendly with colleagues.", counts: false),
        SummaryCase(
            label: "five sentences",
            summary: "Reliable and careful at work. Plans each task well. Keeps the place safe. Keeps the place tidy. "
                + "Friendly with colleagues.",
            counts: false
        ),
    ]
}
