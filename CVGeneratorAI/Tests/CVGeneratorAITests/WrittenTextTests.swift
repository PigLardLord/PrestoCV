import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0031: a sentence the model writes around the facts is kept when it states no fact of its own. The rows of the contract read
/// it through the whole sanitizer; these read `WrittenText` alone, with the dictionary, the language detector and the tagger of
/// names that the contract leaves fixed.
@Suite("Written text: a sentence that states no fact of its own")
struct WrittenTextTests {
    private func written(
        _ description: String, claiming claimed: [String]? = nil, wordList: any WordList = TableWordList(),
        tagger: any LexicalTagger = ListedNames(), languageOfText: @escaping @Sendable (String) -> String? = { _ in nil }
    ) -> WrittenText {
        let source = DescriptionText(description, languageOfText: languageOfText)
        let claimedText = claimed.map { DescriptionText(sentences: $0, of: source) } ?? source
        return WrittenText(source: source, claimed: claimedText, wordList: wordList, tagger: tagger)
    }

    private let teacher = "I'm a primary school teacher. I teach at a school in my town."

    @Test("A sentence in plain words of the profession is plain")
    func plainWords() {
        #expect(written(teacher).isPlain("A patient teacher who plans lessons and works closely with families.", ownWords: []))
    }

    @Test("A digit, a number in words, a month, a negation or an address is a fact", arguments: [
        "Teaches 3 classes.", "Teaches five classes.", "Organises the school trip in june.", "Never misses a lesson.",
        "Doesn't miss a lesson.", "Answers at maria@example.com.",
    ])
    func facts(sentence: String) {
        #expect(!written(teacher).isPlain(sentence, ownWords: []))
    }

    @Test("A sentence that holds master states a degree, whatever the words around it", arguments: [
        ("Has a master in education.", false), ("Holds a Master of Science.", false), ("Has a master's degree.", false),
        ("Holds a masters.", false), ("Holds a masters focused on education.", false), ("Holds a master.", false),
        ("Masters data science.", false), ("Holds a masters; data analysis informs the work.", false),
        ("Works with Master Data Management.", false),
    ])
    func masterIsADegree(sentence: String, isPlain: Bool) {
        #expect(written(teacher).isPlain(sentence, ownWords: ["master", "data", "management", "science"]) == isPlain, "\(sentence)")
    }

    @Test("A length, a rank or a level is a fact only when the description does not write it")
    func unstatedLevels() {
        let sentence = "A senior teacher with years of experience."

        #expect(!written(teacher).isPlain(sentence, ownWords: []))
        #expect(written("I'm a senior teacher with years of experience at a school.").isPlain(sentence, ownWords: []))
    }

    @Test("A word the description holds only where the person claims nothing is a fact the person never claimed")
    func excludedWords() {
        let text = written("I teach at a school. I would like to teach music.", claiming: ["I teach at a school."])

        #expect(!text.isPlain("Teaches music to the pupils.", ownWords: []))
        #expect(text.isPlain("Teaches the pupils.", ownWords: []))
        #expect(text.isExcluded("music"))
    }

    @Test("A word of another job is another job's duty")
    func foreignWords() {
        #expect(!written(teacher).isPlain("Looks after the children of the nursery.", ownWords: [], foreignWords: ["nursery"]))
    }

    @Test("A capital after the first word is a name, but for the person's own titles")
    func capitals() {
        let text = written(teacher)

        #expect(!text.isPlain("Works closely with Rose.", ownWords: []))
        #expect(text.isPlain("A Primary School Teacher who plans lessons.", ownWords: ["primary", "school", "teacher"]))
        #expect(!text.isPlain("Prepares the pupils for the INVALSI tests.", ownWords: []))
    }

    @Test("A word the dictionary does not know is a name")
    func unknownWords() {
        #expect(!written(teacher, wordList: TableWordList(names: ["globex"])).isPlain("Uses the globex method.", ownWords: []))
        #expect(written(teacher, wordList: TableWordList(names: [])).isPlain("Uses the globex method.", ownWords: []))
    }

    @Test("A sentence the detector reads in another language than the description's is not plain")
    func anotherLanguage() {
        let text = written(teacher, languageOfText: { $0.contains("paziente") ? "it" : "en" })

        #expect(!text.isPlain("Insegnante paziente che prepara le lezioni.", ownWords: []))
        #expect(text.isPlain("A patient teacher who plans lessons.", ownWords: []))
    }

