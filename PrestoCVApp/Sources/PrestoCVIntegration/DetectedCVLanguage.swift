import PrestoCVApplication
import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The language of a CV's words, by the application's rule: enough words, one language sure enough (#407). The rule
/// reads every word, so it runs off the main actor (R19).
public struct DetectedCVLanguage: CVLanguageDetecting {
    private let detect: DetectDocumentLanguage

    public init(_ detect: DetectDocumentLanguage) {
        self.detect = detect
    }

    @concurrent public func language(of cv: CV, among languages: [DocumentLanguage]) async -> DocumentLanguage? {
        detect.language(of: cv, among: languages)
    }
}
