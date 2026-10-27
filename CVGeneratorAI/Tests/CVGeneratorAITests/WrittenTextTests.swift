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
