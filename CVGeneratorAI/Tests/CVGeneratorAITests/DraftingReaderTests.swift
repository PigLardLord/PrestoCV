import Testing
@testable import CVGeneratorAI

// The reader's classes of #354, round 3: each class the reader named in the drafts of 5bcc19bf that a rough rule can count. The
// rules are the test's own word lists, not the draft's rules; every name and value is invented.

@Suite("Drafting evaluation: the reader's classes of round 3")
struct DraftingReaderTests {
    // MARK: Summary

    @Test("A summary sentence whose subject is a work word after an article, with any verb, is counted; the person's own work is not")
    func bareSubjectAfterAnArticle() throws {
        let italian = try #require(DraftingInputs.jobs.first { $0.id == "jobs-it" })
        let portuguese = try #require(DraftingInputs.written.first { $0.id == "pt-traps" })
        let italianCV = CVData(summary: "Lavoro come capoturno della manutenzione. La manutenzione è la mia attività principale. "
            + "Il lavoro di squadra lo pratico ogni giorno. Il mio lavoro è vario.")
        let portugueseCV = CVData(summary: "Trabalho como programador em Porto Alegre. O trabalho exige adaptação constante.")

        let counted = { (cv: CVData, input: DraftingInput) in
            ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .bareSubjectSummary }.map(\.value)
        }

