import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Which words of a text the device's lexical class tells are verbs (ADR 0023, rule (c)). The framework tags the verbs of English and
/// German, contractions included ("I'm" is "I" and "'m"); for the other languages it tags nothing, and `VerbForms` reads them. Where
/// the framework is not there, no word is a verb.
enum LexicalClasses {
    /// What tags the words: the device's framework. A test gives another verdict for the task it runs, with `$tagger.withValue`.
    @TaskLocal static var tagger: any LexicalTagger = DeviceLexicalTagger()

    /// The positions, among `words`, of the words that `text` tags as verbs.
    ///
    /// - Parameters:
    ///   - text: The text the words were read from, so that their ranges are offsets of it.
    ///   - language: The language of the text; with none, no word is tagged.
    static func verbs(in text: String, words: [Word], language: Vocabulary.Language?) -> Set<Int> {
        guard let language, !words.isEmpty else { return [] }

        let verbs = tagger.verbs(in: text, language: language)
        return Set(words.indices.filter { index in verbs.contains { $0.contains(words[index].range.lowerBound) } })
    }
}

/// What reads the lexical class of the words of a text.
protocol LexicalTagger: Sendable {
    /// The character offsets, in `text`, of the words it tags as verbs when it reads `text` as `language`.
    func verbs(in text: String, language: Vocabulary.Language) -> [Range<Int>]
}

/// The lexical class of the device's NaturalLanguage framework.
struct DeviceLexicalTagger: LexicalTagger {
    func verbs(in text: String, language: Vocabulary.Language) -> [Range<Int>] {
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(NLLanguage(rawValue: language.rawValue), range: text.startIndex..<text.endIndex)

        var verbs: [Range<Int>] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            if tag == .verb {
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                verbs.append(start..<(start + text.distance(from: range.lowerBound, to: range.upperBound)))
            }
            return true
        }
        return verbs
        #else
        return []
        #endif
    }
}
