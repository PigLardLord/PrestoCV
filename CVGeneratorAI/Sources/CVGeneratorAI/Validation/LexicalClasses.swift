import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Which words of a text the device's lexical class tells are verbs (ADR 0023, rule (c)), contractions included ("I'm" is "I" and
/// "'m"). Whether a device tags a language depends on the language data it has downloaded, so grounding asks it only where the
/// contract holds with its tags, English and German (`VerbForms.readsVerbsByTags`), and grounds a description in either only on a
/// device that tags its language: without the tags a wish, a plan or another person's statement would read as the person's fact, so
/// the sanitiser throws `CVGenerationError.languageDataUnavailable` instead. In Italian, Spanish, French and Portuguese no word is
/// tagged on any device, whatever its data, and `VerbForms` reads their verbs. So a description gives the same draft on every device
/// that grounds it.
enum LexicalClasses {
    /// What tags the words: the sanitiser's tagger while it grounds a description, the device's framework elsewhere. A test gives
    /// another verdict for the task it runs, with `$tagger.withValue`.
    @TaskLocal static var tagger: any LexicalTagger = DeviceLexicalTagger()

    /// The positions, among `words`, of the words that `text` tags as verbs.
    ///
    /// - Parameters:
    ///   - text: The text the words were read from, so that their ranges are offsets of it.
    ///   - language: The language of the text; with none, or in Italian, Spanish, French or Portuguese, no word is tagged.
    static func verbs(in text: String, words: [Word], language: Vocabulary.Language?) -> Set<Int> {
        guard let language, VerbForms.readsVerbsByTags(in: language), !words.isEmpty else { return [] }

        let verbs = tagger.verbs(in: text, language: language.rawValue)
        return Set(words.indices.filter { index in verbs.contains { $0.contains(words[index].range.lowerBound) } })
    }
}

/// What tells the lexical class of the words of a text: in the app, the device's NaturalLanguage framework (`DeviceLexicalTagger`).
/// A language is a BCP 47 primary language code: "en", "de".
public protocol LexicalTagger: Sendable {
    /// Whether it tells the lexical class of the words of `language`.
    func tagsLexicalClass(inLanguage language: String) -> Bool
    /// The character offsets, in `text`, of the words it tags as verbs when it reads `text` in `language`.
    func verbs(in text: String, language: String) -> [Range<Int>]
}

/// The lexical class of the device's NaturalLanguage framework. It tags a language only once the device has the language's data,
/// which is when `NLTagger.availableTagSchemes` lists the lexical class for it.
public struct DeviceLexicalTagger: LexicalTagger {
    public init() {}

    public func tagsLexicalClass(inLanguage language: String) -> Bool {
        #if canImport(NaturalLanguage)
        NLTagger.availableTagSchemes(for: .word, language: NLLanguage(rawValue: language)).contains(.lexicalClass)
        #else
        false
        #endif
    }

    public func verbs(in text: String, language: String) -> [Range<Int>] {
        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(NLLanguage(rawValue: language), range: text.startIndex..<text.endIndex)

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
