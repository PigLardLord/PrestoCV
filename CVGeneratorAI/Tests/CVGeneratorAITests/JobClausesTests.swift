import Testing
@testable import CVGeneratorAI

/// A job's own clauses (#354, ADR 0031): a description that names two jobs in one run-on sentence ("a sound technician at
/// Brightwater ..., then at Copperfield ...") gives the second job the title of the first, and the duties the person said for a job
/// stay in front of the duties written for it. Every name, trade and date is invented.
@Suite("A job's own clauses: the title of a run-on sentence and the duties the person said (#354)")
struct JobClausesTests {
    private let sanitizer = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

    static let english = """
        I have worked in live sound for theatres and touring shows for thirteen years.
        I started in 2013 as a stagehand at the Fenwick Playhouse in Norwich, where I rigged the lights and loaded the trucks until 2016.
        Then I was a sound technician at Brightwater Events from 2016 to 2019, then at Copperfield Arena from 2019 to 2021, \
        setting up the PA systems and mixing the support acts.
        At Copperfield Arena I was also helping the lighting crew with the follow spots.
        Since 2021 I have been head of sound at the Orchard Lane Theatre, where I plan the sound design for each production \
        and train the junior technicians.
        I am now looking for a technical manager role at a larger venue.
        """

    static let italian = """
        Lavoro da sedici anni nella manutenzione di impianti industriali.
        Dal 2010 al 2014 sono stato operaio manutentore alla Conserve Albarella di Termoli, dove riparavo i nastri trasportatori.
        Poi ho fatto il manutentore elettromeccanico al Pastificio Cerreto dal 2014 al 2018, poi al Molino Fontebasso dal 2018 al 2020, \
        controllando i quadri elettrici e programmando la manutenzione preventiva.
        Dal 2020 sono capoturno della manutenzione al Birrificio Valtrigno di Campobasso, dove coordino tre tecnici.
        """

    private static func job(
        _ title: String, _ company: String, from start: String, to end: String? = nil, description: String? = nil
    ) -> Experience {
        Experience(title: title, company: company, startDate: start, endDate: end, current: end == nil, description: description)
    }

    private static let englishJobs = [
        job("stagehand", "Fenwick Playhouse", from: "2013", to: "2016"),
        job("sound technician", "Brightwater Events", from: "2016", to: "2019"),
        job("sound technician", "Copperfield Arena", from: "2019", to: "2021"),
        job("head of sound", "Orchard Lane Theatre", from: "2021"),
    ]

    // MARK: The title of a run-on sentence

    @Test("A job named after another in a run-on sentence keeps the title the sentence gave the first (H1)")
    func runOnTitle() throws {
        let result = try sanitizer.sanitize(CVData(experience: Self.englishJobs), against: Self.english)

        #expect(result.experience.map(\.title) == ["stagehand", "sound technician", "sound technician", "head of sound"])
    }

    @Test("An Italian job named after another in a run-on sentence keeps the title the sentence gave the first (H1)")
    func italianRunOnTitle() throws {
        let draft = CVData(experience: [
            Self.job("manutentore elettromeccanico", "Pastificio Cerreto", from: "2014", to: "2018"),
            Self.job("manutentore elettromeccanico", "Molino Fontebasso", from: "2018", to: "2020"),
        ])

        let result = try sanitizer.sanitize(draft, against: Self.italian)

        #expect(result.experience.map(\.title) == ["manutentore elettromeccanico", "manutentore elettromeccanico"])
    }

    @Test("A title the description gives another job still goes from a job named in a run-on sentence")
    func otherTitleGoes() throws {
        let draft = CVData(experience: [
            Self.job("sound technician", "Brightwater Events", from: "2016", to: "2019"),
            Self.job("stagehand", "Copperfield Arena", from: "2019", to: "2021"),
        ])

        let result = try sanitizer.sanitize(draft, against: Self.english)

        #expect(result.experience.map(\.title) == ["sound technician", ""])
    }

    @Test("A title the description never names becomes the one the run-on sentence gave the job")
    func unnamedTitleTakesTheSentence() throws {
        let draft = CVData(experience: [
            Self.job("sound technician", "Brightwater Events", from: "2016", to: "2019"),
            Self.job("lighting technician", "Copperfield Arena", from: "2019", to: "2021"),
        ])

        let result = try sanitizer.sanitize(draft, against: Self.english)

        #expect(result.experience.map(\.title) == ["sound technician", "sound technician"])
    }

