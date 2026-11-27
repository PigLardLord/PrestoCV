import Testing
@testable import CVGeneratorAI

/// A summary names only the personal qualities the draft's soft skills hold (#359, N1): "…with focus and precision" of a draft whose
/// soft skills hold "precision" and not "focus" (the rules dropped it as a second quality of one kind) said a quality the skills list
/// does not. A quality the description states is the person's own. The descriptions are the evaluation's, and every name and trade
/// in them is invented.
@Suite("A summary names only the qualities the soft skills hold (#359, N1)", .richDraft)
struct SummaryQualityTests {
    private static func sanitizer(_ language: String) -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
    }

    private static func description(of id: String) throws -> String {
        try #require(DraftingInputs.all().first { $0.id == id }).description
    }

    private static let warehouse = CVData(
        personalInfo: PersonalInfo(name: "Daniel Hart", title: "warehouse supervisor"),
        experience: [
            Experience(title: "warehouse supervisor", company: "Northfield Logistics", startDate: "2019", current: true),
            Experience(title: "forklift driver", company: "Kestrel Foods", startDate: "2014", endDate: "2019"),
        ],
        education: [Education(degree: "logistics", institution: "Leeds City College")],
        languages: [Language(name: "English"), Language(name: "Polish")]
    )

    private static let designer = CVData(
        personalInfo: PersonalInfo(name: "Carmen Ibarra", title: "diseñadora gráfica"),
        experience: [
            Experience(title: "diseñadora gráfica", company: "Lumbre Creativa", startDate: "2021", current: true),
            Experience(title: "maquetadora", company: "Mar de Letras", startDate: "2017", endDate: "2021"),
        ]
    )

    private static let cook = CVData(
        personalInfo: PersonalInfo(name: "Luca Ferrandi", title: "cuoco"),
        experience: [
            Experience(title: "cuoco", company: "Il Gabbiano", startDate: "2020", current: true),
            Experience(title: "aiuto cuoco", company: "Hotel Belvedere", startDate: "2016", endDate: "2020"),
        ]
    )

    private static let accountant = CVData(personalInfo: PersonalInfo(title: "comptable"), experience: [])

    // MARK: A quality the soft skills do not hold goes

    @Test("The qualities of a manner phrase that are none of the soft skills are cut out of the sentence, which stays; the evaluation's sentences",
          arguments: [
            ("en-plain", "I allocate storage space efficiently while handling the night shifts with focus and precision.",
             ["reliability", "organization", "dedication", "precision", "trust"],
             "I allocate storage space efficiently while handling the night shifts with precision."),
            ("es-plain",
             "Organizaba la disposición de los contenidos en el material impreso con atención al detalle y enfoque en la claridad.",
             ["precisión", "creatividad", "organización", "equilibrio"],
             "Organizaba la disposición de los contenidos en el material impreso."),
            ("it-plain", "Organizzo la distribuzione dei materiali per garantire l'efficienza del lavoro con attenzione e rigore.",
             ["affidabilità", "precisione", "curiosità", "coordinamento"],
             "Organizzo la distribuzione dei materiali per garantire l'efficienza del lavoro."),
          ])
    func unheldQualityCut(id: String, sentence: String, qualities: [String], kept: String) throws {
        let cv = ["en-plain": Self.warehouse, "es-plain": Self.designer, "it-plain": Self.cook][id]!
        let language = String(id.prefix(2))

        let verdict = try Self.sanitizer(language).summaryCheck(
            of: cv, summary: sentence, field: nil, work: [], duties: [], qualities: qualities, against: try Self.description(of: id)
        )

        #expect(verdict.kept == [kept], "\(verdict.kept) \(verdict.rejected)")
        #expect(verdict.rejected.isEmpty, "\(verdict.rejected)")
    }

    @Test("The cut leaves what follows the phrase: a comma and the clause after it, or the gerund of the tools (the evaluation's sentences)")
    func unheldQualityCutBeforeAClause() throws {
        let english = try Self.sanitizer("en").summaryCheck(
            of: Self.warehouse,
            summary: "I guide the forklift drivers through their shifts with patience and focus, supporting the stock count in a clear way.",
            field: nil, work: [], duties: [], qualities: ["reliability", "passion", "clarity"], against: try Self.description(of: "en-plain")
        )
        let french = try Self.sanitizer("fr").summaryCheck(
            of: Self.accountant,
            summary: "Je rédige les rapports annuels avec précision en utilisant les Tablettes de calcul pour les données financières.",
            field: nil, work: [], duties: [], qualities: ["rigueur", "ponctualité", "discrétion", "organisation"],
            tools: ["Tablettes de calcul"], against: try Self.description(of: "fr-sparse")
        )

        #expect(english.kept == ["I guide the forklift drivers through their shifts, supporting the stock count in a clear way."],
                "\(english.kept) \(english.rejected)")
        #expect(french.kept == ["Je rédige les rapports annuels en utilisant les Tablettes de calcul pour les données financières."],
                "\(french.kept) \(french.rejected)")
    }

    @Test("A sentence whose quality phrase cannot be cut clean goes whole, with the reason: the phrase takes a complement, joins a word that is no quality, or leaves fewer than four words",
          arguments: [
            "I plan the night shifts with focus on safety.",
            "I plan the night shifts with focus and speed.",
            "I work with focus.",
          ])
    func unheldQualityRejected(sentence: String) throws {
        let verdict = try Self.sanitizer("en").summaryCheck(
            of: Self.warehouse, summary: sentence, field: nil, work: [], duties: [], qualities: ["reliability", "precision"],
            against: try Self.description(of: "en-plain")
        )

        #expect(verdict.kept.isEmpty, "\(verdict.kept)")
        #expect(verdict.rejected.map(\.sentence) == [sentence], "\(verdict.rejected)")
        #expect(verdict.rejected.allSatisfy { $0.reason.hasPrefix(CVDataSanitizer.namesAnUnheldQuality) }, "\(verdict.rejected)")
    }

    @Test("The final pass cuts a quality that is none of the kept soft skills from the summary, and keeps the rest")
    func finalPassCutsTheQuality() throws {
        let english = Self.sanitizer("en")
        let writing = DraftWriting(
            summary: "I work as a warehouse supervisor. I allocate storage space efficiently while handling the night shifts with focus and precision.",
            roleDescriptions: [nil, nil], technologies: [], softSkills: ["Precision", "Reliability"]
        )

        let draft = try english.sanitize(Self.warehouse, writing: writing, against: try Self.description(of: "en-plain"))

        #expect(draft.skills.filter { $0.kind == .softSkill }.map(\.name) == ["Precision", "Reliability"], "\(draft.skills)")
        #expect(
            draft.summary == "I work as a warehouse supervisor. I allocate storage space efficiently while handling the night shifts with precision.",
            "\(draft.summary ?? "nil")"
        )
    }

    // MARK: A quality the description gives someone else does not hold

    private static let baker = CVData(
        personalInfo: PersonalInfo(name: "Daniel Hart", title: "baker"),
        experience: [Experience(title: "baker", company: "Acme", startDate: "2019", current: true)]
    )

    private static let bakerDescription = "I work as a baker at Acme, where I bake bread. I am patient. My colleague works with precision."

    @Test("A quality only a colleague has is cut out of the person's sentence, in the check and in the final pass")
    func qualityOfAColleagueCut() throws {
        let english = Self.sanitizer("en")
        let sentence = "I bake bread every morning with precision."

        let verdict = try english.summaryCheck(
            of: Self.baker, summary: sentence, field: nil, work: [], duties: [], qualities: ["patience"], against: Self.bakerDescription
        )
        let writing = DraftWriting(
            summary: "I work as a baker. " + sentence, roleDescriptions: [nil], technologies: [], softSkills: ["Patience"]
        )
        let draft = try english.sanitize(Self.baker, writing: writing, against: Self.bakerDescription)

        #expect(verdict.kept == ["I bake bread every morning."], "\(verdict.kept) \(verdict.rejected)")
        #expect(draft.summary == "I work as a baker. I bake bread every morning.", "\(draft.summary ?? "nil")")
    }

    // MARK: A quality the soft skills hold, or the description states, stays

    @Test("A manner phrase of qualities that are all soft skills stays, in every language",
          arguments: [
            ("en-plain", "I allocate storage space efficiently while handling the night shifts with focus and precision.", ["focus", "precision"]),
            ("en-plain", "I allocate storage space efficiently while handling the night shifts with great precision.", ["Precision"]),
            ("es-plain", "Creo propuestas gráficas innovadoras con precisión y creatividad.", ["precisión", "creatividad"]),
            ("it-plain", "Gestisco la distribuzione dei piatti e la pulizia delle superfici di lavoro con affidabilità e precisione.",
             ["affidabilità", "precisione"]),
            ("it-plain", "Organizzo la distribuzione dei materiali per garantire l'efficienza del lavoro con la massima attenzione.",
             ["Attenzione ai dettagli"]),
          ])
    func heldQualityKept(id: String, sentence: String, qualities: [String]) throws {
        let cv = ["en-plain": Self.warehouse, "es-plain": Self.designer, "it-plain": Self.cook][id]!

        let verdict = try Self.sanitizer(String(id.prefix(2))).summaryCheck(
            of: cv, summary: sentence, field: nil, work: [], duties: [], qualities: qualities, against: try Self.description(of: id)
        )

        #expect(verdict.kept == [sentence], "\(verdict.kept) \(verdict.rejected)")
    }

    @Test("A quality the description states is the person's own, whatever the soft skills hold")
    func statedQualityKept() throws {
        let description = """
            I am a warehouse supervisor at Northfield Logistics. I plan the night shifts and I check every delivery with care. \
            I speak English and Polish.
            """
        let sentence = "I allocate storage space efficiently while handling the night shifts with care."

        let verdict = try Self.sanitizer("en").summaryCheck(
            of: Self.warehouse, summary: sentence, field: nil, work: [], duties: [], qualities: ["reliability"], against: description
        )

        #expect(verdict.kept == [sentence], "\(verdict.kept) \(verdict.rejected)")
    }

    @Test("A phrase with a tool or a noun that is no manner of the person stays, and so does a sentence when the soft skills are not known",
          arguments: [
            ("I track the stock movements with SAP and Excel.", ["reliability"]),
            ("I weigh the parcels with a precision scale.", ["reliability"]),
            ("I check the night shifts with attention sensors.", ["reliability"]),
            ("I allocate storage space efficiently while handling the night shifts with focus and precision.", []),
          ])
    func otherPhrasesKept(sentence: String, qualities: [String]) throws {
        let verdict = try Self.sanitizer("en").summaryCheck(
            of: Self.warehouse, summary: sentence, field: nil, work: [], duties: [], qualities: qualities, tools: ["SAP", "Excel"],
            against: try Self.description(of: "en-plain")
        )

        #expect(verdict.kept == [sentence], "\(verdict.kept) \(verdict.rejected)")
    }

    // MARK: The reading, language by language

    private static func held(_ softSkills: [String]) -> Set<String> {
        UnheldQualities.heldWords(softSkills: softSkills, stated: [])
    }

    @Test("The phrase is read in every language: a list of qualities after the introducer, with its article, its intensifier and its detail",
          arguments: [
            (Vocabulary.Language.german, "Ich installiere die Anlagen in den Neubauten mit Zuverlässigkeit und Empathie.", ["Zuverlässigkeit"],
             "Ich installiere die Anlagen in den Neubauten mit Zuverlässigkeit."),
            (.german, "Ich installiere die Anlagen in den Neubauten mit großer Sorgfalt.", ["Zuverlässigkeit"],
             "Ich installiere die Anlagen in den Neubauten."),
            (.german, "Ich installiere die Anlagen in den Neubauten mit Zuverlässigkeit und Empathie.", ["Zuverlässigkeit", "Empathie"],
             "Ich installiere die Anlagen in den Neubauten mit Zuverlässigkeit und Empathie."),
            (.portuguese, "Organizo a distribuição dos materiais do armazém com atenção constante e rigor.", ["Pontualidade"],
             "Organizo a distribuição dos materiais do armazém."),
            (.portuguese, "Organizo a distribuição dos materiais do armazém com atenção ao detalhe e rigor.", ["Atenção ao detalhe"],
             "Organizo a distribuição dos materiais do armazém com atenção ao detalhe."),
            (.french, "Je gère les soldes financiers de l'entreprise avec rigueur, précision et patience.", ["Rigueur"],
             "Je gère les soldes financiers de l'entreprise avec rigueur."),
            (.french, "Je gère les soldes financiers de l'entreprise avec une grande rigueur et beaucoup de patience.", ["Patience"],
             "Je gère les soldes financiers de l'entreprise avec beaucoup de patience."),
            (.italian, "Organizzo la distribuzione dei materiali con attenzione costante.", ["Affidabilità"],
             "Organizzo la distribuzione dei materiali."),
            (.italian, "Organizzo la distribuzione dei materiali, con la massima attenzione.", ["Affidabilità"],
             "Organizzo la distribuzione dei materiali."),
            (.spanish, "Diseño los carteles de la tienda con creatividad y atención al detalle, usando Illustrator.", ["Creatividad"],
             "Diseño los carteles de la tienda con creatividad, usando Illustrator."),
          ])
    func everyLanguage(language: Vocabulary.Language, sentence: String, softSkills: [String], expected: String) {
        let outcome = UnheldQualities.check(sentence, language: language, held: Self.held(softSkills))

        if expected == sentence {
            #expect(outcome == .unchanged, "\(outcome)")
        } else {
            #expect(outcome == .without(expected), "\(outcome)")
        }
    }

    @Test("A phrase that is no list of qualities, or whose qualities the description states, is left as it is")
    func leftAlone() {
        let sentence = "I plan the night shifts with patience and focus."

        #expect(UnheldQualities.check(sentence, language: .english, held: Self.held(["Reliability"])) == .without("I plan the night shifts."))
        #expect(UnheldQualities.check(sentence, language: .english, held: UnheldQualities.heldWords(softSkills: [], stated: ["patient", "focused"])) == .unchanged)
        #expect(UnheldQualities.check(sentence, language: nil, held: Self.held(["Reliability"])) == .unchanged)
        #expect(UnheldQualities.check("With focus and patience, I plan the night shifts.", language: .english, held: Self.held([])) == .unchanged)
    }

    @Test("The final pass keeps the sentences that name no unheld quality, drops one that cannot be cut, and reads nothing without soft skills")
    func appliedToASummary() {
        let summary = "I work as a supervisor. I plan the night shifts with focus on safety. I check the deliveries with patience and care."
        let held = Self.held(["Care"])

        #expect(UnheldQualities.applied(to: summary, language: .english, held: held)
                == "I work as a supervisor. I check the deliveries with care.")
        #expect(UnheldQualities.applied(to: summary, language: .english, held: nil) == summary)
        #expect(UnheldQualities.applied(to: "I plan the night shifts with focus on safety.", language: .english, held: held) == nil)
        #expect(UnheldQualities.applied(to: nil, language: .english, held: held) == nil)
    }
}
