import CVGeneratorAI

extension CVGenerationError {
    /// Catalog key of the sentence telling the person what went wrong.
    ///
    /// The system's own error text is never shown: it is English and written for developers.
    var messageKey: String {
        switch self {
        case .unavailable(let reason): return reason.explanationKey
        case .descriptionTooShort: return "ai.error.too_short"
        case .descriptionTooLong: return "ai.error.too_long"
        case .contentNotAllowed: return "ai.error.content_not_allowed"
        case .unsupportedLanguage: return "ai.error.unsupported_language"
        case .busy: return "ai.error.busy"
        case .generationFailed: return "ai.error.failed"
        // A failure of the system is not the description's: the neutral sentence asks for nothing
        case .serviceFailed: return "ai.unavailable.unknown"
        case .emptyResult: return "ai.error.empty_result"
        }
    }
}