    // MARK: The duties the person said

    @Test("The duties the person said for a job stay in front of the written ones, in the job's first person (H3)")
    func saidDutiesStay() throws {
        let written = DraftWriting(
            summary: nil,
            roleDescriptions: [
                "I moved the scenery between scenes.", "I tested the microphones before each show.",
                "I tested the microphones before each show.", "I lead the sound team.",
            ],
            technologies: [], softSkills: []
        )

        let result = try sanitizer.sanitize(CVData(experience: Self.englishJobs), writing: written, against: Self.english)
        let texts = result.experience.map { $0.description ?? "" }

        try #require(texts.count == 4)
        #expect(texts[0].hasPrefix("I rigged the lights and loaded the trucks."))
        #expect(texts[1].hasPrefix("I was setting up the PA systems and mixing the support acts."))
        #expect(texts[2].hasPrefix("I was setting up the PA systems and mixing the support acts."))
        #expect(texts[3].hasPrefix("I plan the sound design for each production and train the junior technicians."))
        #expect(texts[0].hasSuffix("I moved the scenery between scenes."))
        #expect(texts[3].hasSuffix("I lead the sound team."))
    }

    @Test("A job's quote said with a gerund is in the first person and ends with a full stop, also when no written duty stays (#354)")
    func quoteWithNoDuties() throws {
        let draft = CVData(experience: [
            Self.job(
                "sound technician", "Brightwater Events", from: "2016", to: "2019",
                description: "setting up the PA systems and mixing the support acts"
            ),
            Self.job("sound technician", "Copperfield Arena", from: "2019", to: "2021"),
        ])
        let written = DraftWriting(summary: nil, roleDescriptions: [nil, nil], technologies: [], softSkills: [])

        let withDuties = try sanitizer.sanitize(draft, writing: written, against: Self.english)
        let plain = try sanitizer.sanitize(draft, against: Self.english)

        #expect(withDuties.experience.first?.description == "I was setting up the PA systems and mixing the support acts.")
        #expect(plain.experience.first?.description == "setting up the PA systems and mixing the support acts.")
    }

    // MARK: A duty said twice

    static let storeroom = """
        Dal 2016 al 2021 ho fatto il magazziniere alla Ferramenta Bruni di Rieti, sistemando gli scaffali e ricevendo la merce dei \
        fornitori.
        Alla Ferramenta Bruni davo anche una mano con le consegne ai clienti.
        """

