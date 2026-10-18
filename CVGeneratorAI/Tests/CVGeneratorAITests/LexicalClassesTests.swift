import Testing
import Foundation
@testable import CVGeneratorAI

#if canImport(NaturalLanguage)
/// The device's lexical class tells the verbs of English and German, contractions included. Grounding reads no tag of the other
/// languages, whatever the device tags.
@Suite("Lexical classes: the verbs the device tags")
struct LexicalClassesTests {
    private func verbs(_ text: String, language: Vocabulary.Language?) -> [String] {
        let words = Word.words(in: text)
        return LexicalClasses.verbs(in: text, words: words, language: language).sorted().map { words[$0].folded }
    }

    @Test("English verbs are tagged, and a contraction is its full form")
    func english() {
        #expect(verbs("I am going to work at Acme", language: .english) == ["am", "going", "work"])
        #expect(verbs("I'm a nurse at Acme", language: .english) == ["m"])
        #expect(verbs("Nurse at Acme", language: .english).isEmpty)
    }

    @Test("German verbs are tagged")
    func german() {
        #expect(verbs("Ich habe vor, bei Acme zu arbeiten", language: .german) == ["habe", "arbeiten"])
    }

    @Test("Without a language no word is tagged")
    func noLanguage() {
        #expect(verbs("I am going to work at Acme", language: nil).isEmpty)
    }

    @Test("The tagger of the task tells the verbs: a verdict forced for English, the device for German")
    func taggerOfTheTask() {
        LexicalClasses.$tagger.withValue(ForcedLexicalTagger([.english: .words(["acme"])])) {
            #expect(verbs("I am going to work at Acme", language: .english) == ["acme"])
            #expect(verbs("Ich habe vor, bei Acme zu arbeiten", language: .german) == ["habe", "arbeiten"])
        }
    }

    @Test("Italian, Spanish, French and Portuguese are never tagged, even by a device that tags every word of theirs", arguments: [
        ("Insegno corsi a studenti presso Acme.", Vocabulary.Language.italian), ("No dudes en contactarme.", .spanish),
        ("N'hésitez pas à me contacter.", .french), ("Trabalhei na Acme.", .portuguese),
    ])
    func untaggedLanguages(text: String, language: Vocabulary.Language) {
        LexicalClasses.$tagger.withValue(ForcedLexicalTagger([language: .everyWord])) {
            #expect(verbs(text, language: language).isEmpty)
        }
    }
}
#endif
