import Foundation
import NaturalLanguage
import PrestoCVCore

/// Reads the language of a text with the system's recognizer, for `DocumentLanguageDetector`.
enum NaturalLanguageReader {

    /// The document languages, as the recognizer names them
    private static let documentLanguages = DocumentLanguage.allCases.map { NLLanguage(rawValue: $0.rawValue) }

    /// The language of the text among all the languages the recognizer knows, and how likely each document language
    /// is when the text is read as one of them
    static func read(_ text: String) -> DocumentLanguageDetector.Reading {
        let open = NLLanguageRecognizer()
        open.processString(text)

        let constrained = NLLanguageRecognizer()
        constrained.languageConstraints = documentLanguages
        constrained.processString(text)

        var likelihoods: [DocumentLanguage: Double] = [:]
        for (language, likelihood) in constrained.languageHypotheses(withMaximum: documentLanguages.count) {
            if let documentLanguage = DocumentLanguage(languageTag: language.rawValue) {
                likelihoods[documentLanguage] = likelihood
            }
        }
        return DocumentLanguageDetector.Reading(dominantLanguage: open.dominantLanguage?.rawValue, likelihoods: likelihoods)
    }
}