    @Test("A clause of a job's quote that a duty the person said holds, after its verb, goes; one with a word of its own stays (#354)",
          arguments: [
              ("sistemando gli scaffali, dando una mano con le consegne ai clienti", false),
              ("sistemando gli scaffali, dando una mano con le consegne dei fornitori", true),
          ])
    func clauseSaidTwice(quote: String, staysWhole: Bool) throws {
        let sanitizer = CVDataSanitizer(languageOfText: { _ in "it" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let draft = CVData(experience: [Self.job("magazziniere", "Ferramenta Bruni", from: "2016", to: "2021", description: quote)])
        let written = DraftWriting(summary: nil, roleDescriptions: ["Controllavo le bolle di carico."], technologies: [], softSkills: [])

        let job = try sanitizer.sanitize(draft, writing: written, against: Self.storeroom).experience.first
        let text = try #require(job?.description)

        #expect(text.components(separatedBy: "una mano con le consegne").count - 1 == (staysWhole ? 2 : 1), "\(text)")
        #expect(text.contains("una mano con le consegne dei fornitori") == staysWhole, "\(text)")
        #expect(text.contains("Davo anche una mano con le consegne ai clienti."), "\(text)")
    }

    // MARK: A duty said again in another tense, or under another job (#362)

    private static func maintenance(quotes: [String?]) -> CVData {
        CVData(experience: [
            job("operaio manutentore", "Conserve Albarella", from: "2010", to: "2014", description: quotes[0]),
            job("manutentore elettromeccanico", "Pastificio Cerreto", from: "2014", to: "2018", description: quotes[1]),
            job("manutentore elettromeccanico", "Molino Fontebasso", from: "2018", to: "2020", description: quotes[2]),
            job("capoturno della manutenzione", "Birrificio Valtrigno", from: "2020", description: quotes[3]),
        ])
    }

    private static let belts = "Riparavo i nastri trasportatori."
    private static let panels = "Controllavo i quadri elettrici e programmavo la manutenzione preventiva."
    private static let crew = "Coordino tre tecnici."
    private static let noText: [String?] = [nil, nil, nil, nil]

    struct TextRow: Sendable, CustomTestStringConvertible {
        let name: String
        let quotes: [String?]
        let duties: [String?]
        let texts: [String]
        var testDescription: String { name }
    }

    static let textRows: [TextRow] = [
        TextRow(
            name: "a quote in the present of a said duty",
            quotes: [nil, "Controllo i quadri elettrici e programmo la manutenzione preventiva.", nil, nil], duties: noText,
            texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "a quote in the present of a part of a said duty", quotes: [nil, "Controllo i quadri elettrici.", nil, nil],
            duties: noText, texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "a quote with a gerund of a part of a said duty", quotes: [nil, "controllando i quadri elettrici", nil, nil],
            duties: noText, texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "a quote in the present of an ended job's said duty", quotes: ["Riparo i nastri trasportatori.", nil, nil, nil],
            duties: noText, texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "a quote that copies another job's said duty", quotes: [nil, nil, nil, "Riparo i nastri trasportatori."],
            duties: noText, texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "a written duty that copies another job's said duty", quotes: noText,
            duties: [nil, nil, nil, "Riparo i nastri trasportatori."], texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "a written duty that copies the tail two other jobs share", quotes: noText,
            duties: ["Controllavo i quadri elettrici.", nil, nil, nil], texts: [belts, panels, panels, crew]
        ),
        TextRow(
            name: "duties with the verb of a said duty and other objects", quotes: [nil, "Controllavo la qualità dei pezzi.", nil, nil],
            duties: [nil, nil, "Controllavo la qualità delle saldature.", "Controllo la manutenzione. Controllo la qualità dei pezzi."],
            texts: [
                belts, "Controllavo la qualità dei pezzi. " + panels, panels + " Controllavo la qualità delle saldature.",
                crew + " Controllo la manutenzione. Controllo la qualità dei pezzi.",
            ]
        ),
    ]

    @Test("A job says a duty once, in its own tense, and says no duty the person said only for another job; other duties stay (#362)",
          arguments: textRows)
    func dutySaidOnce(row: TextRow) throws {
        let sanitizer = CVDataSanitizer(languageOfText: { _ in "it" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let written = DraftWriting(summary: nil, roleDescriptions: row.duties, technologies: [], softSkills: [])

        let result = try sanitizer.sanitize(Self.maintenance(quotes: row.quotes), writing: written, against: Self.italian)
        let texts: [String] = result.experience.map { $0.description ?? "" }

        #expect(texts == row.texts)
    }

    @Test("A written duty that copies, in any tense, a duty the person said only for another job goes; a shared tail and another object stay (#362)",
          arguments: [
              (3, "Riparo i nastri trasportatori.", false),
              (0, "Controllavo i quadri elettrici.", false),
              (0, "Sostituivo i cuscinetti dei motori.", true),
              (2, "Controllavo la qualità delle saldature.", true),
              (3, "Controllo la manutenzione dei forni.", true),
              (3, "Sostituisco i nastri trasportatori.", true),
          ])
    func dutyOfAnotherJob(index: Int, duty: String, stays: Bool) throws {
        let sanitizer = CVDataSanitizer(languageOfText: { _ in "it" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

        let verdicts = try sanitizer.dutyCheck(of: Self.maintenance(quotes: Self.noText), job: index, duties: duty, against: Self.italian)

        #expect(verdicts.kept == (stays ? [duty] : []), "\(verdicts.rejected)")
        #expect(verdicts.rejected.map(\.reason) == (stays ? [] : ["it says what the person did at another job"]))
    }

    // MARK: A duty of another job joined to another, or in the third person (#362)

    /// The maintenance description, with a first job whose duty joins two.
    private static let joinedItalian = italian.replacingOccurrences(
        of: "riparavo i nastri trasportatori.", with: "riparavo i nastri trasportatori e sostituivo i cuscinetti."
    )

    private static let mechanic = """
        Trabajo desde hace catorce años en la mecánica del automóvil.
        De 2009 a 2013 fui ayudante de taller en Talleres Arbizu de Logroño, donde cambiaba el aceite y montaba los neumáticos.
        Después fui mecánico en Autos Cendal de 2013 a 2017, luego en Garaje Olmedo de 2017 a 2020, revisando los frenos y \
        diagnosticando averías.
        Desde 2020 soy jefe de taller en Motor Valdecanas de Haro, donde reparto el trabajo del equipo.
        """

    private static let carpenter = """
        Trabalho há catorze anos com carpintaria.
        De 2010 a 2013 fui ajudante de marcenaria na Marcenaria Jatobá de Maringá, onde cortava as chapas e lixava as peças.
        Depois fui carpinteiro na Móveis Guaraci de 2013 a 2017, depois na Oficina Itaúna de 2017 a 2020, montando armários e \
        instalando portas.
        Desde 2020 sou encarregado de carpintaria na Construtora Pedra Branca de Londrina, onde coordeno a equipe.
        """

    /// Four jobs of `language`'s description, the last current, and the description.
    private static func staff(_ language: String) -> (jobs: CVData, description: String) {
        switch language {
        case "es":
            (CVData(experience: [
                job("ayudante de taller", "Talleres Arbizu", from: "2009", to: "2013"), job("mecánico", "Autos Cendal", from: "2013", to: "2017"),
                job("mecánico", "Garaje Olmedo", from: "2017", to: "2020"), job("jefe de taller", "Motor Valdecanas", from: "2020"),
            ]), mechanic)
        case "pt":
            (CVData(experience: [
                job("ajudante de marcenaria", "Marcenaria Jatobá", from: "2010", to: "2013"),
                job("carpinteiro", "Móveis Guaraci", from: "2013", to: "2017"), job("carpinteiro", "Oficina Itaúna", from: "2017", to: "2020"),
                job("encarregado de carpintaria", "Construtora Pedra Branca", from: "2020"),
            ]), carpenter)
        default:
            (maintenance(quotes: noText), joinedItalian)
        }
    }

    struct DutyRow: Sendable, CustomTestStringConvertible {
        let language: String
        let job: Int
        let duty: String
        let stays: Bool
        var testDescription: String { "\(language), job \(job): \(duty)" }
    }

    @Test("A written duty that joins a duty the person said only for another job to another, or says it in the third person, goes; another object stays (#362)",
          arguments: [
              DutyRow(language: "it", job: 1, duty: "Ripara i nastri trasportatori e sostituisce i cuscinetti.", stays: false),
              DutyRow(language: "it", job: 1, duty: "Riparavo i nastri trasportatori e sostituivo i cuscinetti.", stays: false),
              DutyRow(language: "it", job: 3, duty: "Coordino i turni e sostituisco i cuscinetti.", stays: false),
              DutyRow(language: "it", job: 1, duty: "Sostituiva i cuscinetti.", stays: false),
              DutyRow(language: "it", job: 3, duty: "Sostituisco i filtri delle pompe.", stays: true),
              DutyRow(language: "es", job: 1, duty: "Cambia el aceite y monta los neumáticos.", stays: false),
              DutyRow(language: "es", job: 2, duty: "Cambiaba el aceite y montaba los neumáticos.", stays: false),
              DutyRow(language: "es", job: 3, duty: "Reparto el trabajo del equipo y cambio el aceite.", stays: false),
              DutyRow(language: "es", job: 3, duty: "Cambio los filtros del aire.", stays: true),
              DutyRow(language: "pt", job: 1, duty: "Lixa as peças e corta as chapas.", stays: false),
              DutyRow(language: "pt", job: 2, duty: "Lixava as peças e cortava as chapas.", stays: false),
              DutyRow(language: "pt", job: 3, duty: "Coordeno a equipe e corto as chapas.", stays: false),
              DutyRow(language: "pt", job: 3, duty: "Corto as portas dos armários.", stays: true),
          ])
    func joinedDutyOfAnotherJob(row: DutyRow) throws {
        let sanitizer = CVDataSanitizer(
            languageOfText: { _ in row.language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList()
        )
        let (jobs, description) = Self.staff(row.language)

        let verdicts = try sanitizer.dutyCheck(of: jobs, job: row.job, duties: row.duty, against: description)

        #expect(verdicts.kept == (row.stays ? [row.duty] : []), "\(verdicts.rejected)")
        #expect(verdicts.rejected.map(\.reason) == (row.stays ? [] : ["it says what the person did at another job"]))
    }

    /// A duty the person said in the present with no job (ADR 0031, D7), after the description of `language` in `staff`.
    private static let generalDuty = [
        "it": "Lubrifico i motori e pulisco i filtri delle pompe.", "es": "Limpio las piezas desmontadas.", "pt": "Limpo as ferramentas.",
    ]

    enum TenseOutcome: Sendable { case stays, goesForTheTense, neverForTheTense }

    struct TenseRow: Sendable, CustomTestStringConvertible {
        let language: String
        let job: Int
        let duty: String
        let outcome: TenseOutcome
        var testDescription: String { "\(language), job \(job): \(duty)" }
    }

    @Test("At an ended job with a duty in the past, a duty in the third person present of a said duty goes for its tense; in the past it stays, and a noun never goes for a tense (#362)",
          arguments: [
              TenseRow(language: "it", job: 1, duty: "Lubrifica i motori.", outcome: .goesForTheTense),
              TenseRow(language: "it", job: 1, duty: "Pulisce i filtri delle pompe.", outcome: .goesForTheTense),
              TenseRow(language: "it", job: 1, duty: "Lubrificava i motori.", outcome: .stays),
              TenseRow(language: "it", job: 1, duty: "Lubrificazione dei motori.", outcome: .neverForTheTense),
              TenseRow(language: "it", job: 1, duty: "Pulizia dei filtri delle pompe.", outcome: .neverForTheTense),
              TenseRow(language: "es", job: 0, duty: "Limpia las piezas desmontadas.", outcome: .goesForTheTense),
              TenseRow(language: "es", job: 0, duty: "Limpió las piezas desmontadas.", outcome: .stays),
              TenseRow(language: "es", job: 0, duty: "Limpieza de las piezas desmontadas.", outcome: .neverForTheTense),
              TenseRow(language: "pt", job: 0, duty: "Limpa as ferramentas.", outcome: .goesForTheTense),
              TenseRow(language: "pt", job: 0, duty: "Limpou as ferramentas.", outcome: .stays),
              TenseRow(language: "pt", job: 0, duty: "Limpeza das ferramentas.", outcome: .neverForTheTense),
          ])
    func thirdPersonTense(row: TenseRow) throws {
        let sanitizer = CVDataSanitizer(
            languageOfText: { _ in row.language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList()
        )
        let (jobs, description) = Self.staff(row.language)

        let verdicts = try sanitizer.dutyCheck(
            of: jobs, job: row.job, duties: row.duty, against: description + "\n" + (Self.generalDuty[row.language] ?? "")
        )
        let forTheTense = verdicts.rejected.filter { $0.reason.hasPrefix("it is in the present, and the job has ended") }

        if row.outcome != .neverForTheTense { #expect(verdicts.kept == (row.outcome == .stays ? [row.duty] : []), "\(verdicts.rejected)") }
        #expect(forTheTense.count == (row.outcome == .goesForTheTense ? 1 : 0), "\(verdicts.rejected)")
    }

    private static let spareParts = """
        Dal 2015 al 2019 ho fatto il magazziniere all'Officina Ferrante di Isernia, dove ho aiutato con gli ordini dei ricambi.
        """

    @Test("A duty on the object of a said duty with another verb is another duty: it stays beside the person's, quoted or written (#362)",
          arguments: [
              (nil, "Gestivo gli ordini dei ricambi.", "Ho aiutato con gli ordini dei ricambi. Gestivo gli ordini dei ricambi."),
              ("Gestivo gli ordini dei ricambi.", nil, "Gestivo gli ordini dei ricambi. Ho aiutato con gli ordini dei ricambi."),
          ] as [(String?, String?, String)])
    func dutyWithAnotherVerb(quote: String?, duty: String?, text: String) throws {
        let sanitizer = CVDataSanitizer(languageOfText: { _ in "it" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let draft = CVData(experience: [Self.job("magazziniere", "Officina Ferrante", from: "2015", to: "2019", description: quote)])
        let written = DraftWriting(summary: nil, roleDescriptions: [duty], technologies: [], softSkills: [])

        let result = try sanitizer.sanitize(draft, writing: written, against: Self.spareParts)
        let texts: [String] = result.experience.map { $0.description ?? "" }

        #expect(texts == [text])
    }
}
