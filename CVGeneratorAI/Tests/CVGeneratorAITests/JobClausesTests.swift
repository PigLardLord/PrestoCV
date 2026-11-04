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