    @Test("A German noun has a capital and is no name; a word the tagger calls a name is one")
    func germanNames() {
        let description = "Ich bin Grundschullehrerin. Ich unterrichte an einer Schule."
        let sentence = "Sie arbeitet eng mit Rose und den Familien zusammen."

        #expect(written(description).isPlain(sentence, ownWords: []))
        #expect(!written(description, tagger: ListedNames(["rose"])).isPlain(sentence, ownWords: []))
        #expect(!written(description).isPlain("Sie arbeitet eng mit dem UKE zusammen.", ownWords: []))
    }

    @Test("Every language lists the noun of experience among its words of seniority", arguments: Vocabulary.Language.allCases)
    func experienceIsSeniority(language: Vocabulary.Language) {
        let noun = ["en": "experience", "it": "esperienza", "de": "erfahrung", "es": "experiencia", "fr": "experience", "pt": "experiencia"]

        #expect(WrittenTextWords.of(language).seniority.contains(noun[language.rawValue] ?? ""))
    }
}

/// ADR 0031: a skill the model writes for the role names no language: the languages are the person's own.
@Suite("Inferred skills: the names of the languages")
struct InferredSkillLanguageTests {
    @Test("The names of the world's languages, in the six languages of the app, are known; words of a trade are not")
    func languageNames() {
        for name in ["english", "inglese", "englisch", "ingles", "anglais", "italian", "tedesco", "deutsch"] {
            #expect(InferredSkills.languageNames.contains(name), "\(name)")
        }
        for word in ["planning", "management", "care", "patience", "teamwork"] {
            #expect(!InferredSkills.languageNames.contains(word), "\(word)")
        }
    }
}

/// The device's dictionary and tagger of names, which the contract replaces with fixed ones.
@Suite("Written text: the device's dictionary and names")
struct WrittenTextOnTheDeviceTests {
    @Test("The device's dictionary knows a word of the language and no invented one, and has none of an unknown language")
    func deviceWordList() {
        let dictionary = DeviceWordList()

        #expect(dictionary.knows("teacher", inLanguage: "en") == true)
        #expect(dictionary.knows("glorbexquint", inLanguage: "en") == false)
        #expect(dictionary.knows("teacher", inLanguage: "xx") == nil)
    }

    #if canImport(NaturalLanguage)
    @Test("The device tags a place of a German text as a name, and not its nouns")
    func deviceNames() {
        let text = "Ich arbeite als Lehrerin in Hamburg."
        let names = DeviceLexicalTagger().names(in: text, language: "de")
        let words = Word.words(in: text)
        let named = words.filter { word in names.contains { $0.contains(word.range.lowerBound) } }.map(\.folded)

        #expect(named == ["hamburg"])
    }
    #endif
}

/// A tagger of names that tags the words it is given, as `Word.folded` writes them, and no verb.
private struct ListedNames: LexicalTagger {
    let names: Set<String>

    init(_ names: Set<String> = []) {
        self.names = names
    }

    func tagsLexicalClass(inLanguage language: String) -> Bool { true }
    func verbs(in text: String, language: String) -> [Range<Int>] { [] }
    func names(in text: String, language: String) -> [Range<Int>] {
        Word.words(in: text).filter { names.contains($0.folded) }.map(\.range)
    }
}

