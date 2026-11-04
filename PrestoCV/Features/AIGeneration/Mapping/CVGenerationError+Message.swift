import CVGeneratorAI

extension CVGenerationError {
    /// Catalog key of the sentence telling the person what went wrong on `platform`. An unavailable model is explained
    /// as the AI entry explains it, so a Mac never reads the wording of an iPhone.
    ///
    /// The system's own error text is never shown: it is English and written for developers.
    func messageKey(on platform: AIPlatform) -> String {
        switch self {
        case .unavailable(let reason): return AIEntry.Reason(reason, platform: platform).explanationKey
        case .descriptionTooShort: return "ai.error.too_short"
        case .descriptionTooLong: return "ai.error.too_long"
        case .contentNotAllowed: return "ai.error.content_not_allowed"
        case .unsupportedLanguage: return "ai.error.unsupported_language"
        case .busy: return "ai.error.busy"
        case .generationFailed: return "ai.error.failed"
        // A failure of the system is not the description's: the neutral sentence asks for nothing
        case .serviceFailed: return "ai.unavailable.unknown"
        case .emptyResult: return "ai.error.empty_result"
        case .languageDataUnavailable: return "ai.unavailable.language_data_not_ready"
        }
    }
}
