#if canImport(NaturalLanguage)
import Foundation
import NaturalLanguage
import PrestoCVApplication
import PrestoCVDomain

/// Reads which language a text is written in with the system's recognizer (#407). It reads the text twice: once among
/// every language the recognizer knows, for the language it finds on its own, and once among the languages it is given
/// only, for how likely each of them is. The rule that decides is `DetectDocumentLanguage`.
///
/// A language is given to the recognizer by its tag, as the recognizer names languages ("it", "de"); a tag it does not
/// know gets no likelihood.
public struct NaturalLanguageTextReader: TextLanguageReading {
    public init() {}

    public func reading(of text: String, among languages: [DocumentLanguage]) -> LanguageReading {
        let open = NLLanguageRecognizer()
        open.processString(text)

        var likelihoods: [DocumentLanguage: Double] = [:]
        if !languages.isEmpty {
            let constrained = NLLanguageRecognizer()
            constrained.languageConstraints = languages.map { NLLanguage(rawValue: $0.tag) }
            constrained.processString(text)
            let hypotheses = constrained.languageHypotheses(withMaximum: languages.count)
            for language in languages {
                likelihoods[language] = hypotheses[NLLanguage(rawValue: language.tag)]
            }
        }
        return LanguageReading(dominant: Self.found(open.dominantLanguage), likelihoods: likelihoods)
    }

    /// The language the recognizer finds on its own; nil when it finds none or calls the text undetermined ("und").
    static func found(_ language: NLLanguage?) -> DocumentLanguage? {
        guard let language, language != .undetermined else { return nil }
        return DocumentLanguage(language.rawValue)
    }
}
#endif
