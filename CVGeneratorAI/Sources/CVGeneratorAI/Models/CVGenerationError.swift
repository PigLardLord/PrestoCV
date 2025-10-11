import Foundation

/// Errors that can occur during CV generation
public enum CVGenerationError: Error, Equatable, Sendable {
    /// AI service is not available
    case serviceUnavailable

    /// Invalid or empty user prompt
    case invalidPrompt

    /// AI service returned invalid response
    case invalidResponse

    /// Rate limit exceeded
    case rateLimitExceeded

    /// Generation timeout
    case timeout

    /// Validation failed for generated CV
    case validationFailed(String)

    /// Unknown error
    case unknown(String)
}

extension CVGenerationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "AI service is not available on this device"
        case .invalidPrompt:
            return "Please provide a valid description of your background"
        case .invalidResponse:
            return "Unable to generate CV from the provided information"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later"
        case .timeout:
            return "CV generation timed out. Please try again"
        case .validationFailed(let message):
            return "Generated CV validation failed: \(message)"
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }
}
