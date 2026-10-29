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

    @Test("A kept job counts as described with 40 characters or more in all, in short sentences too")
    func describedJobs() throws {
        let job = try #require(WrittenLayer.texts["en"]?.job)
        let cv = CVData(experience: [
            Experience(company: "A", description: "Cook."), Experience(company: "B", description: job), Experience(company: "C"),
            Experience(company: "D", description: "I glaze the tiles. I fire them in the kiln."),
        ])

        let measure = try Self.measure("en-plain", cv)

        #expect(measure.keptJobs == 4)
        #expect(measure.describedJobs == 2)
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

    @Test("A tool of a design trade is an off-field hit in another trade's draft, and not in the designer's")
    func designTools() throws {
        let cv = CVData(skills: [Skill(name: "After Effects"), Skill(name: "Illustrator")])

        let programmer = try Self.measure("pt-traps", cv)
        let designer = try Self.measure("es-plain", cv)

        #expect(programmer.offField.count == 2)
        #expect(designer.offField.isEmpty)
    }

    @Test("A skill that starts with the stem of a one-word trap echoes it, and is an off-field hit")
    func trapEcho() throws {
        let cv = CVData(skills: [Skill(name: "Técnicas de auditoría"), Skill(name: "Hojas de cálculo")])

        let measure = try Self.measure("es-traps", cv)

        #expect(measure.offField == [
            "skills[0].name \"Técnicas de auditoría\" (an echo of a word the person does not state of themselves: auditor)",
        ])
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

        #expect(measure.readerFindings.filter { $0.path.hasPrefix("skills") } == [
            ReaderFinding(kind: .softAsTechnology, path: "skills[0].name", value: "Teamwork"),
        ])
    }

    @Test("A technology that is a word for anything, or a lone word for an activity, is no tool of the trade; an acronym and a machine are")
    func noToolOfTheTrade() throws {
        let cv = CVData(skills: [
            Skill(name: "Manutenzione"), Skill(name: "documenti"), Skill(name: "PLC"), Skill(name: "Saldatrice a filo"),
        ])

        let measure = try Self.measure("it-plain", cv)

        let skills = measure.readerFindings.filter { $0.path.hasPrefix("skills") }
        #expect(skills.map(\.kind) == [.noToolOfTheTrade, .noToolOfTheTrade])
        #expect(skills.map(\.value) == ["Manutenzione", "documenti"])
    }

    @Test("A job whose duties start in two forms is counted once, and a word that joins the duties is not their form")
    func twoForms() throws {
        let cv = CVData(experience: [
            Experience(company: "A", description: "I mix the evening shows. Rigging the speakers before the doors open."),
            Experience(company: "B", description: "I mix the evening shows. Then I rig the speakers before the doors open."),
            Experience(company: "C", description: "Mixing the evening shows. Rigging the speakers before the doors open."),
        ])

        let measure = try Self.measure("en-plain", cv)

        #expect(measure.readerFindings.filter { $0.kind == .twoForms }.map(\.path) == ["experience[0].description"])
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

    @Test("A loanword the other languages write as their own is no skill in another language")
    func loanword() throws {
        let cv = CVData(skills: [Skill(name: "Leadership", kind: .softSkill), Skill(name: "Team leader", kind: .softSkill)])

        let measure = try Self.measure("it-plain", cv)

        #expect(!measure.readerFindings.contains { $0.kind == .skillInAnotherLanguage })
    }

    @Test("A technology whose head noun an earlier one has is counted: the last word in English, the first in French")
    func sharedHeadNoun() {
        let english = CVData(skills: [Skill(name: "Mixing desks"), Skill(name: "Stage boxes"), Skill(name: "Digital desk")])
        let french = CVData(skills: [Skill(name: "carnets"), Skill(name: "carnet de notes"), Skill(name: "rétroprojecteur")])
        let short = CVData(skills: [Skill(name: "Logic Pro"), Skill(name: "Premiere Pro")])

        #expect(Self.reader(english, "en").map(\.value) == ["Digital desk"])
        #expect(Self.reader(french, "fr").map(\.value) == ["carnet de notes"])
        #expect(Self.reader(short, "en").isEmpty)
    }

    @Test("A headline that is a part of a stated title is counted, and a form of the title is not")
    func headlineFragment() {
        let title = ExpectedFact.title("addetta contabile", "addetta")
        let fragment = Self.reader(CVData(personalInfo: PersonalInfo(title: "contabile")), "it", facts: [title])
        let form = Self.reader(CVData(personalInfo: PersonalInfo(title: "addetta")), "it", facts: [title])
        let whole = Self.reader(CVData(personalInfo: PersonalInfo(title: "addetta contabile")), "it", facts: [title])

        #expect(fragment.map(\.kind) == [.headlineFragment])
        #expect(form.isEmpty)
        #expect(whole.isEmpty)
    }

    @Test("A summary that names no kept title whole is counted, even with a word of one")
    func summaryWithoutPerson() {
        let job = Experience(title: "boat mechanic", company: "Gullwing Marina", description: "I service the outboard engines.")
        let about = CVData(
            summary: "Engines are the heart of every trip. Mechanic work asks for care and precision.", experience: [job]
        )
        let person = CVData(summary: "I work as a boat mechanic. I keep the engines of the fleet running.", experience: [job])

        #expect(Self.reader(about, "en").map(\.kind) == [.summaryWithoutPerson])
        #expect(Self.reader(person, "en").isEmpty)
    }

    @Test("With no title kept, a summary that names a stated title names the person, and one that does not is counted")
    func summaryOfAnUntitledDraft() {
        let title = ExpectedFact.title("tide gauge keeper", "keeper")
        let job = Experience(company: "Harbour Board", description: "I read the tide gauges.")
        let person = CVData(summary: "I work as a tide gauge keeper. I read the gauges twice a day.", experience: [job])
        let about = CVData(summary: "Tides shape the life of every harbour. The gauges need care.", experience: [job])

        #expect(Self.reader(person, "en", facts: [title]).isEmpty)
        #expect(Self.reader(about, "en", facts: [title]).map(\.kind) == [.summaryWithoutPerson])
    }

    @Test("A duty that starts with an infinitive or a gerund is counted once a job, and a first person is not")
    func infinitiveDuty() {
        let cv = CVData(experience: [
            Experience(company: "A", description: "Preparare le buste paga. Archiviare le pratiche."),
            Experience(company: "B", current: true, description: "Preparo le buste paga. Archivio le pratiche."),
        ])

        #expect(Self.reader(cv, "it").map(\.path) == ["experience[0].description"])
    }

    @Test("A description with no full stop at the end is counted")
    func unfinishedDescription() {
        let cv = CVData(experience: [
            Experience(company: "A", description: "tuning the pianos before each recital"),
            Experience(company: "B", description: "I tuned the pianos before each recital."),
        ])

        #expect(Self.reader(cv, "en").map(\.kind) == [.infinitiveDuty, .unfinishedDescription])
    }

    @Test("An ended job in the past and the present is counted, and a current one is not")
    func mixedTense() {
        let text = "Montei os armários das cozinhas. Instalo as portas de correr."
        let cv = CVData(experience: [
            Experience(company: "A", endDate: "2019", description: text),
            Experience(company: "B", current: true, description: text),
        ])

        #expect(Self.reader(cv, "pt").map(\.path) == ["experience[0].description"])
    }

    @Test("The word for a skill listed as a soft skill is counted, and a quality is not")
    func skillWordAsQuality() {
        let cv = CVData(skills: [Skill(name: "Compétences", kind: .softSkill), Skill(name: "Patience", kind: .softSkill)])

        #expect(Self.reader(cv, "fr").map(\.value) == ["Compétences"])
    }

    @Test("An interest that is a clause or a quality at work is counted, and a pastime of a verb is not")
    func clauseAsInterest() {
        let cv = CVData(interests: ["play the piano", "stay calm in a crisis", "I enjoy chess", "grow tomatoes in the garden plot"])

        #expect(Self.reader(cv, "en").map(\.value) == ["stay calm in a crisis", "I enjoy chess", "grow tomatoes in the garden plot"])
    }

    @Test("A summary sentence with the verb of an earlier one, or a duty's sentence, is counted")
    func repeatedSentence() {
        let job = Experience(title: "fleuriste", company: "Les Iris", current: true, description: "Je compose des bouquets de saison.")
        let cv = CVData(
            summary: "Je travaille comme fleuriste. Je travaille avec des fleurs fraîches. Je compose des bouquets de saison.",
            experience: [job]
        )

        #expect(Self.reader(cv, "fr").map(\.value) == [
            "Je travaille avec des fleurs fraîches.", "Je compose des bouquets de saison.",
        ])
    }

    @Test("A job that writes a run of five words twice is counted once, and words of one duty said once are not")
    func repeatedDuty() {
        let cv = CVData(experience: [
            Experience(company: "A", description: "Sistemavo gli scaffali, dando una mano con le consegne ai clienti. "
                + "Davo anche una mano con le consegne ai clienti."),
            Experience(company: "B", description: "Sistemavo gli scaffali. Davo anche una mano con le consegne ai clienti."),
            Experience(company: "C", description: "Davo una mano con le consegne. Davo una mano con gli ordini."),
        ])

        #expect(Self.reader(cv, "it").filter { $0.kind == .repeatedDuty } == [
            ReaderFinding(kind: .repeatedDuty, path: "experience[0].description", value: "una mano con le consegne"),
        ])
    }

    @Test("A skill of more than four words is a clause, of either kind, and a name of four words is not")
    func clauseAsSkill() {
        let cv = CVData(skills: [
            Skill(name: "edit the voice tracks for the podcasts"), Skill(name: "Adobe Audition sound editor"),
            Skill(name: "stay calm when the show runs late", kind: .softSkill),
        ])

        #expect(Self.reader(cv, "en").filter { $0.kind == .clauseAsSkill }.map(\.path) == ["skills[0].name", "skills[2].name"])
    }

    @Test("A summary sentence with a verb of the third person after the title is counted; one as the person is not")
    func thirdPersonSummary() {
        let input = DraftingInput(
            id: "reader-es", kind: .plain, language: "es",
            description: "Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad.", facts: [], traps: []
        )
        let cv = CVData(
            summary: "Contable gestiona los registros con cuidado. Llevo la contabilidad de una fábrica de muebles. "
                + "Para la empresa preparo los informes mensuales. Se encarga de las facturas.",
            experience: [Experience(title: "contable", company: "Muebles Albarracín", startDate: "2017", current: true)]
        )

        let found = ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))

        #expect(found.filter { $0.kind == .thirdPersonSummary }.map(\.value) == [
            "Contable gestiona los registros con cuidado.", "Se encarga de las facturas.",
        ])
    }

    @Test("A soft skill whose head noun is a tool is counted; one that only starts with a tool word is not")
    func toolAsSoftSkill() {
        let cv = CVData(skills: [
            Skill(name: "Präzisionswerkzeug", kind: .softSkill), Skill(name: "Sorgfalt", kind: .softSkill),
            Skill(name: "Messgerät", kind: .softSkill), Skill(name: "Werkzeugpflege", kind: .softSkill),
            Skill(name: "Drehmaschine"),
        ])

        #expect(Self.reader(cv, "de").filter { $0.kind == .toolAsSoftSkill }.map(\.path) == ["skills[0].name", "skills[2].name"])
    }

    @Test("An interest that starts with the finite verb of its clause is a clause, also with a capital; a pastime with an adjective or an infinitive is not",
          arguments: ["spiele Schach", "Spiele Schach"])
    func verbAsInterest(clause: String) {
        let input = DraftingInput(
            id: "reader-de", kind: .plain, language: "de",
            description: "Ich arbeite als Feinmechaniker in Suhl. In meiner Freizeit gehe ich klettern, höre klassische Musik und spiele Schach.",
            facts: [], traps: []
        )
        let cv = CVData(interests: ["klettern", "klassische Musik", clause])

        let found = ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))

        #expect(found.filter { $0.kind == .clauseAsInterest }.map(\.value) == [clause])
    }

    @Test("An interest of one noun said after a verb in the form of its infinitive is counted; the whole phrase, and a noun said after a conjugated verb, are not (#354, round 1)")
    func bareInterest() {
        let input = DraftingInput(
            id: "reader-en", kind: .plain, language: "en",
            description: "I have been a waiter in Exeter since 2019. I play football, I bake bread and my brother plays chess.",
            facts: [], traps: []
        )
        let cv = CVData(interests: ["football", "bake bread", "chess"])

        let found = ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))

        #expect(found.filter { $0.kind == .bareInterest }.map(\.value) == ["football"])
        #expect(found.filter { $0.kind == .clauseAsInterest }.isEmpty)
    }

    @Test("A duty or a quality the person states and no job description or skill holds is counted; one a skill or a description holds is not (#354, round 1)")
    func unwrittenStatement() throws {
        let english = try #require(DraftingInputs.jobs.first { $0.id == "jobs-en" })
        let italian = try #require(DraftingInputs.jobs.first { $0.id == "jobs-it" })
        let unwritten = { (cv: CVData, input: DraftingInput) in
            ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .unwrittenStatement }.map(\.value)
        }
        let missing = CVData(
            experience: [Experience(title: "head of sound", company: "Orchard Lane Theatre", description: "I plan the sound design.")],
            skills: [Skill(name: "digital consoles"), Skill(name: "calm under pressure", kind: .softSkill)]
        )
        let held = CVData(
            experience: [Experience(title: "head of sound", company: "Orchard Lane Theatre", description: "I plan the sound design.")],
            skills: [
                Skill(name: "digital consoles"), Skill(name: "sound effects editing"), Skill(name: "stress resistance under pressure", kind: .softSkill),
                Skill(name: "collaboration with directors", kind: .softSkill),
            ]
        )
        let described = CVData(
            experience: [Experience(
                title: "capoturno della manutenzione", company: "Birrificio Valtrigno",
                description: "Leggo gli schemi elettrici e uso i PLC per trovare i guasti."
            )],
            skills: [Skill(name: "PLC"), Skill(name: "lavoro di squadra", kind: .softSkill)]
        )

        #expect(unwritten(missing, english) == ["sound effects", "working closely with directors"])
        #expect(unwritten(held, english).isEmpty)
        #expect(unwritten(described, italian).isEmpty)
        #expect(unwritten(CVData(skills: [Skill(name: "PLC")]), italian) == ["schemi elettrici", "trovare i guasti", "lavorare in squadra"])
    }

    @Test("A year the description gives a school and the draft does not hold is counted")
    func lostYear() throws {
        let kept = CVData(education: [Education(degree: "logistics", institution: "Leeds City College", endDate: "2013")])
        let lost = CVData(education: [Education(degree: "logistics", institution: "Leeds City College", startDate: "2014")])

        let lostYear = { (measure: WrittenMeasure) in measure.readerFindings.filter { $0.kind == .lostYear && $0.value == "2013" } }

        #expect(lostYear(try Self.measure("en-plain", kept)).isEmpty)
        #expect(lostYear(try Self.measure("en-plain", lost)).count == 1)
    }

    @Test("A run set counts the reader's classes over its distinct drafts, with no threshold")
    func readerCounts() throws {
        let teamwork = Tweak(edit: { $0.skills.append(Skill(name: "Teamwork")) })
        let measured = try DraftMeasures.set(["en-plain", "it-plain"], runs: 2, tweak: DraftMeasures.tweak(teamwork, for: "en-plain"))

        let plain = WrittenCounts(try DraftMeasures.set(["en-plain", "it-plain"], runs: 2)).reader

        let counts = WrittenCounts(measured)

        for kind in ReaderClass.allCases {
            #expect(counts.reader.count(kind) == plain.count(kind) + (kind == .softAsTechnology ? 1 : 0), "\(kind)")
        }
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

    /// The reader's findings in `cv` for an input of `language` with no field, whose description states `facts` alone.
    private static func reader(_ cv: CVData, _ language: String, facts: [ExpectedFact] = []) -> [ReaderFinding] {
        let input = DraftingInput(
            id: "reader-\(language)", kind: .plain, language: language, description: "", facts: facts, traps: []
        )
        return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
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
