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

    @Test("A third duty of a job that opens with the two words of two earlier ones goes; a second one stays (#354, round 2)")
    func dutiesWithOneOpening() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.italianJobs, job: 0,
            duties: "Riparavo i motori elettrici. Riparavo i macchinari usurati. Eseguivo la lubrificazione dei macchinari.",
            keeping: [], against: JobClausesTests.italian
        )

        #expect(verdicts.pinned == ["Riparavo i nastri trasportatori."])
        #expect(verdicts.kept == ["Riparavo i motori elettrici.", "Eseguivo la lubrificazione dei macchinari."])
        #expect(verdicts.rejected.map(\.sentence) == ["Riparavo i macchinari usurati."])
        #expect(verdicts.rejected.map(\.reason) == [CVDataSanitizer.opensAsTwoEarlierOnes])
    }

    @Test("Duties that open with the subject and an auxiliary are no repeated opening: the verb comes later (#354, round 2)")
    func dutiesPastAnAuxiliary() {
        #expect(CVDataSanitizer.opening(of: "J'ai formé les stagiaires.") == nil)
        #expect(CVDataSanitizer.opening(of: "Je veillais à leur hygiène.") == ["je", "veillais"])
        #expect(CVDataSanitizer.opening(of: "Ich habe die Regale montiert.") == nil)
    }

    // MARK: Filler and vague duties (#354, round 11)

    /// The jobs of it-traps: a current one with a duty the person said, and an ended one the person only named.
    private static let itTrapsJobs = CVData(
        personalInfo: PersonalInfo(name: "Chiara Benedetti", location: "Verona"),
        experience: [
            job("impiegata amministrativa", "Ferramenta Scaligera", from: "2017"),
            job("", "Studio Contabile Merlini", from: "2013", to: "2017"),
        ]
    )

    private static func itTraps() throws -> String {
        try #require(DraftingInputs.written.first { $0.id == "it-traps" }).description
    }

    @Test("A clause names work by a word that is none of working, starting, a name, a place or a time: one that only says where the person worked names none (#354, round 11)", arguments: [
        ("je pétris le pain au Fournil Delaunay", true),
        ("Dal 2017 lavoro alla Ferramenta Scaligera, dove gestisco le fatture dei fornitori.", true),
        ("Prima, dal 2013 al 2017, ho lavorato allo Studio Contabile Merlini.", false),
        ("From 2013 to 2016 I worked at the Fenwick Playhouse.", false),
        ("I started in 2013 at the Fenwick Playhouse.", false),
        ("Seit 2018 arbeite ich bei Kranz in Erfurt.", false),
    ])
    func clauseNamesWork(clause: String, names: Bool) {
        let named = ["Fournil Delaunay", "Ferramenta Scaligera", "Studio Contabile Merlini", "Fenwick Playhouse", "Kranz", "Erfurt"]
        #expect(CVDataSanitizer.namesWork(clause, names: named) == names)
    }

    @Test("A written duty that only says where the person worked goes, with its reason; a task of the job stays (#354, round 11)")
    func dutyThatOnlySaysWhere() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.itTrapsJobs, job: 1, duties: "Ho lavorato allo Studio Contabile Merlini. Archiviavo le pratiche dei clienti.",
            against: try Self.itTraps()
        )

        #expect(verdicts.kept == ["Archiviavo le pratiche dei clienti."])
        #expect(verdicts.rejected.map(\.sentence) == ["Ho lavorato allo Studio Contabile Merlini."])
        #expect(verdicts.rejected.map(\.reason) == [CVDataSanitizer.onlyWhereReason])
    }

    @Test("A written duty that names its task only through a vague phrase goes, with its reason; one that names the task stays (#354, round 11)")
    func vagueDuty() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.itTrapsJobs, job: 0,
            duties: "Ho svolto compiti legati alla gestione dei documenti. Gestisco l'archivio dei documenti dei clienti.",
            against: try Self.itTraps()
        )

        #expect(verdicts.kept == ["Gestisco l'archivio dei documenti dei clienti."])
        #expect(verdicts.rejected.map(\.sentence) == ["Ho svolto compiti legati alla gestione dei documenti."])
        #expect(verdicts.rejected.first?.reason.contains("name the task itself") == true)
    }

    @Test("The vague phrases of a duty, in the six languages; a duty that names its task has none (#354, round 11)", arguments: [
        ("Ho svolto compiti legati alla gestione dei documenti.", true),
        ("Seguivo attività relative alla contabilità.", true),
        ("I handled tasks related to the archive.", true),
        ("I carried out duties related to payroll.", true),
        ("Realizaba tareas relacionadas con la contabilidad.", true),
        ("J'effectuais des tâches liées à la comptabilité.", true),
        ("Ich übernahm Aufgaben im Bereich der Buchhaltung.", true),
        ("Realizava tarefas relacionadas com a contabilidade.", true),
        ("Gestisco l'archivio dei documenti dei clienti.", false),
        ("I sort the tasks of the day by urgency.", false),
    ])
    func vaguePhrase(duty: String, vague: Bool) {
        #expect(CVDataSanitizer.isVague(duty) == vague)
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

    #if canImport(NaturalLanguage)
    // The French clauses are read with the device's language data, which only an Apple platform has.
    @Test("The step that writes a job pins the duties the final check pins: an achievement of the job counts toward neither (#354, round 3)")
    func stepPinsAsTheFinalCheck() throws {
        let description = try DraftingInputs.exampleText(in: "fr")
        let cv = CVData(experience: [
            Experience(title: "assistante", company: "crèche", startDate: "2012", endDate: "2016"),
            Experience(
                title: "institutrice", company: "école Don Milani", startDate: "2016", current: true,
                achievements: ["j'ai formé 3 nouveaux enseignants"]
            ),
        ])
        let french = CVDataSanitizer(languageOfText: { _ in "fr" })

        let step = try french.dutyCheck(of: cv, job: 1, duties: "J'ai formé trois nouveaux enseignants. J'enseigne à l'école Don Milani.", against: description)
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, step.kept.joined(separator: " ")], technologies: [], softSkills: [])
        let final = try french.sanitize(cv, writing: writing, against: description).experience
            .first { $0.company == "école Don Milani" }?.description ?? ""

        #expect(step.pinned.allSatisfy { final.contains($0) }, "step \(step.pinned), final \(final)")
        #expect(!step.saysEnough || final.count >= CVDataSanitizer.DutyVerdicts.describedLength, "final \(final)")
    }

    @Test("A count the person gave in digits that a duty writes in words stays, in digits, in the step and the final check; another count goes (#354, round 6)",
          arguments: [
              ("J'ai formé quatre stagiaires.", "J'ai formé 4 stagiaires.", nil),
              ("J'ai formé cinq stagiaires.", nil, "the word \"cinq\" is a number"),
          ] as [(String, String?, String?)])
    func countInWords(duty: String, kept: String?, reason: String?) throws {
        let description = """
            Depuis 2018, je travaille comme bibliothécaire à la médiathèque de Rouen, où j'ai formé 4 stagiaires. \
            Avant, de 2014 à 2018, j'ai travaillé comme libraire dans une librairie.
            """
        let cv = CVData(experience: [
            Experience(title: "libraire", company: "librairie", startDate: "2014", endDate: "2018"),
            Experience(
                title: "bibliothécaire", company: "médiathèque de Rouen", startDate: "2018", current: true,
                achievements: ["j'ai formé 4 stagiaires"]
            ),
        ])
        let french = CVDataSanitizer(languageOfText: { _ in "fr" })

        let step = try french.dutyCheck(of: cv, job: 1, duties: duty, against: description)
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, step.kept.joined(separator: " ")], technologies: [], softSkills: [])
        let final = try french.sanitize(cv, writing: writing, against: description).experience
            .first { $0.company == "médiathèque de Rouen" }?.description ?? ""

        #expect(step.kept == (kept.map { [$0] } ?? []), "\(step.rejected)")
        #expect(step.rejected.map(\.reason) == (reason.map { [$0] } ?? []))
        #expect(kept.map(final.contains) ?? true, "final \(final)")
    }
    #endif

    @Test("A job's plain stated duties of 40 characters are pinned by the step and kept by the final check alike (#354, round 3)")
    func plainDutiesPinnedAlike() throws {
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, nil, nil, nil], technologies: [], softSkills: [])

        let step = try sanitizer.dutyCheck(of: Self.italianJobs, job: 1, duties: nil, against: JobClausesTests.italian)
        let final = try sanitizer.sanitize(Self.italianJobs, writing: writing, against: JobClausesTests.italian)

        #expect(step.saysEnough)
        #expect(step.pinned.allSatisfy { duty in final.experience.contains { ($0.description ?? "").contains(duty) } })
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

    @Test("A written duty about the object of an earlier one, qualified another way, goes; one that shares only a plain word stays (#354, round 10)")
    func dutyAboutAnEarlierObject() throws {
        let again = try sanitizer.dutyCheck(
            of: Self.clerkJob, job: 0,
            duties: "Registravo le scadenze fiscali dei clienti. Aggiornavo il calendario delle scadenze tributarie.", against: Self.clerk
        )
        let other = try sanitizer.dutyCheck(
            of: Self.clerkJob, job: 0,
            duties: "Registravo le fatture dei clienti. Sollecitavo i pagamenti dei clienti.", against: Self.clerk
        )

        #expect(again.kept == ["Registravo le scadenze fiscali dei clienti."])
        #expect(again.rejected.map(\.reason) == [CVDataSanitizer.namesAgainReason])
        #expect(other.kept == ["Registravo le fatture dei clienti.", "Sollecitavo i pagamenti dei clienti."])
    }

    @Test("The object of a duty is qualified after it in the Romance languages and before it in English and German (#354, round 10)",
          arguments: [
              ("I answer formal correspondence.", "I sort the official correspondence.", .english, true),
              ("I repair the electrical sockets.", "I check the electrical panels.", .english, false),
              ("Ich plane die täglichen Lieferungen.", "Ich prüfe die eingehenden Lieferungen.", .german, true),
              ("Tramito los expedientes urgentes.", "Archivo los expedientes cerrados.", .spanish, true),
              ("Tramito los expedientes urgentes.", "Archivo las facturas de los proveedores.", .spanish, false),
          ] as [(String, String, Vocabulary.Language, Bool)])
    func objectOfADuty(sentence: String, earlier: String, language: Vocabulary.Language, isAgain: Bool) {
        #expect(CVDataSanitizer.namesAgain(sentence, earlier, language: language) == isAgain)
    }

    @Test("A duty that starts with an infinitive in -ere or -ire goes, also as the job's first one; one in -are is written in the first person and stays, as does a duty in the first person (#354, round 10)")
    func infinitiveDuty() throws {
        let verdicts = try sanitizer.dutyCheck(
            of: Self.clerkJob, job: 0, duties: "Ricevere le fatture dei clienti. Controllavo i pagamenti dei fornitori.",
            against: Self.clerk
        )
        let written = try sanitizer.dutyCheck(
            of: Self.clerkJob, job: 0, duties: "Registrare le fatture dei clienti. Controllavo i pagamenti dei fornitori.",
            against: Self.clerk
        )

        #expect(verdicts.kept == ["Controllavo i pagamenti dei fornitori."])
        #expect(verdicts.rejected.map(\.sentence) == ["Ricevere le fatture dei clienti."])
        #expect(verdicts.rejected.first?.reason.hasPrefix("it starts with an infinitive") == true)
        #expect(written.kept == ["Registravo le fatture dei clienti.", "Controllavo i pagamenti dei fornitori."])
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

    // MARK: The duties said with no job (ADR 0031, D7)

    /// Two jobs, the later current, and what the person says with no job after them (ADR 0031, D7).
    private static let fitter = "Dal 2009 al 2015 ho lavorato come magazziniere alla Ditta Ponzio. Dal 2015 sono frigorista alla Gelateria Morandi."
    private static let fitterJobs = CVData(experience: [
        job("magazziniere", "Ditta Ponzio", from: "2009", to: "2015"), job("frigorista", "Gelateria Morandi", from: "2015"),
    ])

    @Test(
        "ADR 0031, D7: a sentence of what the person does is a duty in each language; one of what the person knows is none",
        arguments: [
            ("Ich verlege die Wärmepumpen und prüfe die Kältekreise.", Vocabulary.Language.german, true),
            ("Ich kenne mich mit Wärmepumpen aus.", .german, false),
            ("Je règle les compresseurs.", .french, true),
            ("Je connais bien les compresseurs.", .french, false),
            ("Reviso los compresores.", .spanish, true),
            ("Conozco bien los compresores.", .spanish, false),
            ("Reviso os compressores.", .portuguese, true),
            ("Conheço bem os compressores.", .portuguese, false),
        ]
    )
    func generalDutyIsNoKnowledge(sentence: String, language: Vocabulary.Language, holds: Bool) {
        #expect(GeneralDuty.holds(sentence, language: language) == holds)
    }

    @Test(
        "ADR 0031, D7: a present sentence of work with no job is a duty of the current job, in the step and the final check alike; one in the past, a quality, a pastime, a knowledge and one that names another employer are none",
        arguments: [
            ("Taro le valvole e smonto i riduttori delle linee.", true),
            ("Taravo le valvole e smontavo i riduttori delle linee.", false),
            ("Sono paziente e mi piace lavorare in gruppo.", false),
            ("Gioco a calcetto con gli amici.", false),
            ("Taro le valvole per la Ditta Ponzio.", false),
            ("Conosco bene le celle frigorifere e i compressori.", false),
        ]
    )
    func generalDutyOfTheCurrentJob(sentence: String, moves: Bool) throws {
        let description = Self.fitter + " " + sentence
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, nil], technologies: [], softSkills: [])

        let current = try sanitizer.dutyCheck(of: Self.fitterJobs, job: 1, duties: nil, against: description)
        let ended = try sanitizer.dutyCheck(of: Self.fitterJobs, job: 0, duties: nil, against: description)
        let final = try sanitizer.sanitize(Self.fitterJobs, writing: writing, against: description).experience
        let opening = String(sentence.prefix { $0 != " " })

        let currentText = final.first { $0.company == "Gelateria Morandi" }?.description ?? ""
        let endedText = final.first { $0.company == "Ditta Ponzio" }?.description ?? ""

        #expect(current.pinned.contains(sentence) == moves, "pinned \(current.pinned)")
        #expect(!ended.pinned.contains { $0.contains(opening) }, "pinned \(ended.pinned)")
        #expect(currentText.contains(sentence) == moves, "final \(final)")
        #expect(!endedText.contains(opening), "final \(final)")
    }

    @Test("ADR 0031, D7: with two current jobs, a present sentence of work with no job is a duty of neither")
    func generalDutyOfTwoCurrentJobs() throws {
        let description = "Dal 2009 sono magazziniere alla Ditta Ponzio. Dal 2015 sono frigorista alla Gelateria Morandi. "
            + "Taro le valvole e smonto i riduttori delle linee."
        let jobs = CVData(experience: [Self.job("magazziniere", "Ditta Ponzio", from: "2009"), Self.job("frigorista", "Gelateria Morandi", from: "2015")])
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, nil], technologies: [], softSkills: [])

        let final = try sanitizer.sanitize(jobs, writing: writing, against: description).experience

        #expect(!final.contains { ($0.description ?? "").contains("Taro") }, "final \(final)")
    }

    #if canImport(NaturalLanguage)
    // English verbs are read with the device's language data, which only an Apple platform has.
    @Test(
        "ADR 0031, D7: in English too, a present sentence of work with no job is a duty of the current job; one in the past, a pastime and a knowledge are none",
        arguments: [
            ("I rebuild the carburettors and tune the fuel pumps.", true),
            ("I rebuilt the carburettors and tuned the fuel pumps.", false),
            ("I play football.", false),
            ("I know the marine diesel engines well.", false),
        ]
    )
    func generalDutyInEnglish(sentence: String, moves: Bool) throws {
        let description = "From 2012 to 2019 I was a deckhand at Pelican Ferries. Since 2019 I have been a boat mechanic at Gullwing Marina. "
            + sentence
        let jobs = CVData(experience: [
            Self.job("deckhand", "Pelican Ferries", from: "2012", to: "2019"), Self.job("boat mechanic", "Gullwing Marina", from: "2019"),
        ])
        let english = CVDataSanitizer(languageOfText: { _ in "en" })
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, nil], technologies: [], softSkills: [])

        let final = try english.sanitize(jobs, writing: writing, against: description).experience

        let currentText = final.first { $0.company == "Gullwing Marina" }?.description ?? ""
        let endedText = final.first { $0.company == "Pelican Ferries" }?.description ?? ""

        #expect(currentText.contains(sentence) == moves, "final \(final)")
        #expect(!endedText.contains("carburettors"), "final \(final)")
    }
    #endif

    @Test("ADR 0031, D7: the current job is the only one with no end date, or the one with the latest end year; two open jobs, a tie or an undated job give none")
    func currentJobOfTheGeneralDuties() {
        let ended = { (end: String) in Self.job("tecnico", "Officina Breda", from: "2001", to: end) }
        let open = Self.job("tecnico", "Officina Breda", from: "2001")

        #expect(CVDataSanitizer.generalDutyJob(among: [ended("2010"), open, ended("2015")]) == 1)
        #expect(CVDataSanitizer.generalDutyJob(among: [open, ended("2015"), open]) == nil)
        #expect(CVDataSanitizer.generalDutyJob(among: [Experience(title: "tecnico", company: "Officina Breda"), open]) == nil)
        #expect(CVDataSanitizer.generalDutyJob(among: [ended("2010"), ended("marzo 2019"), ended("2015")]) == 1)
        #expect(CVDataSanitizer.generalDutyJob(among: [ended("2019"), ended("2015"), ended("2019")]) == nil)
    }

    // MARK: The title of the current job from the person's own (ADR 0031, D9)

    @Test(
        "ADR 0031, D9: the person's own title said in the present fills the blank title of the current job; an ended job, two current jobs, a title said in the past and a title already found give nothing",
        arguments: [
            ("Mi chiamo Maria Rossi e sono impiegata amministrativa a Lecco. Dal 2013 al 2018 ho lavorato alla Ferramenta Brivio. "
                + "Dal 2018 lavoro allo Studio Valsecchi, dove tengo la prima nota.", "", "Studio Valsecchi", "impiegata amministrativa"),
            ("Mi chiamo Maria Rossi e sono impiegata amministrativa a Lecco. Dal 2013 lavoro alla Ferramenta Brivio. "
                + "Dal 2018 lavoro anche allo Studio Valsecchi, dove tengo la prima nota.", "", "Studio Valsecchi", ""),
            ("Mi chiamo Maria Rossi. Ero impiegata amministrativa a Lecco. Dal 2013 al 2018 ho lavorato alla Ferramenta Brivio. "
                + "Dal 2018 lavoro allo Studio Valsecchi, dove tengo la prima nota.", "", "Studio Valsecchi", ""),
            ("Mi chiamo Maria Rossi e sono impiegata amministrativa a Lecco. Dal 2013 al 2018 ho lavorato alla Ferramenta Brivio. "
                + "Dal 2018 lavoro come contabile allo Studio Valsecchi.", "contabile", "Studio Valsecchi", "contabile"),
        ]
    )
    func currentTitleFromTheOwnTitle(description: String, title: String, employer: String, kept: String) throws {
        let ongoing = description.contains("Dal 2013 lavoro")
        let facts = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi", title: "impiegata amministrativa"),
            experience: [Self.job("", "Ferramenta Brivio", from: "2013", to: ongoing ? nil : "2018"), Self.job(title, employer, from: "2018")]
        )
        let writing = DraftWriting(summary: nil, roleDescriptions: [nil, nil], technologies: [], softSkills: [])

        let final = try sanitizer.sanitize(facts, writing: writing, against: description).experience

        #expect(final.first { $0.company == employer }?.title == kept, "final \(final)")
        #expect(final.first { $0.company == "Ferramenta Brivio" }?.title == "", "final \(final)")
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

    @Test("A quality listed as a tool is a soft skill, and a tool named by what it does stays, even when the tagger reads its first word as a verb (#354, round 5)")
    func skillsCleaned() {
        let tagging = Self.italian(ForcedLexicalTagger([.italian: .words(["software"])]), wordList: TableWordList())
        let description = "Dal 2020 lavoro al Birrificio Valtrigno, dove uso i PLC e gestisco i fermi impianto."

        let verdict = tagging.skillCheck(
            technologies: ["PLC", "precisione", "software di gestione fermi", "PLC"], softSkills: ["lavoro di squadra"], against: description
        )

        #expect(verdict.technologies == ["PLC", "software di gestione fermi"])
        #expect(verdict.softSkills == ["precisione", "lavoro di squadra"])
        #expect(verdict.dropped.isEmpty)
    }

    @Test("In Italian, a word of English that ends in a consonant goes though the device's dictionary knows it; a loanword Italian writes as its own, a product and an Italian word stay (#354, round 3)")
    func englishWordInItalian() {
        let bothLanguages = Self.italian(ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = bothLanguages.skillCheck(
            technologies: ["plotter", "stampante", "Excel", "folder", "registratore di cassa", "drawing board"], softSkills: ["problem solving"],
            against: JobClausesTests.italian
        )

        #expect(verdict.technologies == ["plotter", "stampante", "Excel", "registratore di cassa"])
        #expect(verdict.softSkills == ["problem solving"])
        #expect(verdict.dropped.map(\.sentence) == ["folder", "drawing board"])
        #expect(Set(verdict.dropped.map(\.reason)) == ["another language"])
    }

    @Test("A part or a material the person installs goes from the technologies; a tool named after one, and one to measure with, stay (#354, round 3)")
    func partIsNoTool() {
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = german.skillCheck(
            technologies: ["Rohre", "Rohrschneider", "Pressmaschine", "Rohrzange", "Druckprüfgerät", "Dübel"], softSkills: [],
            against: "Seit 2020 bin ich Installateur bei Wasserwerk Lindtal, wo ich Rohre in Altbauten verlege."
        )

        #expect(verdict.technologies == ["Rohrschneider", "Pressmaschine", "Rohrzange", "Druckprüfgerät"])
        #expect(verdict.dropped.map(\.sentence) == ["Rohre", "Dübel"])
        #expect(Set(verdict.dropped.map(\.reason)) == ["a part or a material, not a tool"])
    }

    @Test("Stationery, furniture or protective wear goes from the technologies in each language; a tool of the trade stays (#354, round 4)")
    func everydayObjectIsNoTool() {
        let rows: [(language: String, technologies: [String], kept: [String], description: String)] = [
            ("fr", ["tableau noir", "tableau numérique", "stylo", "vidéoprojecteur", "cahiers"], ["tableau numérique", "vidéoprojecteur"],
             "Depuis 2019, je suis institutrice à l'école Les Tilleuls, où j'enseigne en classe de CM1."),
            ("en", ["ballpoint pen", "label printer", "office chair", "barcode scanner", "safety gloves"], ["label printer", "barcode scanner"],
             "Since 2021 I run the dispatch bay at Harrowgate Freight."),
            ("it", ["penna", "multimetro", "casco di protezione", "termocamera"], ["multimetro", "termocamera"],
             "Dal 2018 sono manutentore alle Officine Brenta, dove riparo le linee."),
            ("es", ["bolígrafo", "Excel", "archivador", "ContaPlus"], ["Excel", "ContaPlus"],
             "Desde 2017 soy contable en Almacenes Turia y cierro las cuentas del mes."),
            ("pt", ["caneta", "Visual Studio Code", "cadeira", "Git"], ["Visual Studio Code", "Git"],
             "Desde 2020 sou programador na Ribeira Digital, onde crio aplicações."),
            ("de", ["Kugelschreiber", "Abisolierzange", "Schutzhandschuhe", "Spannungsprüfer"], ["Abisolierzange", "Spannungsprüfer"],
             "Seit 2016 bin ich Elektriker bei Elektro Saalfeld und verlege Leitungen in Neubauten."),
        ]
        for row in rows {
            let language = row.language
            // The tagger tags no verb: the device's differs by macOS, and the row is not about verbs.
            let tagger = ForcedLexicalTagger(Vocabulary.Language(tag: language).map { [$0: .words([])] } ?? [:])
            let sanitizer = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: tagger, wordList: TableWordList())

            let verdict = sanitizer.skillCheck(technologies: row.technologies, softSkills: [], against: row.description)

            #expect(verdict.technologies == row.kept, "\(language)")
            #expect(verdict.dropped.map(\.sentence) == row.technologies.filter { !row.kept.contains($0) }, "\(language)")
            #expect(Set(verdict.dropped.map(\.reason)) == ["an everyday object, not a tool of the trade"], "\(language)")
        }
    }

    @Test("Stationery named with a word after or before its noun goes as an everyday object; a board or a pen that is a device stays (#354, round 6)",
          arguments: [
              ("fr", "cahiers de brouillon", "tableau interactif", "Depuis 2019, je suis institutrice à l'école Les Tilleuls, où j'enseigne en classe de CM1."),
              ("it", "quaderni di lavoro", "lavagna interattiva", "Dal 2018 insegno alla scuola Collodi di Prato, dove preparo le lezioni."),
              ("es", "cuadernos de ejercicios", "lápiz óptico", "Desde 2017 soy profesora en el colegio Turia y preparo las clases."),
              ("pt", "cadernos de atividades", "quadro interativo", "Desde 2020 sou professora na escola Ribeira, onde preparo as aulas."),
              ("de", "rote Stifte", "digitale Tafel", "Seit 2016 bin ich Lehrerin an der Grundschule Saalfeld und bereite den Unterricht vor."),
              ("en", "gel pens", "digital pens", "Since 2021 I run the dispatch bay at Harrowgate Freight."),
          ] as [(String, String, String, String)])
    func stationeryWithAWordIsNoTool(language: String, stationery: String, tool: String, description: String) {
        // The tagger tags no verb: the device's differs by macOS, and the row is not about verbs.
        let tagger = ForcedLexicalTagger(Vocabulary.Language(tag: language).map { [$0: .words([])] } ?? [:])
        let sanitizer = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: tagger, wordList: TableWordList())

        let verdict = sanitizer.skillCheck(technologies: [stationery, tool], softSkills: [], against: description)

        #expect(verdict.technologies == [tool])
        #expect(verdict.dropped.map(\.sentence) == [stationery])
        #expect(verdict.dropped.map(\.reason) == ["an everyday object, not a tool of the trade"])
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

    @Test("A written technology of the kind of a tool the person names goes, a console, a mixer and a desk one kind; a tool of another kind stays (#354, round 2)")
    func toolOfAStatedKind() {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = english.skillCheck(
            technologies: ["audio mixing console", "sound mixer", "studio monitors", "line array systems", "digital mixing desk"],
            softSkills: [], stated: ["digital consoles", "PA systems"], against: "I mix on digital consoles and set up the PA systems in Hull."
        )

        #expect(verdict.technologies == ["studio monitors"])
        #expect(Set(verdict.dropped.map(\.reason)) == ["same kind as an earlier tool"])
    }

    @Test("A one-word technology clipped from a phrase of two joined by a conjunction is joined back; two tools joined by one stay apart (#354, round 5)",
          arguments: [
              // What the person works with: what the work is done on is no tool (round 7).
              ("it", "Lavoro con schemi elettrici e pneumatici e programmo PLC e HMI.", ["PLC", "schemi elettrici", "pneumatici", "HMI"],
               ["PLC", "schemi elettrici e pneumatici", "HMI"]),
              ("en", "I work with hydraulic and pneumatic valves and use PLC and HMI panels.", ["hydraulic", "pneumatic valves", "PLC", "HMI panels"],
               ["hydraulic and pneumatic valves", "PLC", "HMI panels"]),
          ])
    func clippedModifierJoined(language: String, description: String, technologies: [String], kept: [String]) {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = checker.skillCheck(technologies: technologies, softSkills: [], against: description)

        #expect(verdict.technologies == kept)
        #expect(verdict.dropped.isEmpty)
    }

    @Test("A technology that names an activity goes; equipment, a kind of tool named by what it does, a named tool and one with an acronym stay (#354, rounds 1 and 5)")
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

        let french = CVDataSanitizer(languageOfText: { _ in "fr" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let school = french.skillCheck(
            technologies: ["logiciel de gestion de classe", "correction des copies", "tableau numérique"],
            softSkills: [], against: "J'enseigne dans une petite école de village près de Rodez."
        )

        #expect(sound.technologies == ["digital consoles", "PA systems", "tracking software", "PLC programming", "line arrays", "docking station"])
        #expect(sound.dropped.map(\.sentence) == ["frequency calibration", "signal routing", "beam focusing"])
        #expect(Set(sound.dropped.map(\.reason)) == ["activity"])
        #expect(plant.technologies == ["PLC", "software di tracciamento", "sistema di controllo remoto", "stazione di saldatura", "multimetro", "programmazione PLC"])
        #expect(plant.dropped.map(\.sentence) == ["manutenzione preventiva"])
        #expect(school.technologies == ["logiciel de gestion de classe", "tableau numérique"])
        #expect(school.dropped.map(\.sentence) == ["correction des copies"])
    }

    @Test("A tool that holds a word of the employer's name goes, unless the person writes it whole; one of a name the CV does not hold stays (#354, round 7)")
    func toolNamedAfterTheEmployer() {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let description = "I drive a reach truck at Kestrel Logistics in Hull and use the SAP Kestrel module for the stock."

        let named = english.skillCheck(
            technologies: ["Kestrel forklift", "SAP Kestrel module", "reach truck"], softSkills: [], stated: [],
            names: ["Kestrel Logistics", "Dana Whitcombe"], against: description
        )
        let unnamed = english.skillCheck(
            technologies: ["Kestrel forklift", "reach truck"], softSkills: [], stated: [], names: [], against: description
        )

        #expect(named.technologies == ["SAP Kestrel module", "reach truck"])
        #expect(named.dropped.map(\.reason) == ["a word of a name"])
        #expect(unnamed.technologies == ["Kestrel forklift", "reach truck"])
    }

    @Test("A tool that is, by its head noun, what the person's work is done on goes; what the person uses stays (#354, round 7)")
    func toolThatIsAWorkObject() {
        let description = "Controllo i quadri elettrici e riparo i nastri trasportatori. Uso i PLC e il multimetro per trovare i guasti."
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = sanitizer.skillCheck(
            technologies: ["quadri elettrici", "PLC", "nastri trasportatori", "multimetro"], softSkills: [], against: description
        )
        let stated = sanitizer.skillCheck(
            technologies: ["quadro elettrico"], softSkills: [], stated: ["quadri elettrici"], against: description
        )
        let driven = english.skillCheck(
            technologies: ["forklift", "pallet jack", "loading dock"], softSkills: [],
            against: "I work with forklifts and a pallet jack, and I clean the loading docks."
        )

        #expect(verdict.technologies == ["PLC", "multimetro"])
        #expect(verdict.dropped.map(\.reason) == ["what the work is done on", "what the work is done on"])
        #expect(stated.dropped.map(\.reason) != ["what the work is done on"])
        #expect(driven.technologies == ["forklift", "pallet jack"])
        #expect(driven.dropped.map(\.reason) == ["what the work is done on"])
    }

    @Test("An application of a trade is a tool, though its noun ends as an activity's does; the activity of that trade goes (#354, round 7)")
    func applicationIsNoActivity() {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let spanish = CVDataSanitizer(languageOfText: { _ in "es" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let portuguese = CVDataSanitizer(languageOfText: { _ in "pt" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let office = sanitizer.skillCheck(
            technologies: ["applicazione di contabilità", "riparazione delle stampanti"], softSkills: [],
            against: "Lavoro come impiegata amministrativa a Bari dal 2018."
        )
        let shop = english.skillCheck(
            technologies: ["stock tracking application", "stock reconciliation"], softSkills: [],
            against: "I run the stockroom of a hardware shop in Leeds."
        )
        let clinic = spanish.skillCheck(
            technologies: ["aplicaciones de facturación", "reparación de equipos"], softSkills: [],
            against: "Trabajo en la recepción de una clínica dental en Murcia."
        )
        let store = portuguese.skillCheck(
            technologies: ["aplicação de inventário", "programação de entregas"], softSkills: [],
            against: "Trabalho no armazém de uma loja em Braga."
        )

        #expect(office.technologies == ["applicazione di contabilità"])
        #expect(office.dropped.map(\.reason) == ["activity"])
        #expect(shop.technologies == ["stock tracking application"])
        #expect(shop.dropped.map(\.reason) == ["activity"])
        #expect(clinic.technologies == ["aplicaciones de facturación"])
        #expect(clinic.dropped.map(\.reason) == ["activity"])
        #expect(store.technologies == ["aplicação de inventário"])
        #expect(store.dropped.map(\.reason) == ["activity"])
    }

    @Test("A record or a document alone, or its scan, goes; a record named with its system or device stays (#354, round 8)",
          arguments: [
              ("es", ["Escaneo", "Registros", "escaneo de albaranes", "lector de albaranes"], ["lector de albaranes"]),
              ("it", ["Documenti", "archivio", "registro elettronico", "archivio digitale", "scanner piano"],
               ["registro elettronico", "archivio digitale", "scanner piano"]),
              ("en", ["paperwork", "records", "document scanner", "QuickBooks"], ["document scanner", "QuickBooks"]),
              ("fr", ["registres", "dossiers", "logiciel de paie"], ["logiciel de paie"]),
              ("pt", ["Documentos", "auditoria", "relógio de ponto"], ["relógio de ponto"]),
              ("de", ["Unterlagen", "Dokumentenscanner", "Register"], ["Dokumentenscanner"]),
          ])
    func recordIsNoTechnology(language: String, technologies: [String], kept: [String]) throws {
        // The device's tagger read "escaneo" as a verb on one host and not on another; this row reads the record rule alone.
        let language = try #require(Vocabulary.Language(rawValue: language))
        let checker = CVDataSanitizer(
            languageOfText: { _ in language.rawValue }, lexicalClasses: ForcedLexicalTagger([language: .noAssets]), wordList: TableWordList()
        )

        let verdict = checker.skillCheck(technologies: technologies, softSkills: [], against: "Lavoro a Lecce dal 2019.")

        #expect(verdict.technologies == kept)
        #expect(Set(verdict.dropped.map(\.reason)) == ["a record or a document, not a tool"])
        #expect(verdict.dropped.count == technologies.count - kept.count)
    }

    @Test("A bare kind of tool goes; a kind with a word of its trade stays, as does a named one, with a capital, an acronym or a digit (#354, rounds 2 and 4)",
          arguments: [
              ("en", ["Pro Tools", "software", "sound design software", "Logic Pro 11", "stage monitors"],
               ["Pro Tools", "sound design software", "Logic Pro 11", "stage monitors"]),
              ("it", ["software", "software CMMS", "piattaforma di stampa", "multimetro"], ["software CMMS", "piattaforma di stampa", "multimetro"]),
              ("es", ["editor", "editor de código", "Visual Studio Code", "hoja de cálculo"],
               ["editor de código", "Visual Studio Code", "hoja de cálculo"]),
              ("pt", ["ferramenta", "ferramenta de teste", "Postman", "aplicativos Android"],
               ["ferramenta de teste", "Postman", "aplicativos Android"]),
          ])
    func kindOfToolIsNoTechnology(language: String, technologies: [String], kept: [String]) {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = checker.skillCheck(technologies: technologies, softSkills: [], against: "Lavoro a Lecce dal 2019.")

        #expect(verdict.technologies == kept)
        #expect(verdict.dropped.map(\.reason) == ["a kind of tool, not its name"])
    }

    @Test("A lone machine, system or piece of equipment, and a kind whose only other word is generic, go; with a word of its trade, a name or an acronym it stays (#354, round 5)",
          arguments: [
              ("de", ["Maschine", "Steuerungssystem", "Drehmaschine", "Gerät"], ["Steuerungssystem", "Drehmaschine"]),
              ("it", ["macchina", "sistema di controllo remoto", "attrezzatura", "macchina da cucire"], ["sistema di controllo remoto", "macchina da cucire"]),
              ("fr", ["machine", "système", "machine à coudre", "logiciel de gestion de classe"], ["machine à coudre", "logiciel de gestion de classe"]),
              ("en", ["system", "equipment", "PA systems", "text editor", "lighting desk"], ["PA systems", "lighting desk"]),
              ("pt", ["editor de texto", "plataforma de desenvolvimento", "editor de código", "máquina de solda"], ["editor de código", "máquina de solda"]),
              ("es", ["equipo", "máquina", "software de datos", "software de contabilidad"], ["software de contabilidad"]),
          ])
    func genericKindIsNoTechnology(language: String, technologies: [String], kept: [String]) {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = checker.skillCheck(technologies: technologies, softSkills: [], against: "Lavoro a Lecce dal 2019.")

        #expect(verdict.technologies == kept)
        #expect(Set(verdict.dropped.map(\.reason)) == ["a kind of tool, not its name"])
        #expect(verdict.dropped.count == technologies.count - kept.count)
    }

    @Test("A kind of tool with a word of its trade stays though the CV lists enough tools; a bare kind goes (#354, round 4)")
    func tradeKindStays() {
        // No word tagged a verb: the device's tagger reads "teodolite" as a verb on one macOS and not on another.
        let checker = CVDataSanitizer(
            languageOfText: { _ in "it" }, lexicalClasses: ForcedLexicalTagger([.italian: .words([])]), wordList: TableWordList()
        )

        let verdict = checker.skillCheck(
            technologies: ["software", "software di rilievo", "teodolite", "stazione totale", "GPS RTK"], softSkills: [],
            against: "Lavoro a Lecce dal 2019."
        )

        #expect(verdict.technologies == ["software di rilievo", "teodolite", "stazione totale", "GPS RTK"])
        #expect(verdict.dropped.map(\.sentence) == ["software"])
    }

    @Test("A German technology that is the infinitive of an activity goes; a machine stays (#354, round 2)")
    func germanActivityIsNoTechnology() {
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = german.skillCheck(
            technologies: ["Messen", "Drehmaschine", "Installieren", "Multimeter", "Abisolierzange"], softSkills: [],
            against: "Feinmechanik, Suhl, 2019."
        )

        #expect(verdict.technologies == ["Drehmaschine", "Multimeter", "Abisolierzange"])
        #expect(verdict.dropped.map(\.reason) == ["activity", "activity"])
    }

    @Test("A fragment and a lone verb go from the skills")
    func fragmentsGo() {
        let verdict = sanitizer.skillCheck(
            technologies: [
                "manutenzione di", "uso dei PLC: base", "controllo quadri elettrici clienti ditta", "gestione di un registro di classe",
            ],
            softSkills: [], against: JobClausesTests.italian
        )

        #expect(verdict.technologies.isEmpty)
        #expect(verdict.dropped.map(\.reason) == ["fragment", "fragment", "fragment", "fragment"])
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

    @Test("A word for knowledge goes from the soft skills; a quality said with it stays (#354, round 2)")
    func knowledgeIsNoQuality() {
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdict = german.skillCheck(
            technologies: [], softSkills: ["Wissen", "Verständnis", "Sorgfalt", "Fachwissen", "Verständnis für Kunden"],
            against: "Feinmechanik, Suhl, 2019."
        )

        #expect(verdict.softSkills == ["Sorgfalt", "Verständnis für Kunden"])
        #expect(verdict.dropped.map(\.reason) == ["a word for a skill", "a word for a skill", "a word for a skill"])
    }

    @Test("A soft skill that only says the person is a professional or has experience goes; a quality, and one said with that word, stay (#354, round 3)")
    func emptyWordIsNoQuality() {
        let verdict = sanitizer.skillCheck(
            technologies: [],
            softSkills: ["professionale", "puntualità", "competente", "esperienza", "atteggiamento professionale", "pazienza"],
            against: JobClausesTests.italian
        )

        #expect(verdict.softSkills == ["puntualità", "atteggiamento professionale", "pazienza"])
        #expect(verdict.dropped.map(\.reason) == ["an empty word, not a quality", "an empty word, not a quality", "an empty word, not a quality"])
    }

    @Test("Of two soft skills of one quality, care or teamwork, the second goes; qualities of other kinds stay (#354, round 2)")
    func oneQualityOnce() {
        let verdict = sanitizer.skillCheck(
            technologies: [],
            softSkills: ["precisione", "lavoro di squadra", "attenzione ai dettagli", "affidabilità", "collaborazione", "calma"],
            against: JobClausesTests.italian
        )

        #expect(verdict.softSkills == ["precisione", "lavoro di squadra", "affidabilità", "calma"])
        #expect(verdict.dropped.map(\.sentence) == ["attenzione ai dettagli", "collaborazione"])
        #expect(Set(verdict.dropped.map(\.reason)) == ["the same quality as an earlier one"])
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

    @Test("A one-word English soft skill in -ed is an adjective and stays; another verb goes (#354, round 2)")
    func edAdjectiveStays() {
        let english = CVDataSanitizer(
            languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([.english: .words(["organized", "motivate"])]),
            wordList: TableWordList()
        )

        let verdict = english.skillCheck(
            technologies: [], softSkills: ["organized", "motivate"], against: "I mix the sound for a small theatre in Hull."
        )

        #expect(verdict.softSkills == ["organized"])
        #expect(verdict.dropped.map(\.reason) == ["verb"])
    }

    @Test("A soft skill the description writes only as a name goes; the same word said as a quality stays (#354, round 2)",
          arguments: [
              ("Mi chiamo Serena Gallo e lavoro a Lecce. Scrivetemi a serena.gallo@example.com.", false),
              ("Mi chiamo Ada Neri e lavoro a Lecce. Sono serena sotto pressione.", true),
          ])
    func nameIsNoQuality(description: String, stays: Bool) {
        let verdict = sanitizer.skillCheck(technologies: [], softSkills: ["serena", "precisione"], against: description)

        #expect(verdict.softSkills == (stays ? ["serena", "precisione"] : ["precisione"]))
        #expect(verdict.dropped.map(\.reason) == (stays ? [] : ["a name"]))
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

    @Test("A summary sentence whose subject is a bare word of the person's work, with or without its article, goes; one as the person stays (#354, rounds 1 and 3)")
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

        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.hasABareSubject, CVDataSanitizer.hasABareSubject])
        #expect(verdict.kept == ["Mi occupo degli impianti con cura."])
    }

    @Test("A summary sentence that opens with an article and a word of the work, or of work itself, has the work as its subject and goes; one with the person's word after the article, or none, stays (#354, round 3)",
          arguments: [
              ("es", "El trabajo pide orden y calma en cada cierre.", false), ("pt", "O trabalho pede calma e ordem em cada entrega.", false),
              ("it", "Il lavoro di squadra lo curo in ogni chiusura.", false), ("es", "La contable de la oficina cuida cada cierre.", false),
              ("es", "Mi trabajo de cada día son las cuentas de la oficina.", true), ("es", "En el trabajo llevo las cuentas con calma.", true),
              ("it", "Il mio lavoro mi porta ogni giorno tra i conti.", true),
          ])
    func summaryWithTheWorkAsItsSubject(language: String, sentence: String, stays: Bool) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("contable", "Muebles Albarracín", from: "2017")])
        let description = "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y "
            + "analizo los movimientos de caja."

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.hasABareSubject) == !stays, "\(verdict.rejected)")
    }

    @Test("A German summary sentence whose clause after dass, weil or ob puts its verb before the end goes; one with the verb last, or with a comparison after it, stays (#354, round 5)",
          arguments: [
              ("Ich achte darauf, dass alle Maschinen der Halle sauber laufen.", true),
              ("Ich achte darauf, dass alle Maschinen laufen ruhig durch genaue Pflege der Lager.", false),
              ("Ich pflege die Maschinen gern, weil jede Anlage läuft durch gute Pflege der Lager.", false),
              ("Ich sorge dafür, dass jede Maschine läuft wie am ersten Tag.", true),
          ])
    func germanVerbBeforeTheEnd(sentence: String, stays: Bool) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("Mechaniker", "Spulerei Wendt", from: "2016")])
        let description = "Ich wohne in Gera. Seit 2016 arbeite ich als Mechaniker bei der Spulerei Wendt, wo ich die Maschinen der Halle pflege."

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.putsTheVerbBeforeTheEnd) == !stays, "\(verdict.rejected)")
    }

    @Test("A summary sentence of a bare word of the work joined by its language's with to qualities, and no verb, goes; one with a verb of the person stays (#354, round 3)",
          arguments: [
              ("es", "Contable con gran ojo para el detalle y mucha calma.", false), ("it", "Contable con occhio per i dettagli e calma.", false),
              ("pt", "Contable com olho para os detalhes e calma.", false),
              ("es", "Soy contable con buen ojo para los detalles.", true), ("es", "Contable de oficio, llevo las cuentas con calma.", true),
              ("es", "Contable con calma, llevo las cuentas de cada cliente.", true),
          ])
    func summaryFragment(language: String, sentence: String, stays: Bool) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("contable", "Muebles Albarracín", from: "2017")])
        let description = "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y "
            + "analizo los movimientos de caja."

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.hasNoVerb) == !stays, "\(verdict.rejected)")
    }

    @Test("A summary sentence that lists three of the draft's own skills goes; one that names two inside the work stays (#354, round 3)")
    func summaryListingSkills() throws {
        let portuguese = CVDataSanitizer(languageOfText: { _ in "pt" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("programador", "Loja Vidal", from: "2018")])
        let description = "Moro em Braga. Desde 2018 trabalho como programador na Loja Vidal, onde desenvolvo aplicativos com Git e Figma para lojas."

        let verdict = try portuguese.summaryCheck(
            of: facts,
            summary: "Trabalho como programador com terminal, scanner, codec e sensor. Desenvolvo aplicativos com Git e Figma para lojas.",
            field: nil, work: ["aplicativos"], duties: [], qualities: ["paciência"],
            tools: ["terminal", "scanner", "codec", "sensor", "Git", "Figma"], against: description
        )

        #expect(verdict.rejected.map(\.sentence) == ["Trabalho como programador com terminal, scanner, codec e sensor."])
        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.listsSkills])
        #expect(verdict.kept == ["Desenvolvo aplicativos com Git e Figma para lojas."])
    }

    @Test("A summary sentence whose subject is a quality goes; a quality the person works with, or one before a comma, stays (#354, round 2)")
    func summaryWithAQualitySubject() throws {
        let description = JobClausesTests.italian.replacingOccurrences(
            of: "Birrificio Valtrigno di Campobasso, dove coordino tre tecnici.", with: "Birrificio Valtrigno."
        )

        let verdict = try sanitizer.summaryCheck(
            of: Self.italianJobs,
            summary: "Lavoro come capoturno della manutenzione degli impianti. Precisione e calma sono le mie doti in ogni turno. "
                + "Seguo gli impianti con precisione e calma in ogni turno di lavoro. Calmo e attento, seguo ogni impianto fino alla fine.",
            field: nil, work: ["impianti"], duties: [], qualities: ["precisione", "calma"], against: description
        )

        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.hasAQualitySubject])
        #expect(verdict.rejected.map(\.sentence) == ["Precisione e calma sono le mie doti in ogni turno."])
        #expect(verdict.kept.count == 3)
    }

    @Test("A summary sentence that names no word of the work goes after the first; a first one stays unless an opening goes before it, and one that names a title or a duty stays (#354, round 6)")
    func summaryNamingNoWork() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("fitter", "Harlow Mills", from: "2015")])
        let description = "I live in Leeds. Since 2015 I have worked as a fitter at Harlow Mills, where I service each gearbox."
        let check = { (summary: String) in
            try english.summaryCheck(
                of: facts, summary: summary, field: nil, work: ["I service each gearbox."], duties: [], qualities: ["patience"],
                tools: [], against: description
            )
        }
        let titled = "I work as a fitter at a busy mill and keep its lines running through every shift."
        let duty = "I service the gearboxes of the mill with care and check every bearing."
        let calm = "I stay calm with each new challenge."

        let later = try check([titled, calm, duty].joined(separator: " "))
        let first = try check([calm, titled, duty].joined(separator: " "))
        let opened = try check([calm, duty].joined(separator: " "))

        #expect(later.rejected.map(\.sentence) == [calm], "\(later.rejected)")
        #expect(later.kept == [titled, duty])
        #expect(first.rejected.isEmpty, "\(first.rejected)")
        #expect(first.kept == [calm, titled, duty])
        #expect(opened.opening == "I work as a fitter.")
        #expect(opened.rejected.map(\.reason) == [CVDataSanitizer.namesNoWork], "\(opened.rejected)")
        #expect(opened.kept == [duty])
    }

    @Test("A summary sentence that names a kept tool of fewer than five letters names the work, and one the description states is no name; the same sentence without it, or with a tool the description does not state, goes, in the summary check and in the final check (#354, round 10)")
    func summaryNamingAShortTool() throws {
        let english = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("fitter", "Harlow Mills", from: "2015")])
        let description = "I live in Leeds. Since 2015 I have worked as a fitter at Harlow Mills, where I service each gearbox and keep my notes in SAP."
        let check = { (summary: String) in
            try english.summaryCheck(
                of: facts, summary: summary, field: nil, work: ["I service each gearbox.", "SAP", "Maximo"], duties: [], qualities: [],
                tools: ["SAP", "Maximo"], against: description
            )
        }
        let titled = "I work as a fitter at a busy mill and keep its lines running through every shift."
        let tool = "I log each repair in SAP before the end of the day."
        let bare = "I log each repair before the end of the day."
        let inferred = "I log each repair in Maximo before the end of the day."

        let named = try check([titled, tool].joined(separator: " "))
        let unnamed = try check([titled, bare].joined(separator: " "))
        let unstated = try check([titled, inferred].joined(separator: " "))

        #expect(named.rejected.isEmpty, "\(named.rejected)")
        #expect(named.kept == [titled, tool])
        #expect(unnamed.rejected.first { $0.sentence == bare }?.reason == CVDataSanitizer.namesNoWork, "\(unnamed.rejected)")
        #expect(unstated.rejected.first { $0.sentence == inferred }?.reason.hasSuffix("reads as a name") == true, "\(unstated.rejected)")

        // The final check reads the stated technologies the draft keeps as the person's words too: a summary names no tool the
        // description lacks, as no other name (ADR 0031, "inferred").
        let final = { (summary: String, technologies: [String]) in
            try english.sanitize(
                facts, writing: DraftWriting(summary: summary, roleDescriptions: [nil], technologies: technologies, softSkills: []),
                against: description
            ).summary
        }
        #expect(try final([titled, tool].joined(separator: " "), ["SAP"]) == [titled, tool].joined(separator: " "))
        #expect(try final([titled, inferred].joined(separator: " "), ["SAP", "Maximo"]) == titled)
    }

    @Test("A summary sentence names the work by a kept tool only when the description states the tool: one with a tool the person never named and no duty goes (#354, round 11)")
    func summaryNamingAnUnstatedTool() throws {
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("Elektriker", "Kranz", from: "2018")])
        let description = "Seit 2018 arbeite ich als Elektriker bei Kranz in Erfurt und programmiere die Steuerungen mit KNX."
        let check = { (summary: String) in
            try german.summaryCheck(
                of: facts, summary: summary, field: nil, work: ["Ich programmiere die Steuerungen mit KNX.", "KNX"], duties: [],
                qualities: [], tools: ["KNX", "Werkzeugkasten"], against: description
            )
        }
        let titled = "Ich arbeite als Elektriker in neuen Wohnhäusern und halte jede Baustelle in Ordnung."
        let stated = "Ich sichere alle Schritte mit KNX ab."
        let unstated = "Ich sichere alle Schritte mit dem Werkzeugkasten ab."

        let keep = try check([titled, stated].joined(separator: " "))
        let drop = try check([titled, unstated].joined(separator: " "))

        #expect(keep.rejected.isEmpty, "\(keep.rejected)")
        #expect(keep.kept == [titled, stated])
        #expect(drop.rejected.map(\.sentence) == [unstated], "\(drop.rejected)")
        #expect(drop.rejected.map(\.reason) == [CVDataSanitizer.namesNoWork])
        #expect(CVDataSanitizer.namesNoWork == "it says nothing of the work: name a duty of the roles")
    }

    @Test("A short summary gets the opening when it names no title and a sentence of the earlier titles it does not name, the latest first; a full one gets none (#354, round 6)", arguments: [
        ("Mi piace il lavoro fatto bene.",
         "Lavoro come capoturno della manutenzione. Mi piace il lavoro fatto bene. "
            + "In passato ho lavorato come manutentore elettromeccanico e operaio manutentore."),
        ("Sono capoturno della manutenzione da anni.",
         "Sono capoturno della manutenzione da anni. In passato ho lavorato come manutentore elettromeccanico e operaio manutentore."),
        ("Coordino i tecnici della manutenzione in ogni turno. Seguo gli impianti con cura e controllo che le linee girino bene "
            + "dal primo all'ultimo turno.", nil),
        // The floor's opening and the first sentence opened with one verb (#354, round 7).
        ("Lavoro da sedici anni nella manutenzione di impianti industriali.",
         "Sono capoturno della manutenzione. Lavoro da sedici anni nella manutenzione di impianti industriali. "
            + "In passato ho lavorato come manutentore elettromeccanico e operaio manutentore."),
    ] as [(String, String?)])
    func summaryFloor(summary: String, floor: String?) throws {
        let description = JobClausesTests.italian
        let written = try sanitizer.summaryFloor(of: Self.italianJobs, summary: summary, most: 4, against: description)

        #expect(written == floor, "\(written ?? "nil")")
    }

    @Test("The floor names the titles the description grounds, not a title of the draft read in an employer's name (#354, round 7)")
    func summaryFloorOfGroundedTitles() throws {
        let description = """
            Dal 2017 lavoro alla Ferramenta Scaligera come impiegata amministrativa, dove gestisco le fatture dei fornitori. \
            Prima, dal 2013 al 2017, ho lavorato allo Studio Contabile Merlini.
            """
        let facts = CVData(experience: [
            Self.job("impiegata amministrativa", "Ferramenta Scaligera", from: "2017"),
            Self.job("contabile", "Studio Contabile Merlini", from: "2013", to: "2017"),
        ])

        let written = try sanitizer.summaryFloor(of: facts, summary: "Seguo i fornitori con cura.", most: 4, against: description)

        #expect(written == "Lavoro come impiegata amministrativa. Seguo i fornitori con cura.", "\(written ?? "nil")")
    }

    @Test("A written summary sentence that says the person worked as what no kept title names goes; one of a kept title, or of a part of a team, stays (#354, round 7)")
    func summaryOfAnUnkeptTitle() throws {
        let description = "Dal 2015 sono geometra allo Studio Tecnico Ferri di Lecco, dove seguo i cantieri e preparo le pratiche catastali."
        let facts = CVData(experience: [Self.job("geometra", "Studio Tecnico Ferri", from: "2015")])
        let titled = "Lavoro come geometra e seguo i cantieri con cura."
        let team = "Lavoro come parte di una squadra affiatata."
        let writing = DraftWriting(
            summary: [titled, "In passato ho lavorato come tecnico.", team].joined(separator: " "), roleDescriptions: [nil],
            technologies: [], softSkills: []
        )

        let sanitized = try sanitizer.sanitize(facts, writing: writing, against: description)

        #expect(sanitized.summary == [titled, team].joined(separator: " "), "\(sanitized.summary ?? "nil")")
    }

    @Test("A summary sentence that ends with the last three words of an earlier one goes; one that shares fewer stays (#354, round 2)")
    func summaryWithARepeatedEnding() throws {
        let spanish = CVDataSanitizer(languageOfText: { _ in "es" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("contable", "Muebles Albarracín", from: "2017")])
        let description = "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo las cuentas y "
            + "preparo las facturas."

        let verdict = try spanish.summaryCheck(
            of: facts,
            summary: "Trabajo como contable y cuido las cuentas de cada cliente con enfoque ordenado. "
                + "Llevo las cuentas de la empresa con enfoque ordenado. Preparo las facturas de los clientes con un enfoque claro y ordenado.",
            field: nil, work: ["cuentas", "facturas"], duties: [], qualities: [], against: description
        )

        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.endsAsAnEarlierOne])
        #expect(verdict.rejected.map(\.sentence) == ["Llevo las cuentas de la empresa con enfoque ordenado."])
        #expect(verdict.kept == [
            "Trabajo como contable y cuido las cuentas de cada cliente con enfoque ordenado.",
            "Preparo las facturas de los clientes con un enfoque claro y ordenado.",
        ])
    }

    @Test("A summary sentence whose closing clause opens and ends as an earlier one's goes; one that ends otherwise stays (#354, round 8)")
    func summaryWithARepeatedClosing() throws {
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("Tischler", "Holzwerk Brenner", from: "2018")])
        let description = "Ich wohne in Gera. Seit 2018 arbeite ich als Tischler bei Holzwerk Brenner, wo ich Regale baue und Räume ausmesse."

        let verdict = try german.summaryCheck(
            of: facts,
            summary: "Ich arbeite als Tischler und baue Regale für jeden Raum, was die Montage erleichtert. "
                + "Ich messe jeden Raum genau aus, was den Einbau erleichtert. Ich plane jedes Regal mit dem Kunden, was Umbauten spart.",
            field: nil, work: ["Regale", "Räume"], duties: [], qualities: [], against: description
        )

        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.endsAsAnEarlierOne])
        #expect(verdict.rejected.map(\.sentence) == ["Ich messe jeden Raum genau aus, was den Einbau erleichtert."])
        #expect(verdict.kept == [
            "Ich arbeite als Tischler und baue Regale für jeden Raum, was die Montage erleichtert.",
            "Ich plane jedes Regal mit dem Kunden, was Umbauten spart.",
        ])
    }

    /// A summary of a current job and an ended one: the summary sentence it keeps and the one it drops.
    struct EndedJobRow: Sendable {
        let language: String
        let description: String
        let jobs: [Experience]
        let ended: String
        let current: String
        let keeps: String
        let drops: String
    }

    static let endedJobRows: [EndedJobRow] = [
        EndedJobRow(
            language: "it",
            description: "Abito a Rieti. Dal 2012 al 2016 ho lavorato come cameriere alla Locanda Ginepro, dove servivo i piatti ai "
                + "tavoli e apparecchiavo la sala prima del servizio. Dal 2016 lavoro come caposala all'Albergo Sorbo, dove organizzo "
                + "i turni dei camerieri e accolgo i clienti all'ingresso.",
            jobs: [job("cameriere", "Locanda Ginepro", from: "2012", to: "2016"), job("caposala", "Albergo Sorbo", from: "2016")],
            ended: "Servivo i piatti ai tavoli. Apparecchiavo la sala prima del servizio.",
            current: "Organizzo i turni dei camerieri. Accolgo i clienti all'ingresso.",
            keeps: "Organizzo i turni della sala e accolgo i clienti con cortesia.",
            drops: "Apparecchio i tavoli e servo i piatti con precisione."
        ),
        EndedJobRow(
            language: "en",
            description: "I live in Hull. From 2011 to 2017 I was a baker at Wheatley Bakehouse, where I kneaded the dough by hand "
                + "and baked the bread loaves before dawn. Since 2017 I am a shop manager at Corn Exchange Deli, where I order the "
                + "flour stock and train the new staff at the counter.",
            jobs: [job("baker", "Wheatley Bakehouse", from: "2011", to: "2017"), job("shop manager", "Corn Exchange Deli", from: "2017")],
            ended: "I kneaded the dough by hand. I baked the bread loaves before dawn.",
            current: "I order the flour stock. I train the new staff at the counter.",
            keeps: "I order the flour stock and train the counter staff with patience.",
            drops: "I knead the dough by hand and bake the bread loaves before dawn."
        ),
    ]

    @Test("A summary sentence in the present about the duties of an ended job goes; one about the current job stays (#354, round 10)",
          arguments: endedJobRows)
    func summaryOfAnEndedJob(row: EndedJobRow) throws {
        let checker = CVDataSanitizer(
            languageOfText: { _ in row.language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList()
        )

        let verdict = try checker.summaryCheck(
            of: CVData(experience: row.jobs), summary: row.keeps + " " + row.drops, field: nil, work: [row.ended, row.current],
            duties: [row.ended, row.current], qualities: [], tools: [], endedDuties: [row.ended], against: row.description
        )

        #expect(verdict.rejected.map(\.sentence) == [row.drops])
        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.speaksOfAnEndedJob])
        #expect(verdict.kept == [row.keeps])
    }

    @Test("With no current job, a summary sentence in the present about an ended job's duties stays (#354, round 10)")
    func summaryWithNoCurrentJob() throws {
        let checker = CVDataSanitizer(languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let ended = "I kneaded the dough by hand. I baked the bread loaves before dawn."
        let description = "I live in Hull. From 2011 to 2017 I was a baker at Wheatley Bakehouse, where I kneaded the dough by hand and "
            + "baked the bread loaves before dawn."

        let verdict = try checker.summaryCheck(
            of: CVData(experience: [Self.job("baker", "Wheatley Bakehouse", from: "2011", to: "2017")]),
            summary: "I work as a baker. I knead the dough by hand and bake the bread loaves before dawn.", field: nil,
            work: [ended], duties: [ended], qualities: [], tools: [], endedDuties: [ended], against: description
        )

        #expect(!verdict.rejected.contains { $0.reason == CVDataSanitizer.speaksOfAnEndedJob })
    }

    struct SelfPraiseRow: Sendable {
        let summary: String
        let kept: [String]
    }

    static let selfPraiseRows: [SelfPraiseRow] = [
        SelfPraiseRow(
            summary: "Ich arbeite als Elektriker und setze mit dem Bauleiter die Anschlüsse jedes neuen Hauses. "
                + "Ich verlege die Leitungen in neuen Häusern, was die Sicherheit erhöht. "
                + "Ich montiere die Schaltschränke mit Sorgfalt, was meine Konzentration verdeutlicht.",
            kept: [
                "Ich arbeite als Elektriker und setze mit dem Bauleiter die Anschlüsse jedes neuen Hauses.",
                "Ich verlege die Leitungen in neuen Häusern, was die Sicherheit erhöht.",
                "Ich montiere die Schaltschränke mit Sorgfalt.",
            ]
        ),
        SelfPraiseRow(
            summary: "Ich arbeite als Elektriker und setze mit dem Bauleiter die Anschlüsse jedes neuen Hauses. "
                + "Ich verlege die Leitungen in neuen Häusern, was meine Genauigkeit zeigt. "
                + "Ich montiere die Schaltschränke mit Sorgfalt, was meine Konzentration verdeutlicht.",
            kept: [
                "Ich arbeite als Elektriker und setze mit dem Bauleiter die Anschlüsse jedes neuen Hauses.",
                "Ich verlege die Leitungen in neuen Häusern, was meine Genauigkeit zeigt.",
                "Ich montiere die Schaltschränke mit Sorgfalt.",
            ]
        ),
    ]

    @Test("A closing clause of self-praise after an earlier sentence's closing comment goes and its sentence stays; the first comment stays (#354, round 10)",
          arguments: selfPraiseRows)
    func summaryWithASecondSelfPraise(row: SelfPraiseRow) throws {
        let (summary, kept) = (row.summary, row.kept)
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("Elektriker", "Elektro Lindner", from: "2015")])
        let description = "Ich wohne in Suhl. Seit 2015 arbeite ich als Elektriker bei Elektro Lindner. Ich verlege die Leitungen. "
            + "Ich montiere die Schaltschränke. Ich setze die Anschlüsse jedes neuen Hauses."

        let verdict = try german.summaryCheck(
            of: facts, summary: summary, field: nil, work: ["Leitungen", "Anschlüsse", "Schaltschränke"], duties: [], qualities: [], against: description
        )

        #expect(verdict.rejected.isEmpty, "\(verdict.rejected)")
        #expect(verdict.kept == kept)
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

    @Test("A summary sentence with a title or a reflexive pronoun of the third person goes where the pronoun is dropped; a known verb of the third person is written as the person (#354)",
          arguments: [
              ("es", "Contable gestiona los registros con cuidado.", false), ("es", "El contable revisa las facturas.", false),
              ("es", "Analiza los movimientos de caja.", true), ("es", "Se encarga de la contabilidad.", false),
              ("es", "Analizo los movimientos de caja.", true), ("es", "Experiencia en contabilidad de pymes.", true),
              ("es", "Hice la contabilidad de tres empresas.", true), ("es", "Para la empresa llevo la contabilidad.", true),
              ("es", "Llevaba la contabilidad de la empresa.", true),
              ("it", "Si occupa della contabilità.", false), ("it", "Gestisce la contabilità della ditta.", true),
              ("it", "Mi occupo della contabilità.", true), ("it", "Durante il giorno seguo la contabilità.", true),
              ("it", "Gestire la contabilità mi piace.", true),
              ("pt", "Analisa os movimentos de caixa.", true), ("pt", "Analiso os movimentos de caixa.", true),
          ])
    func summaryInTheThirdPerson(language: String, sentence: String, stays: Bool) throws {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let facts = CVData(experience: [Self.job("contable", "Muebles Albarracín", from: "2017")])
        let description = "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y "
            + "analizo los movimientos de caja."

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.speaksInTheThirdPerson) == !stays, "\(verdict.rejected)")
    }

    /// A checker of `language` (Italian, Spanish or Portuguese), with the facts and the description of an accountant in it.
    private static func accountant(
        _ language: String, wordList: TableWordList = TableWordList()
    ) -> (checker: CVDataSanitizer, facts: CVData, description: String) {
        let checker = CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: wordList)
        switch language {
        case "it":
            return (checker, CVData(experience: [Self.job("contabile", "Mobili Brembo", from: "2017")]),
                    "Vivo a Lecco. Dal 2017 lavoro come contabile alla Mobili Brembo, dove tengo la contabilità della ditta e analizzo i movimenti di cassa.")
        case "pt":
            return (checker, CVData(experience: [Self.job("contabilista", "Móveis Cávado", from: "2017")]),
                    "Moro em Braga. Desde 2017 trabalho como contabilista na Móveis Cávado, onde faço a contabilidade e analiso os movimentos de caixa.")
        default:
            return (checker, CVData(experience: [Self.job("contable", "Muebles Albarracín", from: "2017")]),
                    "Vivo en Teruel. Desde 2017 trabajo como contable en Muebles Albarracín, donde llevo la contabilidad y analizo los movimientos de caja.")
        }
    }

    @Test("A summary sentence that opens with a verb of the third person the word list knows in the first person, after a quality or alone, is written as the person; a title or a quality noun as its subject still goes (#354, round 5)",
          arguments: [
              ("it", "Gestisce la contabilità della ditta.", "Gestisco la contabilità della ditta."),
              ("it", "Precisa gestisce la contabilità della ditta.", "Gestisco la contabilità della ditta."),
              ("es", "Analiza los movimientos de caja.", "Analizo los movimientos de caja."),
              ("pt", "Analisa os movimentos de caixa.", "Analiso os movimentos de caixa."),
              ("es", "Contable gestiona los registros con cuidado.", nil),
              ("it", "La precisione guida ogni intervento.", nil),
          ] as [(String, String, String?)])
    func thirdPersonVerbWrittenAsThePerson(language: String, sentence: String, kept: String?) throws {
        let (checker, facts, description) = Self.accountant(language)

        let verdict = try checker.summaryCheck(
            of: facts, summary: sentence, field: nil, work: [], duties: [], qualities: ["precisa"], against: description
        )

        #expect(verdict.kept == (kept.map { [$0] } ?? []), "\(verdict.rejected)")
    }

    @Test("A verb of the third person whose first person the word list does not know is not rewritten, and the sentence goes (#354, round 5)")
    func unknownFirstPersonStaysOut() throws {
        let (checker, facts, description) = Self.accountant("es", wordList: TableWordList(names: TableWordList.inventedNames.union(["analizo"])))

        let verdict = try checker.summaryCheck(of: facts, summary: "Analiza los movimientos de caja.", field: nil, against: description)

        #expect(verdict.kept.isEmpty)
        #expect(verdict.rejected.map(\.reason) == [CVDataSanitizer.speaksInTheThirdPerson])
    }

    @Test("An Italian, Spanish or Portuguese summary sentence with no word and no verb of the person goes; one with a verb of the person first, or first after a comma, or a word of the person stays; a past participle first, or a gerund, is no verb of the person (#354, rounds 5 and 6)",
          arguments: [
              ("it", "Ogni azione è guidata dalla cura per i conti.", false), ("it", "Controllo i conti della ditta ogni giorno.", true),
              ("it", "Con cura, verifico i movimenti di cassa.", true), ("it", "Il mio lavoro è tenere i conti in ordine.", true),
              ("es", "Cada asiento exige atención constante.", false), ("es", "Reviso las facturas cada semana.", true),
              ("pt", "Cada lançamento exige atenção constante.", false), ("pt", "Reviso as faturas todas as semanas.", true),
              // A past participle first is no verb of the person; a first person of the same ending is one (#354, round 6).
              ("es", "Mantenido un control riguroso de las facturas, lo que agiliza los cierres.", false),
              ("es", "Mantengo un control riguroso de las facturas.", true), ("es", "Decido el orden de los cierres mensuales.", true),
              ("it", "Curato ogni dettaglio delle registrazioni contabili.", false),
              ("it", "Abituato alle scadenze, controllo i conti ogni giorno.", true), ("it", "Valuto i rischi di ogni registrazione.", true),
              ("pt", "Mantido um controle rigoroso das faturas.", false), ("pt", "Decido a ordem dos fechamentos mensais.", true),
              // A gerund after a comma is no verb of the person; a first person of the same ending is one (#354, round 6).
              ("it", "Le scadenze richiedono cura, garantendo conti in ordine.", false),
              ("it", "Con pazienza, comprendo le esigenze dei fornitori.", true),
              ("es", "Mantenido un control riguroso de las facturas, evitando retrasos.", false),
              ("es", "Atiendo a los proveedores con calma.", true), ("es", "Reviso las facturas, asegurando su exactitud.", true),
              ("pt", "As faturas exigem cuidado, garantindo prazos cumpridos.", false),
              ("pt", "Atendo os fornecedores com calma.", true),
          ])
    func summaryWithNoVerbOfThePerson(language: String, sentence: String, stays: Bool) throws {
        let (checker, facts, description) = Self.accountant(language)

        let verdict = try checker.summaryCheck(of: facts, summary: sentence, field: nil, against: description)

        #expect(verdict.rejected.map(\.reason).contains(CVDataSanitizer.hasNoVerbOfThePerson) == !stays, "\(verdict.rejected)")
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

    @Test("The summary reads a job's work as its duties' topics: each clause with its subject, auxiliary and verb gone, none with a number (#354, round 3)")
    func workTopics() {
        #expect(CVDataSanitizer.workTopics(of: "Je prépare les ateliers d'éveil et j'accueille les familles le matin.")
            == ["les ateliers d'éveil", "les familles le matin"])
        #expect(CVDataSanitizer.workTopics(of: "Ich habe die Lichtleisten montiert und prüfe die Notbeleuchtung.")
            == ["die Lichtleisten", "die Notbeleuchtung"])
        #expect(CVDataSanitizer.workTopics(of: "Mi occupo delle bolle dei corrieri, controllando gli scaffali e i carrelli.")
            == ["delle bolle dei corrieri", "gli scaffali", "carrelli"])
        #expect(CVDataSanitizer.workTopics(of: "I trained 4 new porters. I sort the parcels and labels.") == ["the parcels", "labels"])
        #expect(CVDataSanitizer.workTopics(of: "I sort the mail. I sort the mail. I fold the towels. I stack the chairs. I wipe the tables.")
            == ["the mail", "the towels", "the chairs", "the tables"])
    }

    @Test("The summary reads a current job's work as the topics of the duties the person said, and those of its written duties only when the person said none (#354, round 11)")
    func workTopicsOfACurrentJob() {
        let written = "Gestisco le fatture dei fornitori. Organizzo le comunicazioni con i fornitori."
        #expect(CVDataSanitizer.workTopics(stated: ["Gestisco le fatture dei fornitori."], duties: written) == ["le fatture dei fornitori"])
        #expect(CVDataSanitizer.workTopics(stated: [], duties: written) == ["le fatture dei fornitori", "le comunicazioni con i fornitori"])
        #expect(CVDataSanitizer.workTopics(stated: [], duties: nil).isEmpty)
        let french = "Je prépare les ateliers d'éveil et j'accueille les familles le matin."
        #expect(CVDataSanitizer.workTopics(stated: [french], duties: french + " Je range la salle.")
            == ["les ateliers d'éveil", "les familles le matin"])
    }
}

/// A dictionary that knows every word in English and none in any other language.
private struct EnglishOnly: WordList {
    func knows(_ word: String, inLanguage language: String) -> Bool? { language == "en" }
}
