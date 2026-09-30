// MARK: - Errors

/// Why no draft came back. Cancellation is not one of them: it ends in `CancellationError`.
public enum DraftingError: Error, Hashable, Sendable {
    // The request
    case descriptionTooShort, descriptionTooLong
    /// The language is not a BCP 47 tag, or the model does not support it.
    case unsupportedLanguage
    case unavailable(DraftAvailability.Reason)

    // The model, one case per failure it reports
    case contextWindowExceeded, assetsUnavailable, guardrailViolation, refusal, decodingFailure, rateLimited, concurrentRequests
    /// Any other failure of the model or of its adapter.
    case generationFailed

    // The draft
    /// The draft holds no text: it is never handed on as a CV.
    case emptyDraft
    /// A text or a list in the draft is over its limit.
    case oversizedDraft
}
