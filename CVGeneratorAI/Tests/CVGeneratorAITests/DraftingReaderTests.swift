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

    @Test("A summary sentence past the opening with no word of the description, the titles, the duties or the skills is counted; one with a word of the work is not (#354, round 4)")
    func unanchoredSummary() {
        let cv = CVData(
            personalInfo: PersonalInfo(title: "lock keeper"),
            summary: "I work as a lock keeper. I grease every gate before the barges arrive. "
                + "I guarantee every action follows the established pattern with deliberate intention.",
            experience: [Experience(title: "lock keeper", company: "Brindle Canal", description: "I grease the gates of the lock.")]
        )

        #expect(Self.reader(cv, "en").filter { $0.kind == .unanchoredSummary }.map(\.value) == [
            "I guarantee every action follows the established pattern with deliberate intention.",
        ])
    }

    @Test("A German separable verb split at the end of a subordinate clause is counted; one split in a main clause, or joined, is not (#354, round 4)")
    func splitSeparableVerb() {
        let cv = CVData(
            summary: "Ich arbeite als Schleusenwärter. Ich achte darauf, dass ich die Funktion der Tore sicher stelle. "
                + "Ich öle die Tore, bevor die Kähne ein fahren.",
            experience: [Experience(
                title: "Schleusenwärter", company: "Kanal Brindle",
                description: "Ich stelle die Funktion der Tore sicher. Ich prüfe, ob die Schleuse richtig zumacht."
            )]
        )

        #expect(Self.reader(cv, "de").filter { $0.kind == .splitVerb }.map(\.value) == ["sicher stelle", "ein fahren"])
    }

    @Test("A summary sentence that shares only a word for work of any trade with the work is counted; one that names a duty is not (#354, round 5)")
    func workWordIsNoAnchor() {
        let cv = CVData(
            personalInfo: PersonalInfo(title: "fabbro"),
            summary: "Lavoro come fabbro in officina. Ogni giorno il lavoro richiede costanza e cura. Saldo cancelli con attenzione alla forma.",
            experience: [Experience(title: "fabbro", company: "Officina Merla", description: "Nel mio lavoro saldo cancelli in ferro battuto.")]
        )

        #expect(Self.reader(cv, "it").filter { $0.kind == .unanchoredSummary }.map(\.value) == [
            "Ogni giorno il lavoro richiede costanza e cura.",
        ])
    }

    @Test("An Italian, Spanish or Portuguese summary sentence with no first person is counted; one with a verb or a word of the person is not (#354, round 5)")
    func impersonalSummary() {
        let italian = CVData(summary: "Lavoro come fabbro da molti anni. Ogni cancello richiede pazienza e misura. "
            + "Con calma, saldo le cerniere ai telai. La precisione guida ogni intervento. Mi piace il ferro battuto.")
        let spanish = CVData(summary: "Soy cerrajero en un taller pequeño. Cada cerradura exige un ajuste fino.")
        let portuguese = CVData(summary: "Conserto relógios antigos com cuidado. O ofício exige paciência.")
        let counted = { (cv: CVData, language: String) in
            Self.reader(cv, language).filter { $0.kind == .impersonalSummary }.map(\.value)
        }

        #expect(counted(italian, "it") == ["Ogni cancello richiede pazienza e misura.", "La precisione guida ogni intervento."])
        #expect(counted(spanish, "es") == ["Cada cerradura exige un ajuste fino."])
        #expect(counted(portuguese, "pt") == ["O ofício exige paciência."])
        #expect(counted(CVData(summary: "The work asks for patience."), "en").isEmpty)
    }

    @Test("An Italian, Spanish or Portuguese summary sentence that opens with a participle and has no person is counted; one with a verb of the person, or a first person of the same ending, is not (#354, round 6)")
    func participleSummary() {
        let italian = CVData(summary: "Curato ogni dettaglio delle cornici dorate. Abituato alla polvere, restauro le cornici antiche. "
            + "Valuto lo stato di ogni tela. Restauro le cornici antiche con pazienza.")
        let spanish = CVData(summary: "Mantenido un archivo ordenado de las partituras, lo que facilita los ensayos. "
            + "Mantengo un archivo ordenado de las partituras. Decido el orden de los ensayos.")
        let portuguese = CVData(summary: "Mantido um arquivo organizado das plantas da obra. Mantenho um arquivo organizado das plantas.")
        let counted = { (cv: CVData, language: String) in
            Self.reader(cv, language).filter { $0.kind == .participleSummary }.map(\.value)
        }

        #expect(counted(italian, "it") == ["Curato ogni dettaglio delle cornici dorate."])
        #expect(counted(spanish, "es") == ["Mantenido un archivo ordenado de las partituras, lo que facilita los ensayos."])
        #expect(counted(portuguese, "pt") == ["Mantido um arquivo organizado das plantas da obra."])
        #expect(counted(CVData(summary: "Trained the new staff."), "en").isEmpty)
    }

    @Test("A German subordinate clause that ends with a noun after its verb is counted; one that ends with its verb is not (#354, round 5)")
    func germanVerbPosition() {
        let cv = CVData(summary: "Ich arbeite als Schleusenwärter. Ich prüfe, dass alle Tore schließen sauber nach jeder Fahrt. "
            + "Ich achte darauf, dass die Tore sauber schließen. Ich weiß, ob die Pumpe läuft.")

        #expect(Self.reader(cv, "de").filter { $0.kind == .germanVerbPosition }.map(\.value) == [
            "dass alle Tore schließen sauber nach jeder Fahrt",
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

    @Test("Stationery and a quantity are no tools of a trade; a digital board, learning software, a terminal and a code editor are (#354, round 4)")
    func everydayThingsAreOffTrade() throws {
        let teacher = try #require(try DraftingInputs.examples().first { $0.id == "example-fr" })
        let programmer = try #require(DraftingInputs.written.first { $0.id == "pt-traps" })
        let sound = try #require(DraftingInputs.jobs.first { $0.id == "jobs-en" })
        let counted = { (names: [String], input: DraftingInput) in
            let cv = CVData(skills: names.map { Skill(name: $0) })
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .offTradeTechnology }.map(\.value)
        }

        #expect(counted(["tableau numérique", "logiciel d'apprentissage", "cahiers", "stylo"], teacher) == ["cahiers", "stylo"])
        #expect(counted(["terminal", "editor de código", "codec", "sensor"], programmer) == ["codec", "sensor"])
        #expect(counted(["lighting rig", "truck load"], sound) == ["truck load"])
    }

    @Test("A part the electrician installs is no tool of the trade; a measuring tool is one")
    func partsAreNoTools() throws {
        let electrician = try #require(DraftingInputs.written.first { $0.id == "de-plain" })
        let cv = CVData(skills: ["Schalter", "Leitungen", "Multimeter", "KNX"].map { Skill(name: $0) })

        let found = ReaderRules.findings(in: cv, for: electrician, report: InventedFacts.count(cv, for: electrician))

        #expect(found.filter { $0.kind == .noToolOfTheTrade }.map(\.value) == ["Schalter", "Leitungen"])
    }

    @Test("A role, the noun of an activity or a document as a technology is counted; a tool, a tool with an acronym and a kind of model are not (#354, round 5)")
    func nonToolTechnology() {
        let counted = { (names: [String], language: String) in
            Self.reader(CVData(skills: names.map { Skill(name: $0) }), language).filter { $0.kind == .nonToolTechnology }.map(\.value)
        }

        #expect(counted(["Registros", "programación de turnos", "hoja de cálculo", "análisis FMEA"], "es")
            == ["Registros", "programación de turnos"])
        #expect(counted(["operador", "faturas", "gerador de relatórios", "modelo de simulação"], "pt") == ["operador", "faturas"])
        #expect(counted(["contratti", "registratore di cassa"], "it") == ["contratti"])
        #expect(counted(["data analysis", "invoice", "label printer", "SQL reporting"], "en") == ["data analysis", "invoice"])
    }

    @Test("A modifier cut from the noun of another technology is counted; a noun joined to another technology is not (#354, round 5)")
    func clippedModifier() {
        let counted = { (description: String, names: [String], language: String) in
            let input = DraftingInput(id: "reader-\(language)", kind: .plain, language: language, description: description, facts: [], traps: [])
            let cv = CVData(skills: names.map { Skill(name: $0) })
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .clippedModifier }.map(\.value)
        }

        #expect(counted("Leggo disegni meccanici e idraulici e monto tubi flessibili e valvole.",
                        ["disegni meccanici", "idraulici", "tubi flessibili", "valvole"], "it") == ["idraulici"])
        #expect(counted("I read hydraulic and electric diagrams and fit valves and flexible hoses.",
                        ["electric diagrams", "hydraulic", "flexible hoses", "valves"], "en") == ["hydraulic"])
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