/// ADR 0031: a qualification and a number are facts in any language and in any way they are written, in a sentence the model writes
/// around the facts. The language is given, so the verdict is the same on every device.
@Suite("Written text: qualifications and numbers written as one word")
struct WrittenTextFactsTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let language: String
        let description: String
        let plain: String
        let qualifications: [String]
        let numbers: [String]

        var testDescription: String { language }
    }

    static let cases: [Case] = [
        Case(language: "en", description: "I'm a primary school teacher. I teach at a school in my town.",
             plain: "A patient teacher who plans lessons and works closely with families.",
             qualifications: ["Holds a teaching license.", "A certified teacher.", "Has a master in education.", "Holds a degree."],
             numbers: ["Teaches twentyone pupils.", "Follows thirtyfive pupils."]),
        Case(language: "it", description: "Sono un'insegnante di scuola primaria. Insegno in una scuola della mia città.",
             plain: "Insegnante paziente che prepara le lezioni e collabora con le famiglie.",
             qualifications: ["Ha l'abilitazione all'insegnamento.", "Ha una laurea in pedagogia.", "È un'insegnante certificata."],
             numbers: ["Segue ventuno alunni.", "Segue trentatré alunni.", "Segue duecento alunni.", "Segue tremila alunni.",
                       "Segue centoventi alunni."]),
        Case(language: "de", description: "Ich bin Grundschullehrerin. Ich unterrichte an einer Schule in meiner Stadt.",
             plain: "Geduldige Lehrerin, die den Unterricht plant.",
             qualifications: ["Sie besitzt eine Lizenz zum Unterrichten.", "Sie hat einen Abschluss in Pädagogik.",
                              "Sie ist zertifizierte Lehrerin."],
             numbers: ["Sie betreut einundzwanzig Kinder.", "Sie betreut zweihundert Kinder.", "Sie betreut dreitausend Kinder.",
                       "Sie betreut zweihunderteinundzwanzig Kinder."]),
        Case(language: "es", description: "Soy maestra de primaria. Enseño en una escuela de mi ciudad.",
             plain: "Maestra paciente que prepara las clases y colabora con las familias.",
             qualifications: ["Tiene la licenciatura en educación.", "Tiene una licencia para enseñar.", "Es una maestra titulada."],
             numbers: ["Atiende a veintiuno alumnos.", "Atiende a veintiún alumnos.", "Atiende a veintidós alumnos.",
                       "Atiende a doscientos alumnos.", "Atiende a quinientos alumnos."]),
        Case(language: "fr", description: "Je suis institutrice. J'enseigne dans une école de ma ville.",
             plain: "Institutrice patiente qui prépare les cours et collabore avec les familles.",
             qualifications: ["Possède une licence en éducation.", "Est une institutrice diplômée.", "Possède un master."],
             numbers: ["Suit vingt-deux élèves.", "Suit quatre-vingt-dix élèves.", "Suit quatrevingts élèves."]),
        Case(language: "pt", description: "Sou professora do ensino fundamental. Leciono numa escola da minha cidade.",
             plain: "Professora paciente que prepara as aulas e colabora com as famílias.",
             qualifications: ["Possui licenciatura em educação.", "É uma professora habilitada.", "Possui um mestrado."],
             numbers: ["Acompanha duzentos alunos.", "Acompanha quinhentos alunos.", "Acompanha dezoito alunos."]),
    ]

    private func written(_ item: Case) -> WrittenText {
        let tag = item.language
        let source = DescriptionText(item.description, languageOfText: { _ in tag })
        return WrittenText(source: source, claimed: source, wordList: TableWordList(), tagger: ListedNames())
    }

    @Test("A sentence in plain words of the profession is plain, in every language", arguments: cases)
    func plain(item: Case) {
        #expect(written(item).isPlain(item.plain, ownWords: []), "\(item.plain)")
    }

    @Test("A word of a qualification states a fact the person never stated, in every language", arguments: cases)
    func qualification(item: Case) {
        let text = written(item)

        for sentence in item.qualifications {
            #expect(!text.isPlain(item.plain + " " + sentence, ownWords: []), "\(sentence)")
            #expect(!text.isPlain(sentence, ownWords: []), "\(sentence)")
        }
    }

    @Test("A number written as one word, compound or inflected, counts what the person never counted, in every language", arguments: cases)
    func compoundNumber(item: Case) {
        let text = written(item)

        for sentence in item.numbers {
            #expect(!text.isPlain(sentence, ownWords: []), "\(sentence)")
        }
    }

    @Test("A compound number word is a number; a word that only looks like one is not", arguments: Vocabulary.Language.allCases)
    func numberWords(language: Vocabulary.Language) {
        let numbers: [Vocabulary.Language: [String]] = [
            .english: ["twentyone", "ninetynine", "twohundred"],
            .italian: ["ventuno", "ventidue", "trentatre", "centoventi", "duecento", "tremila", "centouno", "ventotto", "novecentonovantanove"],
            .german: ["einundzwanzig", "zweihundert", "dreitausend", "zweihunderteinundzwanzig", "einhundert", "dreiundzwanzig"],
            .spanish: ["veintiuno", "veintiun", "veintiuna", "veintidos", "doscientos", "doscientas", "quinientos", "setecientos"],
            .french: ["quatrevingts", "vingts"],
            .portuguese: ["duzentos", "trezentas", "quinhentos", "novecentos"],
        ]
        let others: [Vocabulary.Language: [String]] = [
            .english: ["tone", "often", "alone", "stone", "teacher"],
            .italian: ["insegnante", "treno", "settimana", "unico", "sedia", "tremendo", "duomo"],
            .german: ["einzig", "dreieck", "achtung", "lehrerin", "einen", "zweiter"],
            .spanish: ["dosis", "milagro", "docente", "diezmo", "maestra"],
            .french: ["institutrice", "feuille", "centre", "dixieme"],
            .portuguese: ["professora", "milagre", "dezembro", "centro"],
        ]
        let words = WrittenTextWords.of(language)

        for word in numbers[language] ?? [] { #expect(words.isNumber(word), "\(word)") }
        for word in others[language] ?? [] { #expect(!words.isNumber(word), "\(word)") }
    }
}
