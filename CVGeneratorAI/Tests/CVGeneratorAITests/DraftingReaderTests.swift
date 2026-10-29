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

    @Test("A German separable verb split at the end of a subordinate clause is counted; one split in a main clause, or joined, is not, nor a noun before the verb (#354, rounds 4 and 8)")
    func splitSeparableVerb() {
        let cv = CVData(
            summary: "Ich arbeite als Schleusenwärter. Ich achte darauf, dass ich die Funktion der Tore sicher stelle. "
                + "Ich öle die Tore, bevor die Kähne ein fahren. Ich arbeite ruhig, indem ich auf jedes Teil achte. "
                + "Ich lerne viel, weil ich an jeder Übung teil nehme.",
            experience: [Experience(
                title: "Schleusenwärter", company: "Kanal Brindle",
                description: "Ich stelle die Funktion der Tore sicher. Ich prüfe, ob die Schleuse richtig zumacht."
            )]
        )

        #expect(Self.reader(cv, "de").filter { $0.kind == .splitVerb }.map(\.value) == ["sicher stelle", "ein fahren", "teil nehme"])
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

    @Test("A summary sentence whose only word in \"-o\" after a comma is a gerund speaks as no one; a first person of the same ending speaks (#354, round 6)")
    func gerundSummary() {
        let italian = CVData(summary: "Le consegne richiedono ordine, garantendo tempi certi. Con calma, comprendo le richieste dei clienti.")
        let spanish = CVData(summary: "Mantenido un inventario preciso de las piezas, evitando faltas. Atiendo a los clientes con calma.")
        let portuguese = CVData(summary: "As entregas exigem ordem, garantindo prazos certos. Atendo os clientes com calma.")
        let counted = { (cv: CVData, language: String, kind: ReaderClass) in
            Self.reader(cv, language).filter { $0.kind == kind }.map(\.value)
        }

        #expect(counted(italian, "it", .impersonalSummary) == ["Le consegne richiedono ordine, garantendo tempi certi."])
        #expect(counted(spanish, "es", .participleSummary) == ["Mantenido un inventario preciso de las piezas, evitando faltas."])
        #expect(counted(spanish, "es", .impersonalSummary).isEmpty)
        #expect(counted(portuguese, "pt", .impersonalSummary) == ["As entregas exigem ordem, garantindo prazos certos."])
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

    @Test("Stationery as a technology is counted, also with a word after or before its noun; a board or a pen that is a device is not (#354, round 6)")
    func stationeryTechnology() {
        let counted = { (names: [String], language: String) in
            Self.reader(CVData(skills: names.map { Skill(name: $0) }), language).filter { $0.kind == .stationeryTechnology }.map(\.value)
        }

        #expect(counted(["cahiers de brouillon", "tableau interactif", "stylo"], "fr") == ["cahiers de brouillon", "stylo"])
        #expect(counted(["quaderni di lavoro", "lavagna interattiva"], "it") == ["quaderni di lavoro"])
        #expect(counted(["cuadernos de ejercicios", "lápiz óptico"], "es") == ["cuadernos de ejercicios"])
        #expect(counted(["cadernos de atividades", "quadro interativo"], "pt") == ["cadernos de atividades"])
        #expect(counted(["rote Stifte", "digitale Tafel"], "de") == ["rote Stifte"])
        #expect(counted(["gel pens", "digital pens"], "en") == ["gel pens"])
    }

    @Test("A German subordinate clause that ends with a noun or an adverb after its verb is counted; one that ends with its verb is not (#354, rounds 5 and 12)")
    func germanVerbPosition() {
        let cv = CVData(summary: "Ich arbeite als Schleusenwärter. Ich prüfe, dass alle Tore schließen sauber nach jeder Fahrt. "
            + "Ich achte darauf, dass die Tore sauber schließen. Ich weiß, ob die Pumpe läuft. "
            + "Ich sorge dafür, dass die Schleusen öffnen zuverlässig. Ich sehe, dass die Pumpen ruhig laufen. "
            + "Ich weiß, dass die Kunden zufrieden sind.")

        #expect(Self.reader(cv, "de").filter { $0.kind == .germanVerbPosition }.map(\.value) == [
            "dass alle Tore schließen sauber nach jeder Fahrt", "dass die Schleusen öffnen zuverlässig",
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

    @Test("The office, class and workshop tools a reader accepted in round 7's answers are of their trade; a forklift in a classroom, a trailer and a scan are not (#354, round 8)")
    func roundSevenToolsAreOfTheirTrade() throws {
        let inputs = DraftingInputs.written + DraftingInputs.jobs + (try DraftingInputs.examples())
        let byId = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0) })
        let counted = { (names: [String], id: String) in
            guard let input = byId[id] else { return ["no input \(id)"] }
            let cv = CVData(skills: names.map { Skill(name: $0) })
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .offTradeTechnology }.map(\.value)
        }

        #expect(counted(["logiciel de gestion de classe", "système de suivi des progrès", "imprimante multifonction scolaire"], "example-fr") == [])
        #expect(counted(["logiciel de gestion de classe", "chariot élévateur"], "example-fr") == ["chariot élévateur"])
        #expect(counted(["Google Calendar", "Documenti"], "it-traps") == ["Documenti"])
        #expect(counted(["Google Sheets", "Escaneo"], "es-traps") == ["Escaneo"])
        #expect(counted(["audio editing software", "trailer"], "jobs-en") == ["trailer"])
        #expect(counted(["strumenti di diagnostica industriale", "sensori di temperatura", "navigatore GPS"], "jobs-it") == ["navigatore GPS"])
        #expect(counted(["Werkzeugkasten", "Gabelstapler"], "de-plain") == ["Gabelstapler"])
        #expect(counted(["barcode scanner", "trailer", "GPS"], "en-plain") == ["trailer", "GPS"])
    }

    @Test("A part the electrician installs is a work object; a measuring tool is not")
    func partsAreNoTools() throws {
        let electrician = try #require(DraftingInputs.written.first { $0.id == "de-plain" })
        let cv = CVData(skills: ["Schalter", "Elektrische Leitungen", "Multimeter", "KNX"].map { Skill(name: $0) })

        let found = ReaderRules.findings(in: cv, for: electrician, report: InventedFacts.count(cv, for: electrician))

        #expect(found.filter { $0.kind == .workObjectTechnology }.map(\.value) == ["Schalter", "Elektrische Leitungen"])
    }

    @Test("A work object of the maintainer is counted; a tool named after a verb of use and a tool whose head is a tool are not (#354, round 7)")
    func workObjectTechnology() throws {
        let maintainer = try #require(DraftingInputs.jobs.first { $0.id == "jobs-it" })
        let used = DraftingInput(
            id: "jobs-it", kind: .jobs, language: "it", description: "Uso i quadri elettrici di prova.", facts: [], traps: []
        )
        let names = ["quadri elettrici", "PLC", "software di gestione impianti", "cuscinetti"]
        let counted = { (input: DraftingInput) in
            let cv = CVData(skills: names.map { Skill(name: $0) })
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .workObjectTechnology }.map(\.value)
        }

        #expect(counted(maintainer) == ["quadri elettrici", "cuscinetti"])
        #expect(counted(used) == ["cuscinetti"])
    }

    @Test("A generic system with a work word is counted; a stated one, one of the trade's list, a named or a device one is not (#354, round 9)")
    func genericSystemTechnology() throws {
        let maintainer = try #require(DraftingInputs.jobs.first { $0.id == "jobs-it" })
        let engineer = try #require(DraftingInputs.jobs.first { $0.id == "jobs-en" })
        let accountant = try #require(DraftingInputs.written.first { $0.id == "es-traps" })
        let electrician = try #require(DraftingInputs.written.first { $0.id == "de-plain" })
        let stated = DraftingInput(
            id: "jobs-it", kind: .jobs, language: "it", description: maintainer.description + " Uso il software di gestione impianti.",
            facts: maintainer.facts, traps: []
        )
        let counted = { (names: [String], input: DraftingInput) in
            let cv = CVData(skills: names.map { Skill(name: $0) })
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .genericSystemTechnology }.map(\.value)
        }
        let italian = ["sistema di tracciamento dati", "software di gestione impianti", "strumenti di diagnostica industriale", "PLC"]

        #expect(counted(italian, maintainer) == ["sistema di tracciamento dati", "software di gestione impianti"])
        #expect(counted(italian, stated) == ["sistema di tracciamento dati"])
        #expect(counted([
            "truck loading equipment", "PA system", "Audio editing software", "QLab playback system", "digital mixing system", "software",
        ], engineer) == ["truck loading equipment"])
        #expect(counted(["sistema de gestión de documentos", "máquina de escaneo de registros", "software de contabilidad", "Excel"],
                        accountant) == ["sistema de gestión de documentos", "máquina de escaneo de registros"])
        #expect(counted(["Montagesystem", "Steuerungssystem", "KNX", "Werkzeugkasten", "System"], electrician) == ["Montagesystem"])
    }

    @Test("A technology with a word of an employer's name is counted; a stated one and a word also written in lowercase are not (#354, round 7)")
    func employerWordTechnology() throws {
        let supervisor = try #require(DraftingInputs.written.first { $0.id == "en-plain" })
        let names = ["Kestrel forklift", "Logistics software", "SAP", "pallet jack"]
        let cv = CVData(skills: names.map { Skill(name: $0) })
        let stated = DraftingInput(
            id: "en-plain", kind: .plain, language: "en", description: supervisor.description + " I use the SAP Kestrel module.",
            facts: supervisor.facts, traps: []
        )
        let counted = { (input: DraftingInput, cv: CVData) in
            ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .employerWordTechnology }.map(\.value)
        }

        #expect(counted(supervisor, cv) == ["Kestrel forklift"])
        #expect(counted(stated, CVData(skills: [Skill(name: "SAP Kestrel module")])) == [])
    }

    // MARK: Summary titles

    @Test("A summary that says the person worked as no kept title is counted; a kept title, a part of one and a quality are not (#354, round 7)")
    func inventedSummaryTitle() throws {
        let clerk = try #require(DraftingInputs.written.first { $0.id == "it-traps" })
        let counted = { (summary: String) in
            let cv = CVData(
                personalInfo: PersonalInfo(title: "impiegata amministrativa"), summary: summary,
                experience: [Experience(title: "impiegata amministrativa", company: "Ferramenta Scaligera", startDate: "2017", current: true)]
            )
            return ReaderRules.findings(in: cv, for: clerk, report: InventedFacts.count(cv, for: clerk))
                .filter { $0.kind == .inventedSummaryTitle }.count
        }

        #expect(counted("Sono impiegata amministrativa a Verona. In passato ho lavorato come contabile.") == 1)
        #expect(counted("Lavoro come impiegata amministrativa alla Ferramenta Scaligera.") == 0)
        #expect(counted("Lavoro come impiegata in amministrazione.") == 0)
        #expect(counted("Sono precisa e organizzata.") == 0)
        #expect(counted("Sono consulente fiscale.") == 1)
        #expect(counted("Lavoro come impiegata e studio i bilanci per il mio ufficio.") == 0)
        #expect(counted("In passato ho lavorato come magazziniera, cassiera e contabile.") == 3)
    }

    @Test("The opening's verb opening another summary sentence is counted; two verbs are not (#354, round 7)")
    func floorVerbCollision() {
        let counted = { (summary: String) in
            Self.reader(CVData(summary: summary), "it").filter { $0.kind == .floorVerbCollision }.map(\.value)
        }

        #expect(counted("Lavoro come capoturno della manutenzione. Lavoro da sedici anni nella manutenzione.")
            == ["Lavoro da sedici anni nella manutenzione."])
        #expect(counted("Sono capoturno della manutenzione. Lavoro da sedici anni nella manutenzione.") == [])
        #expect(counted("Lavoro come capoturno. Coordino tre tecnici.") == [])
    }

    @Test("A noun glued to the next word of an answer is counted; a particle joined to its verb and two words without a capital are not (#354, round 8)")
    func gluedWord() {
        let cv = CVData(summary: "Ich prüfe jede Schleuse, indem ich auf jedes Stückachte. Ich lerne gern, weil ich an jeder Übung teilnehme.")

        #expect(ReaderRules.gluedWords(in: cv, answers: ["Ich prüfe jede Schleuse, indem ich auf jedes Stück achte."]).map(\.value) == ["Stückachte"])
        #expect(ReaderRules.gluedWords(in: cv, answers: ["Ich lerne gern, weil ich an jeder Übung teil nehme."]).isEmpty)
        #expect(ReaderRules.gluedWords(in: cv, answers: ["auf jedes stück achte"]).isEmpty)
    }

    @Test("One noun with two adjectives in two sentences of a job is counted; one noun with one adjective, and two nouns, are not (#354, round 8)")
    func rewordedDuty() {
        let counted = { (description: String) in
            Self.reader(CVData(experience: [Experience(title: "segretaria", company: "Vetreria Olmo", description: description)]), "it")
                .filter { $0.kind == .rewordedDuty }.map(\.value)
        }

        #expect(counted("Preparo le spedizioni nazionali. Controllo le spedizioni urgenti del mattino.")
            == ["spedizioni nazionali / spedizioni urgenti"])
        #expect(counted("Preparo le spedizioni nazionali. Archivio le spedizioni nazionali.") == [])
        #expect(counted("Preparo le spedizioni nazionali. Controllo le consegne urgenti.") == [])
    }

    @Test("Two summary sentences closing with one clause are counted; one closing clause, and two clauses with other words, are not (#354, round 8)")
    func repeatedTail() {
        let counted = { (summary: String) in Self.reader(CVData(summary: summary), "de").filter { $0.kind == .repeatedTail }.map(\.value) }

        #expect(counted("Ich baue Regale auf, was meine Sorgfalt zeigt. Ich messe Wände aus, was meine Geduld zeigt.")
            == ["Ich messe Wände aus, was meine Geduld zeigt."])
        #expect(counted("Ich baue Regale auf, was meine Sorgfalt zeigt. Ich messe Wände aus, damit alles passt.") == [])
        #expect(counted("Ich baue Regale auf. Ich messe Wände aus, was meine Geduld zeigt.") == [])
    }

    @Test("A present summary sentence of an ended job's duties is counted; one of a current job, and one in the past, are not (#354, round 10)")
    func endedDutyInSummary() {
        let jobs = [
            Experience(title: "caposala", company: "Ostello Pino", current: true, description: "Organizzo i turni del personale di sala."),
            Experience(title: "cameriere", company: "Trattoria Faggio", description: "Ho servito i piatti ai tavoli. Ho apparecchiato i coperti serali."),
        ]
        let counted = { (summary: String) in
            Self.reader(CVData(summary: summary, experience: jobs), "it").filter { $0.kind == .endedDutyInSummary }.map(\.value)
        }

        #expect(counted("Lavoro come caposala. Servo i piatti ai tavoli e apparecchio i coperti serali.")
            == ["Servo i piatti ai tavoli e apparecchio i coperti serali."])
        #expect(counted("Lavoro come caposala. Organizzo i turni del personale di sala con cura.") == [])
        #expect(counted("Lavoro come caposala. Ho servito i piatti ai tavoli e apparecchiato i coperti serali.") == [])
    }

    @Test("A self-praise closing clause after the first is counted; the first one and a clause on the work are not (#354, round 10)")
    func selfPraiseTail() {
        let counted = { (summary: String, language: String) in
            Self.reader(CVData(summary: summary), language).filter { $0.kind == .selfPraiseTail }.map(\.value)
        }

        #expect(counted("Ich baue Regale auf, was meine Sorgfalt zeigt. Ich messe Wände aus, was meine Geduld beweist.", "de")
            == ["Ich messe Wände aus, was meine Geduld beweist."])
        #expect(counted("Ich baue Regale auf, was meine Sorgfalt zeigt. Ich messe Wände aus, was die Stabilität erhöht.", "de") == [])
        #expect(counted("I pack the orders, which shows my care. I label the boxes, which shows my focus.", "en")
            == ["I label the boxes, which shows my focus."])
        #expect(counted("Preparo gli ordini, che dimostra la mia cura. Etichetto le scatole, che dimostra la mia attenzione.", "it")
            == ["Etichetto le scatole, che dimostra la mia attenzione."])
    }

    @Test("A frequency the description does not say is counted; one it says is not (#354, round 10)")
    func inventedFrequency() {
        let counted = { (description: String, said: String) in
            let input = DraftingInput(id: "reader-es", kind: .plain, language: "es", description: said, facts: [], traps: [])
            let cv = CVData(experience: [Experience(title: "contable", company: "Taller Olmo", description: description)])
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .inventedFrequency }.map(\.value)
        }

        #expect(counted("Reviso los pagos semanales. Archivo los recibos mensuales.", "Llevo las cuentas del taller.") == ["semanales", "mensuales"])
        #expect(counted("Reviso los pagos semanales.", "Reviso cada semana los pagos semanales del taller.") == [])
    }

    @Test("A summary sentence with a kept tool the description does not state is counted; one with a stated tool is not (#354, round 11)")
    func unstatedToolInSummary() {
        let input = DraftingInput(
            id: "reader-de", kind: .plain, language: "de", description: "Ich bin Elektriker und kenne mich mit KNX aus.", facts: [], traps: []
        )
        let cv = CVData(
            summary: "Ich arbeite als Elektriker. Ich programmiere die Gebäude mit KNX. Ich sichere alle Schritte mit dem Werkzeugkasten ab.",
            skills: ["KNX", "Werkzeugkasten"].map { Skill(name: $0) }
        )

        #expect(ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
            .filter { $0.kind == .unstatedToolInSummary }.map(\.value) == ["Ich sichere alle Schritte mit dem Werkzeugkasten ab."])
    }

    @Test("A summary sentence from a duty the draft wrote is counted; one from a stated duty is not (#354, round 11)")
    func writtenDutyInSummary() {
        let input = DraftingInput(
            id: "reader-it", kind: .plain, language: "it", description: "Sono impiegata amministrativa e gestisco le fatture dei fornitori.",
            facts: [], traps: []
        )
        let cv = CVData(
            summary: "Lavoro come impiegata amministrativa. Controllo le fatture dei fornitori con precisione. "
                + "Rispondo alle comunicazioni con i corrieri.",
            experience: [Experience(
                title: "impiegata amministrativa", company: "Ferramenta Olmo",
                description: "Gestisco le fatture dei fornitori. Organizzo le comunicazioni con i corrieri."
            )]
        )

        #expect(ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
            .filter { $0.kind == .writtenDutyInSummary }.map(\.value) == ["Rispondo alle comunicazioni con i corrieri."])
    }

    @Test("A duty word in lower case that the description has only in an employer's name is counted; the name and a word said elsewhere are not (#354, round 11)")
    func employerWordInDuty() {
        let counted = { (said: String) in
            let input = DraftingInput(
                id: "reader-es", kind: .plain, language: "es", description: said, facts: [.employer("Transportes Ebro Norte")], traps: []
            )
            let cv = CVData(experience: [Experience(
                title: "contable", company: "Transportes Ebro Norte",
                description: "Llevo la contabilidad de Transportes Ebro Norte. Calculo los gastos de transporte."
            )])
            return ReaderRules.findings(in: cv, for: input, report: InventedFacts.count(cv, for: input))
                .filter { $0.kind == .employerWordInDuty }.map(\.value)
        }

        #expect(counted("Trabajo en Transportes Ebro Norte, donde llevo la contabilidad.") == ["transporte"])
        #expect(counted("Trabajo en Transportes Ebro Norte, donde llevo la contabilidad y reviso el transporte.") == [])
    }

    @Test("A duty of a vague phrase is counted; a duty that names its task is not (#354, round 11)")
    func vagueDuty() {
        let cv = CVData(experience: [
            Experience(
                title: "impiegata", company: "Studio Olmo",
                description: "Ho svolto compiti legati alla gestione dei documenti. Gestisco l'archivio dei documenti dei clienti."
            ),
            Experience(title: "clerk", company: "Olmo Ltd", description: "I handled tasks related to the office. I file the invoices."),
        ])

        #expect(Self.reader(cv, "it").filter { $0.kind == .vagueDuty }.map(\.value)
            == ["Ho svolto compiti legati alla gestione dei documenti.", "I handled tasks related to the office."])
    }

    @Test("A description that only says the person worked is counted; one with a word of the job or a duty is not (#354, round 11)")
    func bareWorkDescription() {
        let cv = CVData(experience: [
            Experience(company: "Transportes Ebro Norte", current: true, description: "Trabajo en Transportes Ebro Norte. Llevo la contabilidad."),
            Experience(company: "gestoría Aranda y Molina", endDate: "2018", description: "Trabajé."),
            Experience(company: "guardería", endDate: "2014", description: "Trabajé como auxiliar en una guardería."),
        ])

        #expect(Self.reader(cv, "es").filter { $0.kind == .bareWorkDescription }.map(\.path) == ["experience[1].description"])
    }

    @Test("A job sentence that opens with a relative word is counted; a relative word before a comma and a sentence that opens with the person are not (#354, round 12)")
    func relativeDuty() {
        let cv = CVData(experience: [
            Experience(title: "bibliothécaire", company: "médiathèque Saule", description: "Je range les fonds anciens. Où j'ai classé 40 cartons."),
            Experience(title: "keeper", company: "Ash Park", description: "Where needed, I repair the fences. I feed the goats."),
            Experience(title: "custode", company: "Parco Olmo", description: "Curo il parco. Dove ho piantato i tigli."),
        ])

        #expect(Self.reader(cv, "fr").filter { $0.kind == .relativeDuty }.map(\.value) == ["Où j'ai classé 40 cartons.", "Dove ho piantato i tigli."])
    }

    @Test("A verb with the noun of its own action is counted; a verb with a noun of the people it serves, and two words of other stems, are not (#354, round 12)")
    func ownNounAfterTheVerb() {
        let cv = CVData(
            summary: "Lavoro come archivista. Gestisco la gestione dei registri. Insegno agli insegnanti nuovi a catalogare.",
            experience: [
                Experience(title: "archivist", company: "Elm Records", description: "I manage the management of the ledgers. I file the deeds."),
                Experience(title: "Archivarin", company: "Stadtarchiv Linde", description: "Ich verwalte die Akten. Ich ordne die Bestände."),
            ]
        )

        #expect(Self.reader(cv, "it").filter { $0.kind == .ownNounDuty }.map(\.value)
            == ["I manage the management of the ledgers.", "Gestisco la gestione dei registri."])
    }

    @Test("An ended job with a compound past and an imperfect is counted; one past form, and a current job, are not (#354, round 12)")
    func twoPastForms() {
        let cv = CVData(experience: [
            Experience(title: "magazziniere", company: "Deposito Faggio", endDate: "2019", description: "Ho caricato i furgoni. Controllavo le bolle."),
            Experience(title: "magazziniere", company: "Deposito Tiglio", endDate: "2015", description: "Ho caricato i furgoni. Ho controllato le bolle."),
            Experience(title: "magazziniere", company: "Deposito Pino", current: true, description: "Ho caricato i furgoni. Controllo le bolle."),
        ])
        let french = CVData(experience: [
            Experience(title: "magasinier", company: "dépôt Hêtre", endDate: "2012", description: "J'ai chargé les camions. Je vérifiais les bons."),
        ])

        #expect(Self.reader(cv, "it").filter { $0.kind == .twoPastForms }.map(\.path) == ["experience[0].description"])
        #expect(Self.reader(french, "fr").filter { $0.kind == .twoPastForms }.map(\.path) == ["experience[0].description"])
    }

    @Test("A soft skill of a gerund and its words is counted; a quality and a pair of skills are not (#354, round 10)")
    func gerundSoftSkill() {
        let counted = { (names: [String], language: String) in
            Self.reader(CVData(skills: names.map { Skill(name: $0, kind: .softSkill) }), language)
                .filter { $0.kind == .gerundSoftSkill }.map(\.value)
        }

        #expect(counted(["talking openly with clients", "calm", "planning and organising", "active listening"], "en")
            == ["talking openly with clients"])
        #expect(counted(["ascoltando con cura i colleghi", "precisa"], "it") == ["ascoltando con cura i colleghi"])
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
