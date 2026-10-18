import Testing
import Foundation
@testable import CVGeneratorAI

/// The verbs the vocabulary does not list, told by their form: the markers of an infinitive, the endings of an infinitive, of a
/// future and of a conditional.
@Suite("Verb forms: infinitives, futures and conditionals by their endings")
struct VerbFormsTests {
    private func word(_ text: String) -> Word {
        Word.words(in: text)[0]
    }

    @Test("A marker introduces an infinitive in its own language", arguments: [
        ("to", Vocabulary.Language.english), ("zu", .german), ("di", .italian), ("per", .italian), ("de", .spanish), ("para", .spanish),
        ("pour", .french), ("de", .french), ("para", .portuguese), ("a", .spanish), ("con", .spanish), ("em", .portuguese),
        ("com", .portuguese),
    ])
    func markers(marker: String, language: Vocabulary.Language) {
        #expect(VerbForms.isInfinitiveMarker(marker, in: language), "\(marker)")
    }

    @Test("\"to\" and \"zu\" are the markers when the language is not known, and no other word is")
    func markersWithoutALanguage() {
        #expect(VerbForms.isInfinitiveMarker("to", in: nil))
        #expect(VerbForms.isInfinitiveMarker("zu", in: nil))
        #expect(!VerbForms.isInfinitiveMarker("per", in: nil))
        #expect(!VerbForms.isInfinitiveMarker("to", in: .italian))
    }

    @Test("An infinitive of Italian, Spanish, French or Portuguese ends like one, and is long enough", arguments: [
        ("lavorare", Vocabulary.Language.italian), ("trabajar", .spanish), ("travailler", .french), ("trabalhar", .portuguese),
        ("laurearsi", .italian), ("mettre", .french),
    ])
    func infinitives(text: String, language: Vocabulary.Language) {
        #expect(VerbForms.hasInfinitiveEnding(word(text), in: language), "\(text)")
    }

    @Test("A short word, or a word of another ending, is no infinitive; English and German have none by ending", arguments: [
        ("per", Vocabulary.Language.italian), ("ser", .spanish), ("lavoro", .italian), ("work", .english), ("arbeiten", .german),
    ])
    func notInfinitives(text: String, language: Vocabulary.Language) {
        #expect(!VerbForms.hasInfinitiveEnding(word(text), in: language), "\(text)")
    }

    @Test("A future or a conditional ends like one: the accent tells \"lavorerò\" from \"numero\"", arguments: [
        ("resterò", Vocabulary.Language.italian), ("lavorerà", .italian), ("lavorerei", .italian), ("lavorerebbe", .italian),
        ("quedaré", .spanish), ("trabajará", .spanish), ("trabajaría", .spanish), ("tendré", .spanish),
        ("resterai", .french), ("travaillerais", .french), ("voudrait", .french), ("sera", .french),
        ("ficarei", .portuguese), ("trabalharão", .portuguese), ("serei", .portuguese),
    ])
    func tenses(text: String, language: Vocabulary.Language) {
        #expect(VerbForms.hasTenseEnding(word(text), in: language), "\(text)")
    }

    @Test("A word that only ends like a tense is none: a noun, a present, a past", arguments: [
        ("numero", Vocabulary.Language.italian), ("infermiera", .italian), ("enfermería", .spanish), ("trabajé", .spanish),
        ("portrait", .french), ("travaillé", .french), ("trabalhei", .portuguese), ("verão", .portuguese),
    ])
    func notTenses(text: String, language: Vocabulary.Language) {
        #expect(!VerbForms.hasTenseEnding(word(text), in: language), "\(text)")
    }

    @Test("Only Italian, Spanish, French and Portuguese read infinitives by their ending")
    func readByEnding() {
        #expect(VerbForms.readsInfinitivesByEnding(in: .italian))
        #expect(VerbForms.readsInfinitivesByEnding(in: .portuguese))
        #expect(!VerbForms.readsInfinitivesByEnding(in: .english))
        #expect(!VerbForms.readsInfinitivesByEnding(in: .german))
        #expect(!VerbForms.readsInfinitivesByEnding(in: nil))
    }

    @Test("An English gerund that no form of to be makes finite is bare: \"reading\" in a list of interests, not \"looking\" in \"I'm looking\"")
    func bareGerunds() {
        func isBare(_ text: String, at index: Int, in language: Vocabulary.Language = .english) -> Bool {
            let words = Word.words(in: text)
            return VerbForms.isBareGerund(words[index], after: index > 0 ? words[index - 1] : nil, in: language)
        }

        #expect(isBare("Interests reading", at: 1))
        #expect(isBare("problem solving", at: 1))
        #expect(isBare("Leading", at: 0))
        #expect(!isBare("I'm looking", at: 2))
        #expect(!isBare("She was working", at: 2))
        #expect(!isBare("I have been working", at: 3))
        #expect(!isBare("They bring", at: 1), "bring is a verb, not a gerund")
        #expect(!isBare("worked", at: 0))
        #expect(!isBare("Interessen lesen", at: 1, in: .german))
    }

    @Test("Grounding reads the verbs of English and German from the device's tags, and of no other language")
    func verbsByTags() {
        #expect(VerbForms.readsVerbsByTags(in: .english))
        #expect(VerbForms.readsVerbsByTags(in: .german))
        #expect(!VerbForms.readsVerbsByTags(in: .italian))
        #expect(!VerbForms.readsVerbsByTags(in: nil))
    }
}
