import NaturalLanguage

/// The language detector that the app hands to the sanitizer (the package cannot import the app). `DraftingInputsTests` pins its
/// answer for every input of the drafting evaluation.
enum AppLanguageDetector {
    static let minimumConfidence = 0.6

    static func languageTag(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= minimumConfidence else { return nil }
        return language.rawValue
    }
}
