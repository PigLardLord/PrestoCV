import NaturalLanguage

/// Tells which language a person wrote their description in.
enum DescriptionLanguageDetector {
    /// Below this confidence the language is treated as unknown: a wrong guess would print the
    /// CV's headings in the wrong language, while no guess follows the app's language.
    static let minimumConfidence = 0.6

    /// The BCP 47 tag of the language of `text`, or nil when it cannot tell.
    static func languageTag(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= minimumConfidence else { return nil }
        return language.rawValue
    }
}
