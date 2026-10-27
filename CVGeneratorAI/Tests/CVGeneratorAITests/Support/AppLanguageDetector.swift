import NaturalLanguage

/// A copy of the app's `DescriptionLanguageDetector` (PrestoCV/Features/AIGeneration/Mapping/DescriptionLanguageDetector.swift),
/// which the app hands to the sanitizer: the package cannot import the app. `DraftingInputsTests` checks that its lines are the
/// app's and pins its answer for every input of the drafting evaluation, so a copy that drifts fails there.
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
