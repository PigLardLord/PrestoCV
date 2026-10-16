import Foundation

/// Why generating a CV failed.
///
/// Cases say what happened, not what to tell the person; the app maps each one to its own
/// localised text. Cancellation is never an error: it surfaces as `CancellationError`.
public enum CVGenerationError: Error, Equatable, Sendable {
    /// The model cannot run now, for the given reason
    case unavailable(AIAvailability.Reason)

    /// The description is too short to draft anything from
    case descriptionTooShort

    /// The description is longer than the limit, or than the model can take
    case descriptionTooLong

    /// The model declined the text
    case contentNotAllowed

    /// The model does not support the language of the description
    case unsupportedLanguage

    /// The model is serving another request
    case busy

    /// The model answered the description, but its answer could not be used
    case generationFailed

    /// A system service failed around the model, or the framework failed in a way this version does not know: the
    /// description is not the cause
    case serviceFailed

    /// The model answered, but nothing usable was left once the unsupported parts were removed
    case emptyResult
}
