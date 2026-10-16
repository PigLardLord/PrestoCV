import Testing
import Foundation
@testable import CVGeneratorAI

#if canImport(NaturalLanguage)
/// The device's lexical class tells the verbs of English and German, contractions included; it tells none of the other languages.
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
}
#endif