        #expect(counted(italianCV, italian) == [
            "La manutenzione è la mia attività principale.", "Il lavoro di squadra lo pratico ogni giorno.",
        ])
        #expect(counted(portugueseCV, portuguese) == ["O trabalho exige adaptação constante."])
    }

    @Test("A summary sentence with no verb that starts with a bare word of the title is a fragment; one as the person is not")
    func fragmentSummary() throws {
        let spanish = try #require(DraftingInputs.written.first { $0.id == "es-traps" })
        let cv = CVData(summary: "Contable con gran capacidad de análisis y precisión. Soy contable con años de oficio en una gestoría.")

        let found = ReaderRules.findings(in: cv, for: spanish, report: InventedFacts.count(cv, for: spanish))

        #expect(found.filter { $0.kind == .fragmentSummary }.map(\.value) == ["Contable con gran capacidad de análisis y precisión."])
    }

    @Test("A summary sentence that lists three of the draft's own skills is counted; one that names two inside the work is not")
    func listySummary() {
        let cv = CVData(
            summary: "Trabalho como programador com terminal, scanner, codec e sensor. Desenvolvo aplicativos com Git e Figma para lojas.",
            skills: ["terminal", "scanner", "codec", "sensor", "Git", "Figma"].map { Skill(name: $0) }
        )

        #expect(Self.reader(cv, "pt").filter { $0.kind == .listySummary }.map(\.value) == [
            "Trabalho como programador com terminal, scanner, codec e sensor.",
        ])
    }

    @Test("In English, \"I\" opens no subject and a work word with its verb is no fragment; a title joined by \"with\" is one")
    func englishSubjectsAndFragments() {
        let job = Experience(title: "boat mechanic", company: "Gullwing Marina", description: "I service the outboard engines.")
        let cv = CVData(
            summary: "I work as a boat mechanic. Mechanic work asks for care and precision. Mechanic with a steady hand and an eye for detail.",
            experience: [job]
        )

        let found = Self.reader(cv, "en").filter { [.bareSubjectSummary, .fragmentSummary].contains($0.kind) }

        #expect(found.map(\.kind) == [.fragmentSummary])
        #expect(found.map(\.value) == ["Mechanic with a steady hand and an eye for detail."])
    }

    @Test("A summary sentence of three clauses joined by semicolons is counted; one with a single semicolon is not")
    func chainedSummary() {
        let cv = CVData(summary: "I work as a lock keeper. I grease the gates; I log the boats; I clear the weirs of driftwood. "
            + "I check the sluices each morning; the barges pass at noon.")

        #expect(Self.reader(cv, "en").filter { $0.kind == .chainedSummary }.map(\.value) == [
            "I grease the gates; I log the boats; I clear the weirs of driftwood.",
        ])
    }

    // MARK: Skills

    @Test("A soft skill that is an empty word of experience or of being a professional is counted; a quality and the word for a skill are not")
    func emptySoftSkill() {
        let cv = CVData(skills: ["professional", "experience", "patience", "knowledge"].map { Skill(name: $0, kind: .softSkill) })
        let german = CVData(skills: ["Erfahrung", "Geduld", "Wissen"].map { Skill(name: $0, kind: .softSkill) })

        #expect(Self.reader(cv, "en").filter { $0.kind == .emptySoftSkill }.map(\.value) == ["professional", "experience"])
        #expect(Self.reader(german, "de").filter { $0.kind == .emptySoftSkill }.map(\.value) == ["Erfahrung"])
    }

    @Test("A loanword a language writes as its own is no skill in another language there, and is one in a language that does not")
    func loanwordByLanguage() {
        let cv = CVData(skills: [Skill(name: "scanner"), Skill(name: "printer")])

        #expect(Self.reader(cv, "pt").filter { $0.kind == .skillInAnotherLanguage }.map(\.value) == ["printer"])
        #expect(Self.reader(cv, "es").filter { $0.kind == .skillInAnotherLanguage }.map(\.value) == ["scanner", "printer"])
    }

    @Test("The rigs of live sound are tools of the trade; a safety harness in a warehouse and a load balancer are not")
    func tradeVocabularies() throws {
        let sound = try #require(DraftingInputs.jobs.first { $0.id == "jobs-en" })
        let warehouse = try #require(DraftingInputs.written.first { $0.id == "en-plain" })
        let counted = { (names: [String], input: DraftingInput) in
            let cv = CVData(skills: names.map { Skill(name: $0) })
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .offTradeTechnology }.map(\.value)
        }

        #expect(counted(["follow spot rig", "lighting rig", "audio distribution box"], sound).isEmpty)
        #expect(counted(["SAP", "pallet jack", "safety harness", "load balancer"], warehouse) == ["safety harness", "load balancer"])
    }

    @Test("A part the electrician installs is no tool of the trade; a measuring tool is one")
    func partsAreNoTools() throws {
        let electrician = try #require(DraftingInputs.written.first { $0.id == "de-plain" })
        let cv = CVData(skills: ["Schalter", "Leitungen", "Multimeter", "KNX"].map { Skill(name: $0) })

        let found = ReaderRules.findings(in: cv, for: electrician, report: InventedFacts.count(cv, for: electrician))

        #expect(found.filter { $0.kind == .noToolOfTheTrade }.map(\.value) == ["Schalter", "Leitungen"])
    }

    // MARK: Duties

    #if canImport(NaturalLanguage)
    // The duty check reads the description's clauses with the device's language data, which only an Apple platform has.
    @Test("A job under 40 characters whose step pins a duty it does not hold is counted; one of 40 characters is not")
    func stepVsFinalPinned() throws {
        let sound = try #require(DraftingInputs.jobs.first { $0.id == "jobs-en" })
        let cv = CVData(experience: [
            Experience(
                title: "head of sound", company: "Orchard Lane Theatre", startDate: "2021", current: true,
                description: "I plan the sound design."
            ),
            Experience(
                title: "stagehand", company: "Fenwick Playhouse", startDate: "2013", endDate: "2016",
                description: "I rigged the lights and loaded the trucks."
            ),
        ])

        let found = ReaderRules.findings(in: cv, for: sound, report: InventedFacts.count(cv, for: sound))

        #expect(found.filter { $0.kind == .stepVsFinalPinned }.map(\.path) == ["experience[0].description"])
    }
    #endif

    // MARK: -

    /// The reader's findings in `cv` for an input of `language` with no field, whose description states nothing.
    private static func reader(_ cv: CVData, _ language: String) -> [ReaderFinding] {
        let input = DraftingInput(id: "reader-\(language)", kind: .plain, language: language, description: "", facts: [], traps: [])
        return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
    }
}
