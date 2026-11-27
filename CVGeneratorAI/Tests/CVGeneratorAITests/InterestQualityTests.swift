import Testing
@testable import CVGeneratorAI

/// An interest is a pastime (#354): a clause in which the person tells a quality at work ("I keep calm with the guests", "mi piace
/// lavorare in gruppo") is no interest, and goes; a hobby stays, with the person's own things in it ("walks with my dog"). Every
/// name and sentence is invented.
@Suite("An interest is a pastime, never a quality at work (#354)")
struct InterestQualityTests {
    private let sanitizer = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

    static let english = """
        I have been a waiter at the Lantern Bistro in Exeter since 2019. I keep calm with the guests and I like working \
        side by side with the chefs. In my free time I like chess, long walks with my dog and hiking in the Alps.
        """

    static let italian = """
        Dal 2018 faccio il magazziniere alla Logistica Varesi di Pavia. Sono paziente e mi piace lavorare in gruppo. \
        Nel tempo libero mi piace la fotografia.
        """

    @Test("A quality at work written as an interest goes, in English")
    func englishQualitiesGo() throws {
        let draft = CVData(interests: ["keep calm with the guests", "like working side by side with the chefs", "chess"])

        let result = try sanitizer.sanitize(draft, against: Self.english)

        #expect(result.interests == ["chess"])
    }

    @Test("A clause in which the person tells a quality goes, in Italian, and the hobby stays")
    func italianClauseGoes() throws {
        let draft = CVData(interests: ["sono paziente e mi piace lavorare in gruppo", "fotografia"])

        let result = try sanitizer.sanitize(draft, against: Self.italian)

        #expect(result.interests == ["fotografia"])
    }

    @Test("A liking of some work goes when the verb of liking is not its first word")
    func likingOfWorkGoes() throws {
        let draft = CVData(interests: ["mi piace lavorare in gruppo", "fotografia"])

        let result = try sanitizer.sanitize(draft, against: Self.italian)

        #expect(result.interests == ["fotografia"])
    }

    // MARK: The verb of an interest

    static let german = """
        Seit 2019 arbeite ich als Feinmechaniker bei der Werkstatt Ohlsen in Suhl. In meiner Freizeit gehe ich klettern, höre \
        klassische Musik und spiele Schach.
        """

    static let sundays = "I have been a waiter at the Lantern Bistro in Exeter since 2019. On Sundays I play chess and go hiking in the Alps."

    @Test("An interest quoted with a conjugated verb of its clause is the pastime the verb names; one that starts with an adjective, a verb in the form of its infinitive or a gerund stays whole (#354)")
    func verbOfAnInterestGoes() throws {
        let german = CVDataSanitizer(
            languageOfText: { _ in "de" },
            lexicalClasses: ForcedLexicalTagger([.german: .words(["arbeite", "gehe", "hore", "spiele", "klettern"])]), wordList: TableWordList()
        )
        let english = CVDataSanitizer(
            languageOfText: { _ in "en" },
            lexicalClasses: ForcedLexicalTagger([.english: .words(["have", "been", "play", "go", "hiking"])]), wordList: TableWordList()
        )

        let leisure = try german.sanitize(CVData(interests: ["klettern", "klassische Musik", "spiele Schach"]), against: Self.german)
        let sundays = try english.sanitize(CVData(interests: ["play chess", "hiking in the Alps"]), against: Self.sundays)

        #expect(leisure.interests == ["klettern", "klassische Musik", "Schach"])
        #expect(sundays.interests == ["play chess", "hiking in the Alps"])
    }

    @Test("An English interest whose verb is in the form the person says after \"I\" keeps its verb, and a German one conjugated loses it (#354)",
          arguments: [("play football", "en", "play football"), ("bake bread", "en", "bake bread"), ("spiele Schach", "de", "Schach")])
    func infinitiveOfAnInterestStays(interest: String, language: String, kept: String) throws {
        let description = language == "en"
            ? "I have been a waiter at the Lantern Bistro in Exeter since 2019. I play football and I bake bread."
            : Self.german
        let sanitizer = CVDataSanitizer(
            languageOfText: { _ in language },
            lexicalClasses: ForcedLexicalTagger([.english: .words(["have", "been", "play", "bake"]), .german: .words(["arbeite", "gehe", "hore", "spiele", "klettern"])]),
            wordList: TableWordList()
        )

        let result = try sanitizer.sanitize(CVData(interests: [interest]), against: description)

        #expect(result.interests == [kept])
    }

    @Test("A verb is conjugated by its ending: \"-s\" or \"-ed\" in English, anything but \"-n\" in German (#354)",
          arguments: [("play", "en", false), ("plays", "en", true), ("baked", "en", true), ("dress", "en", false), ("spiele", "de", true), ("spielen", "de", false)])
    func conjugatedVerb(verb: String, language: String, conjugated: Bool) throws {
        #expect(CVDataSanitizer.isConjugated(verb, in: try #require(Vocabulary.Language(rawValue: language))) == conjugated)
    }

    #if canImport(NaturalLanguage)
    @Test("A German interest that starts with a capital verb after \"und\" is the pastime the verb names, by the device's tags (#354)")
    func capitalVerbOfAnInterestGoes() throws {
        let german = CVDataSanitizer(languageOfText: { _ in "de" }, lexicalClasses: DeviceLexicalTagger(), wordList: TableWordList())

        let leisure = try german.sanitize(CVData(interests: ["klettern", "klassische Musik", "Spiele Schach"]), against: Self.german)

        #expect(leisure.interests == ["klettern", "klassische Musik", "Schach"])
    }
    #endif

