import Testing
@testable import CVGeneratorAI

/// The checks of a draft written a section at a time (ADR 0031, "A request per section"): each job's duties, the skills and the
/// summary are read sentence by sentence, as the final check reads them, with the reason a repair request reads for each sentence
/// that goes. The descriptions are Italian, and their language is given, so the checks read the same on every platform; every name,
/// trade and date is invented.
@Suite("The checks of a draft written a section at a time (ADR 0031)")
struct SectionChecksTests {
    private let sanitizer = Self.italian(ForcedLexicalTagger([:]), wordList: TableWordList())

    /// A sanitizer that reads every text as Italian: without it, the language of a description is the device's guess, which some
    /// platforms do not make.
    private static func italian(_ tagger: ForcedLexicalTagger, wordList: any WordList) -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { _ in "it" }, lexicalClasses: tagger, wordList: wordList)
    }

    private static func job(_ title: String, _ company: String, from start: String, to end: String? = nil) -> Experience {
        Experience(title: title, company: company, startDate: start, endDate: end, current: end == nil)
    }

    private static let italianJobs = CVData(experience: [
        job("operaio manutentore", "Conserve Albarella", from: "2010", to: "2014"),
        job("manutentore elettromeccanico", "Pastificio Cerreto", from: "2014", to: "2018"),
        job("manutentore elettromeccanico", "Molino Fontebasso", from: "2018", to: "2020"),
        job("capoturno della manutenzione", "Birrificio Valtrigno", from: "2020"),
    ])

    // MARK: The form of a duty

    @Test("A duty's form is the way it starts: I, a verb in -ing or another verb in English; the first person, a gerund or an infinitive in Italian")
    func formOfADuty() {
        #expect(CVDataSanitizer.form("I plan the menus.", language: .english) == .withI)
        #expect(CVDataSanitizer.form("Planning the menus.", language: .english) == .ing)
        #expect(CVDataSanitizer.form("Plans the menus.", language: .english) == .verb)
        #expect(CVDataSanitizer.form("Controllavo i quadri.", language: .italian) == .firstPerson)
        #expect(CVDataSanitizer.form("Controllando i quadri.", language: .italian) == .gerund)
        #expect(CVDataSanitizer.form("Controllare i quadri.", language: .italian) == .infinitive)
        #expect(CVDataSanitizer.form("Ich plane die Menüs.", language: .german) == nil)
    }

    // MARK: The duties of a job

    @Test("A job's written duties keep the duties the person said in front, and drop a repeat, another job's name, another form and a fragment, each with its reason")
    func dutiesOfAJob() throws {
        let written = """
            Riparavo i motori elettrici. Coordinavo i turni al Birrificio Valtrigno. Eseguivo la lubrificazione dei macchinari. \
            Sostituire i cuscinetti usurati. Riparavo i nastri trasportatori. Riparavo i motori e
            """

        let verdicts = try sanitizer.dutyCheck(of: Self.italianJobs, job: 0, duties: written, against: JobClausesTests.italian)

        #expect(verdicts.pinned == ["Riparavo i nastri trasportatori."])
        #expect(verdicts.kept == ["Riparavo i motori elettrici.", "Eseguivo la lubrificazione dei macchinari."])
        let reasons = Dictionary(uniqueKeysWithValues: verdicts.rejected.map { ($0.sentence, $0.reason) })
        #expect(reasons["Riparavo i nastri trasportatori."] == "it repeats a duty already written")
        #expect(reasons["Coordinavo i turni al Birrificio Valtrigno."] != nil)
        #expect(reasons["Sostituire i cuscinetti usurati."]?.hasPrefix("it is written in another form") == true)
        #expect(reasons["Riparavo i motori e"] == "it is not a whole sentence")
        #expect(verdicts.avoid.contains("Valtrigno") || verdicts.avoid.contains("valtrigno"))
    }

    // MARK: D6, the typical duties of a job the person described (#354, round 1)

    @Test("d6: a job whose stated duties are under 40 characters keeps a typical duty after them")
    func d6TypicalDutyOfAShortJobStays() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.italianJobs, job: 3, duties: "Pianifico i turni della squadra.", against: JobClausesTests.italian
        )

        #expect(verdicts.pinned == ["Coordino tre tecnici."])
        #expect(verdicts.kept == ["Pianifico i turni della squadra."])
        #expect(!verdicts.saysEnough)
    }

    @Test("d6: a job whose stated duties run to 40 characters keeps them and drops a typical duty, with its reason")
    func d6TypicalDutyOfADescribedJobGoes() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.italianJobs, job: 1, duties: "Eseguivo la lubrificazione dei macchinari.", against: JobClausesTests.italian
        )

        #expect(verdicts.pinned == ["Controllavo i quadri elettrici e programmavo la manutenzione preventiva."])
        #expect(verdicts.kept.isEmpty)
        #expect(verdicts.rejected.map(\.reason) == [CVDataSanitizer.DutyVerdicts.describedReason])
        #expect(verdicts.saysEnough)
    }

    @Test("A repair's duties are checked against the duties kept before it, and the duties of a job past the draft's are none")
    func repairAgainstEarlier() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.italianJobs, job: 1, duties: "Eseguivo la lubrificazione dei macchinari.",
            keeping: ["Eseguivo la lubrificazione dei macchinari."], against: JobClausesTests.italian
        )
        let none = try sanitizer.dutyCheck(of: Self.italianJobs, job: 9, duties: "Riparavo i motori.", against: JobClausesTests.italian)

        #expect(verdicts.kept.isEmpty)
        #expect(verdicts.rejected.map(\.reason) == ["it repeats a duty already written"])
        #expect(none.kept.isEmpty && none.pinned.isEmpty && none.rejected.isEmpty)
    }

    /// A job the person names with no duty of its own, ended and then current (#354).
    private static let clerk = "Dal 2013 al 2017 sono stata impiegata contabile allo Studio Ferretti di Lodi."
    private static let clerkNow = "Dal 2017 lavoro come impiegata contabile allo Studio Ferretti di Lodi."
    private static let clerkJob = CVData(experience: [job("impiegata contabile", "Studio Ferretti", from: "2013", to: "2017")])
    private static let clerkJobNow = CVData(experience: [job("impiegata contabile", "Studio Ferretti", from: "2017")])

    @Test("A duty that starts with an infinitive goes, also as the job's first one; a duty in the first person stays (#354)")
    func infinitiveDuty() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.clerkJob, job: 0, duties: "Registrare le fatture dei clienti. Controllavo i pagamenti dei fornitori.",
            against: Self.clerk
        )

        #expect(verdicts.kept == ["Controllavo i pagamenti dei fornitori."])
        #expect(verdicts.rejected.map(\.sentence) == ["Registrare le fatture dei clienti."])
        #expect(verdicts.rejected.first?.reason.hasPrefix("it starts with an infinitive") == true)
    }

    @Test("An ended job's duty in the present goes after one in the past; the current job's duties in the present stay (#354)")
    func tenseOfAnEndedJob() throws {
        let duties = "Controllavo i pagamenti dei fornitori. Registro le fatture dei clienti. Preparavo i documenti per la banca."
        let ended = try sanitizer.dutyCheck(of: Self.clerkJob, job: 0, duties: duties, against: Self.clerk)
        let current = try sanitizer.dutyCheck(
            of: Self.clerkJobNow, job: 0, duties: "Controllo i pagamenti dei fornitori. Registro le fatture dei clienti.",
            against: Self.clerkNow
        )

        #expect(ended.kept == ["Controllavo i pagamenti dei fornitori.", "Preparavo i documenti per la banca."])
        #expect(ended.rejected.map(\.sentence) == ["Registro le fatture dei clienti."])
        #expect(ended.rejected.first?.reason.hasPrefix("it is in the present, and the job has ended") == true)
        #expect(current.kept == ["Controllo i pagamenti dei fornitori.", "Registro le fatture dei clienti."])
    }

    @Test("A duty's tense is the ending of its first word in Italian, Spanish and Portuguese, and none in English (#354)")
    func tenseOfADuty() {
        #expect(CVDataSanitizer.tense(of: "Colaboro com as equipas de design.", language: .portuguese) == .present)
        #expect(CVDataSanitizer.tense(of: "Desenhava os cartazes da loja.", language: .portuguese) == .past)
        #expect(CVDataSanitizer.tense(of: "Coordiné los turnos del almacén.", language: .spanish) == .past)
        #expect(CVDataSanitizer.tense(of: "Organizo los turnos del almacén.", language: .spanish) == .present)
        #expect(CVDataSanitizer.tense(of: "Ho gestito le fatture.", language: .italian) == .past)
        #expect(CVDataSanitizer.tense(of: "Sono responsabile delle fatture.", language: .italian) == nil)
        #expect(CVDataSanitizer.tense(of: "I plan the menus.", language: .english) == nil)
    }

    // MARK: The context of each job

    @Test("Each job the facts keep gets the clauses of the description that belong to it, in the order of the facts, and the field the person states")
    func contextOfEachJob() throws {
        let context = try sanitizer.draftContext(of: Self.italianJobs, against: JobClausesTests.italian)
        let facts = try sanitizer.sanitize(Self.italianJobs, against: JobClausesTests.italian)

        #expect(context.jobs.count == facts.experience.count)
        #expect(context.jobs.map(\.job) == [0, 1, 2, 3])
        #expect(context.jobs[0].clauses.contains { $0.contains("nastri trasportatori") })
        #expect(!context.jobs[0].clauses.contains { $0.contains("Birrificio") })
        #expect(context.jobs[3].clauses.contains { $0.contains("coordino tre tecnici") })
    }

    @Test("The sentences in which the person says what they do and what they are like, with no job, reach the skills; a search, a job's sentence and a number do not (#354, round 1)")
    func ownSentences() throws {
        let description = JobClausesTests.italian + """

            Leggo gli schemi elettrici e pneumatici e uso i PLC per trovare i guasti.
            Sono preciso e mi piace lavorare in squadra.
            Cerco un posto da responsabile della manutenzione in un'azienda più grande.
            Seguo 3 linee di imbottigliamento.
            """

        let context = try sanitizer.draftContext(of: Self.italianJobs, against: description)

        #expect(context.own.contains("Leggo gli schemi elettrici e pneumatici e uso i PLC per trovare i guasti."))
        #expect(context.own.contains("Sono preciso e mi piace lavorare in squadra."))
        #expect(!context.own.contains { $0.contains("Cerco") || $0.contains("imbottigliamento") || $0.contains("Valtrigno") })
        #expect(!context.own.contains { $0.contains("Pastificio") || $0.contains("Albarella") })
    }

    // MARK: The skills

    @Test("A quality listed as a tool is a soft skill, and a tool named by an activity goes, even when the tagger reads its first word as a verb")
    func skillsCleaned() {
        let tagging = Self.italian(ForcedLexicalTagger([.italian: .words(["software"])]), wordList: TableWordList())
        let description = "Dal 2020 lavoro al Birrificio Valtrigno, dove uso i PLC e gestisco i fermi impianto."

        let verdict = tagging.skillCheck(
            technologies: ["PLC", "precisione", "software di gestione fermi", "PLC"], softSkills: ["lavoro di squadra"], against: description
        )

        #expect(verdict.technologies == ["PLC"])
        #expect(verdict.softSkills == ["precisione", "lavoro di squadra"])
        #expect(verdict.dropped.map(\.reason) == ["activity"])
    }

    @Test("A skill whose words are all of English, in a description of another language, goes")
    func skillInAnotherLanguage() {
        let englishOnly = Self.italian(ForcedLexicalTagger([:]), wordList: EnglishOnly())

        let verdict = englishOnly.skillCheck(
            technologies: ["preventive maintenance"], softSkills: [], against: JobClausesTests.italian
        )

        #expect(verdict.technologies.isEmpty)
        #expect(verdict.dropped.map(\.reason) == ["another language"])
    }

    @Test("Of two technologies of one kind, by their head noun, the second goes; tools of other kinds, and a short last word, stay (#354)")
    func toolsOfOneKind() {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let french = CVDataSanitizer(languageOfText: { _ in "fr" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let sound = english.skillCheck(
            technologies: ["studio monitors", "digital mixing desk", "nearfield monitor", "Shure microphones", "Logic Pro", "Premiere Pro"],
            softSkills: [], against: "I mix the sound for a small theatre in Hull."
        )
        let wiring = french.skillCheck(
            technologies: ["pince à dénuder", "multimètre", "pinces coupantes", "l'oscilloscope"], softSkills: [],
            against: "Je câble des tableaux électriques à Rouen."
        )

        #expect(sound.technologies == ["studio monitors", "digital mixing desk", "Shure microphones", "Logic Pro", "Premiere Pro"])
        #expect(sound.dropped.map(\.reason) == ["same kind as an earlier tool"])
        #expect(wiring.technologies == ["pince à dénuder", "multimètre", "l'oscilloscope"])
        #expect(wiring.dropped.map(\.sentence) == ["pinces coupantes"])
    }

    @Test("A technology that names an activity, or a kind of tool by what it does, goes; equipment, a named tool and one with an acronym stay (#354, round 1)")
    func activityIsNoTechnology() {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let sound = english.skillCheck(
            technologies: [
                "digital consoles", "frequency calibration", "PA systems", "signal routing", "beam focusing", "tracking software",
                "PLC programming", "line arrays", "docking station",
            ],
            softSkills: [], against: "I mix the sound for a small theatre in Hull."
        )
        let plant = sanitizer.skillCheck(
            technologies: [
                "PLC", "software di tracciamento", "sistema di controllo remoto", "stazione di saldatura", "manutenzione preventiva",
                "multimetro", "programmazione PLC",
            ],
            softSkills: [], against: JobClausesTests.italian
        )

        #expect(sound.technologies == ["digital consoles", "PA systems", "PLC programming", "line arrays", "docking station"])
        #expect(sound.dropped.map(\.sentence) == ["frequency calibration", "signal routing", "beam focusing", "tracking software"])
        #expect(Set(sound.dropped.map(\.reason)) == ["activity"])
        #expect(plant.technologies == ["PLC", "stazione di saldatura", "multimetro", "programmazione PLC"])
        #expect(plant.dropped.map(\.sentence) == ["software di tracciamento", "sistema di controllo remoto", "manutenzione preventiva"])
    }

    @Test("A fragment and a lone verb go from the skills")
    func fragmentsGo() {
        let verdict = sanitizer.skillCheck(
            technologies: ["manutenzione di", "uso dei PLC: base"], softSkills: [], against: JobClausesTests.italian
        )

        #expect(verdict.technologies.isEmpty)
        #expect(verdict.dropped.map(\.reason) == ["fragment", "fragment"])
    }

    @Test("A word that names a skill and no skill goes from the soft skills; a quality said with it stays (#354)")
    func skillWordsGo() {
        let verdict = sanitizer.skillCheck(
            technologies: [], softSkills: ["competenze", "Capacità", "compétence", "capacità di ascolto", "precisione"],
            against: JobClausesTests.italian
        )

        #expect(verdict.softSkills == ["capacità di ascolto", "precisione"])
        #expect(verdict.dropped.map(\.reason) == ["a word for a skill", "a word for a skill", "a word for a skill"])
    }

    @Test("A soft skill whose head noun is a tool goes; one that only starts with a tool word stays (#354)",
          arguments: [
              ("de", "Präzisionswerkzeug", false), ("de", "Systemdenken", true), ("de", "Sorgfalt", true),
              ("en", "communication tools", false), ("en", "systems thinking", true),
              ("it", "strumenti di misura", false), ("it", "pensiero sistemico", true),
          ])
    func toolAsSoftSkill(language: String, skill: String, stays: Bool) {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = checker.skillCheck(technologies: [], softSkills: [skill], against: "Feinmechanik, Suhl, 2019.")

        #expect(verdict.softSkills == (stays ? [skill] : []))
        #expect(verdict.dropped.map(\.reason) == (stays ? [] : ["a tool"]))
    }

    @Test("A tool the model lists with a word of a quality in it is no soft skill (#354)")
    func toolWithAQualityWord() {
        let checker = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = checker.skillCheck(technologies: ["Präzisionswerkzeug", "Drehmaschine"], softSkills: [], against: "Feinmechanik, Suhl, 2019.")

        #expect(verdict.softSkills.isEmpty)
        #expect(verdict.technologies == ["Drehmaschine"])
    }

    // MARK: The summary

    @Test("A summary sentence about the person in the third person goes, and a short summary with no title gets an opening from the facts")
    func summaryChecked() throws {
        // The current job's sentence names its employer alone, so that the facts keep the job current.
        let description = JobClausesTests.italian.replacingOccurrences(
            of: "Birrificio Valtrigno di Campobasso, dove coordino tre tecnici.", with: "Birrificio Valtrigno."
        )

        let verdict = try sanitizer.summaryCheck(
            of: Self.italianJobs, summary: "Lui è un tecnico esperto. Mi occupo degli impianti con cura.", field: nil, against: description
        )

        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.speaksInTheThirdPerson])
        #expect(verdict.kept == ["Mi occupo degli impianti con cura."])
        #expect(verdict.problems.contains("it keeps fewer than 2 sentences"))
        #expect(verdict.problems.contains("it is shorter than 120 characters"))
        #expect(verdict.opening == "Lavoro come capoturno della manutenzione.")
    }

    @Test("A summary sentence whose subject is a bare word of the person's work goes; one with its article or as the person stays (#354, round 1)")
    func summaryWithABareSubject() throws {
        let description = JobClausesTests.italian.replacingOccurrences(
            of: "Birrificio Valtrigno di Campobasso, dove coordino tre tecnici.", with: "Birrificio Valtrigno."
        )

        let verdict = try sanitizer.summaryCheck(
            of: Self.italianJobs,
            summary: "Manutenzione è la mia attività principale. La manutenzione degli impianti è il mio lavoro di ogni giorno. "
                + "Mi occupo degli impianti con cura.",
            field: nil, against: description
        )

        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.hasABareSubject])
        #expect(verdict.kept == ["La manutenzione degli impianti è il mio lavoro di ogni giorno.", "Mi occupo degli impianti con cura."])
    }

    @Test("A summary sentence with no word of the person goes where the pronoun is kept; one about the person stays (#354)")
    func summaryOfThePerson() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("sound technician", "Copperfield Arena", from: "2019")])
        let description = "I am a sound technician at Copperfield Arena since 2019. I set up the PA systems and mix the support acts."

        let verdict = try english.summaryCheck(
            of: facts,
            summary: "Clear sound is the heart of every live show. As a sound technician, my work covers the sound desks, the stage "
                + "monitors and the mixing of live acts. I keep calm when a show runs late.",
            field: nil, against: description
        )

        #expect(verdict.rejected.map(\.sentence) == ["Clear sound is the heart of every live show."])
        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.saysNothingOfThePerson])
        #expect(verdict.kept.count == 2)
        #expect(verdict.opening == nil)
    }

    @Test("A summary sentence with a verb of the third person and no subject goes where the pronoun is dropped; one as the person stays (#354)",
          arguments: [
              ("es", "Contable gestiona los registros con cuidado.", false), ("es", "El contable revisa las facturas.", false),
              ("es", "Analiza los movimientos de caja.", false), ("es", "Se encarga de la contabilidad.", false),
              ("es", "Analizo los movimientos de caja.", true), ("es", "Experiencia en contabilidad de pymes.", true),
              ("es", "Hice la contabilidad de tres empresas.", true), ("es", "Para la empresa llevo la contabilidad.", true),
              ("es", "Llevaba la contabilidad de la empresa.", true),
              ("it", "Si occupa della contabilità.", false), ("it", "Gestisce la contabilità della ditta.", false),
              ("it", "Mi occupo della contabilità.", true), ("it", "Durante il giorno seguo la contabilità.", true),
              ("it", "Gestire la contabilità mi piace.", true),
              ("pt", "Analisa os movimentos de caixa.", false), ("pt", "Analiso os movimentos de caixa.", true),
          ])
    func summaryInTheThirdPerson(language: String, sentence: String, stays: Bool) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("contable", "Muebles Albarracín", from: "2017")])
        let description = "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y "
            + "analizo los movimientos de caja."

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.speaksInTheThirdPerson) == !stays, "\(verdict.rejected)")
    }

    @Test("A summary naming no title whole gets the opening; a sentence with its verb, an earlier verb or a duty goes (#354)")
    func summaryWithoutRepeats() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("sound technician", "Copperfield Arena", from: "2019")])
        let description = "I am a sound technician at Copperfield Arena since 2019. I set up the PA systems and mix the support acts."

        let verdict = try english.summaryCheck(
            of: facts,
            summary: "I work with sound for bands of every kind and size. I mix live acts with a steady hand and a clear ear. "
                + "I mix bands on small stages too. I set up the PA systems and mix the support acts.",
            field: nil, duties: ["I set up the PA systems and mix the support acts."], against: description
        )

        #expect(verdict.opening == "I work as a sound technician.")
        #expect(verdict.kept == ["I mix live acts with a steady hand and a clear ear."])
        #expect(verdict.rejected.map(\.reason) == [
            CVDataSanitizer.startsAsAnEarlierOne,
            "it says again a duty of a job: say what the person's work has in common",
            CVDataSanitizer.startsAsAnEarlierOne,
        ])
        #expect(verdict.problems.first == "it keeps fewer than 2 sentences")
    }

    @Test("A summary naming a title whole gets no opening; its sentences with other verbs, and one joining duties, stay (#354)")
    func summaryNamingATitle() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("sound technician", "Copperfield Arena", from: "2019")])
        let description = "I am a sound technician at Copperfield Arena since 2019. I set up the PA systems and mix the support acts."

        let verdict = try english.summaryCheck(
            of: facts,
            summary: "I work as a sound technician for live shows of every size. I mix live acts with a steady hand and a clear ear, "
                + "from the first check to the last song.",
            field: nil, duties: ["I set up the PA systems and mix the support acts."], against: description
        )

        #expect(verdict.opening == nil)
        #expect(verdict.rejected.isEmpty)
        #expect(verdict.kept.count == 2)

        let joining = try english.summaryCheck(
            of: facts,
            summary: "I work as a sound technician for live shows of every size. I set up the sound systems, mix the support "
                + "acts and keep each show on time.",
            field: nil, duties: ["I set up the sound systems.", "I mix the support acts."], against: description
        )
        #expect(joining.rejected.isEmpty)
    }

    @Test("The opening says the current job's title in the present, else the last one's in the past, in the description's language")
    func openings() {
        let teacher = CVData(experience: [Self.job("institutrice", "École Lamartine", from: "2015")])
        let electrician = CVData(experience: [
            Self.job("apprentice", "Brook Lane Works", from: "2009", to: "2012"),
            Self.job("electrician", "Harlow Fittings", from: "2012", to: "2019"),
        ])

        #expect(CVDataSanitizer.opening(of: teacher, language: .french) == "Je travaille comme institutrice.")
        #expect(CVDataSanitizer.opening(of: electrician, language: .english) == "I worked as an electrician.")
        #expect(CVDataSanitizer.opening(of: electrician, language: .german) == "Ich habe als electrician gearbeitet.")
        #expect(CVDataSanitizer.opening(of: CVData(), language: .english) == nil)
        #expect(CVDataSanitizer.opening(of: teacher, language: nil) == nil)
    }
}

/// A dictionary that knows every word in English and none in any other language.
private struct EnglishOnly: WordList {
    func knows(_ word: String, inLanguage language: String) -> Bool? { language == "en" }
}
