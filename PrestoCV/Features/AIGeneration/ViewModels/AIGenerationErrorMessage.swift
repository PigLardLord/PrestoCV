import Foundation
import CVGeneratorAI
import PrestoCVCore

/// The sentence shown when drafting fails.
///
/// Only the kind of failure decides it. The text of an error that came from the system (a domain and a code) is
/// never shown, because the person cannot act on it. An `AppError`, such as a CV that could not be saved, already
/// carries a sentence of the app's own.
enum AIGenerationErrorMessage {

    static func key(for error: Error) -> String {
        switch error as? CVGenerationError {
        case .serviceUnavailable:
            return "ai.unavailable.unknown"
        case .invalidPrompt:
            return "ai.error.empty_description"
        case .descriptionTooLong:
            return "ai.error.too_long"
        case .invalidResponse:
            return "ai.error.empty_result"
        case .timeout, .rateLimitExceeded:
            return "ai.error.busy"
        case .validationFailed, .unknown, nil:
            return "ai.error.failed"
        }
    }

    static func text(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.localizedDescription
        }
        return key(for: error).localized
    }
}