    // MARK: A hobby is never cut to a fragment (#359)

    /// One description per language, each with the pastimes a draft quotes.
    static let pastimes: [String: String] = [
        "de": """
            Seit 2019 arbeite ich als Feinmechaniker bei der Werkstatt Ohlsen in Suhl. In meiner Freizeit gehe ich klettern und spiele \
            Schach. Ich spiele das Klavier und koche am Wochenende für meine Freunde. Ich gehe gern mit meinem Hund spazieren und \
            wandere in den Bergen. Ich mag Fußball, Lesen und Wandern in den Bergen. Ich fahre am Wochenende gern Rad und sammle \
            im Herbst. Ich tanze nicht am Wochenende und schwimme selten im Winter. \
            Ich male im Sommer nie und reite im Winter selten.
            """,
        "en": """
            I have been a waiter at the Lantern Bistro in Exeter since 2019. In my free time I walked in the park every Sunday, \
            and I like chess, football and hiking in the Alps.
            """,
        "it": "Faccio il magazziniere a Pavia dal 2018. Nel tempo libero mi piace la pesca e passeggiare con il mio cane.",
        "es": "Soy mecánico en Zaragoza desde 2018. En mi tiempo libre me gusta la pesca y salir a pasear por el campo.",
        "fr": "Je suis boulanger à Lille depuis 2018. Pendant mon temps libre, j'aime la lecture et la randonnée dans les Vosges.",
        "pt": "Sou padeiro em Braga desde 2018. No meu tempo livre gosto de pesca e de caminhadas com o meu cão.",
    ]

    @Test("An interest cut to a clause fragment goes, and a noun hobby stays: a conjugated verb is cut away only when a noun phrase is left, and a German verb that only tells when, where or how gives its noun (#359)",
          arguments: [
              ("de", "koche am Wochenende für meine Freunde", ["Kochen"]),
              ("de", "gehe gern mit meinem Hund spazieren", ["Spazieren"]),
              ("de", "wandere in den Bergen", ["Wandern"]),
              ("de", "sammle im Herbst", ["Sammeln"]),
              ("de", "fahre am Wochenende gern Rad", []),
              ("de", "tanze nicht am Wochenende", []),
              ("de", "schwimme selten im Winter", []),
              ("de", "male im Sommer nie", []),
              ("de", "reite im Winter selten", []),
              ("de", "Wandern in den", []),
              ("de", "spiele Schach", ["Schach"]),
              ("de", "spiele das Klavier", ["Klavier"]),
              ("de", "Wandern in den Bergen", ["Wandern in den Bergen"]),
              ("de", "Fußball", ["Fußball"]),
              ("de", "Lesen", ["Lesen"]),
              ("en", "walked in the park", []),
              ("en", "hiking in the", []),
              ("en", "football", ["football"]),
              ("en", "hiking in the Alps", ["hiking in the Alps"]),
              ("it", "passeggiare con il", []),
              ("it", "la pesca", ["la pesca"]),
              ("es", "pasear por el", []),
              ("es", "la pesca", ["la pesca"]),
              ("fr", "la randonnée dans les", []),
              ("fr", "la lecture", ["la lecture"]),
              ("pt", "caminhadas com o", []),
              ("pt", "pesca", ["pesca"]),
          ])
    func fragmentOfAHobbyGoes(language: String, interest: String, kept: [String]) throws {
        let sanitizer = CVDataSanitizer(
            languageOfText: { _ in language },
            lexicalClasses: ForcedLexicalTagger([
                .german: .words(["arbeite", "spiele", "koche", "gehe", "wandere", "mag", "fahre", "sammle", "tanze", "schwimme", "male", "reite"]),
                .english: .words(["have", "been", "walked", "like"]),
            ]),
            wordList: TableWordList()
        )

        let result = try sanitizer.sanitize(CVData(interests: [interest]), against: try #require(Self.pastimes[language]))

        #expect(result.interests == kept)
    }

    @Test("A German hobby the person denies or hardly ever does gives no pastime", arguments: [
        "koche nicht am Wochenende", "male im Sommer nie", "reite im Winter selten", "gehe nie mit meinem Hund spazieren",
        "koche kaum für meine Freunde", "wandere niemals in den Bergen",
    ])
    func deniedHobbyGivesNoPastime(interest: String) {
        #expect(InterestFragment.germanActivity(of: interest) == nil)
    }

    @Test("A hobby with the person's own things in it stays")
    func hobbiesStay() throws {
        let draft = CVData(interests: ["chess", "long walks with my dog", "hiking in the Alps"])

        let result = try sanitizer.sanitize(draft, against: Self.english)

        #expect(result.interests == ["chess", "long walks with my dog", "hiking in the Alps"])
    }

    @Test("D8: a liking of working or collaborating gives the work in the person's words; another liking, a wish or a title gives none (#354)",
          arguments: [
              ("I keep calm and I like working closely with choreographers.", ["working closely with choreographers"]),
              ("Sono paziente e mi piace lavorare in squadra.", ["lavorare in squadra"]),
              ("Me gusta colaborar con los proveedores.", ["colaborar con los proveedores"]),
              ("Gosto de trabalhar em equipe, e sou calmo.", ["trabalhar em equipe"]),
              ("I like baking rye bread.", []),
              ("I would like to work closely with chefs.", []),
              ("I'd like to work with chefs.", []),
              ("J'aime travailler comme guide.", []),
          ])
    func workLikings(sentence: String, expected: [String]) {
        #expect(CVDataSanitizer.workLikings(in: sentence) == expected)
    }
}
