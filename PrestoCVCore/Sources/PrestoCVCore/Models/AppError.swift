import Foundation

// MARK: - App Error Definition

public enum AppError: Error, LocalizedError, Equatable, Sendable {
    case unknown(String)  // Changed from Error to String for Equatable
    case invalidData(String)
    case notFound(String)
    case networkError(String)
    case validationError(String)
    case decodingError(String)
    case encodingError(String)
    case fileSystemError(String)
    
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidData(let lhsMessage), .invalidData(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.notFound(let lhsMessage), .notFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.validationError(let lhsMessage), .validationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.decodingError(let lhsMessage), .decodingError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.encodingError(let lhsMessage), .encodingError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.fileSystemError(let lhsMessage), .fileSystemError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .unknown(let message):
            return message.isEmpty ? String(localized: "error.unknown") : message
        case .invalidData(let description):
            let localizedTemplate = String(localized: "error.invalid_data")
            return String(format: localizedTemplate, description)
        case .notFound(let item):
            let localizedTemplate = String(localized: "error.not_found")
            return String(format: localizedTemplate, item)
        case .networkError(let description):
            let localizedTemplate = String(localized: "error.network")
            return String(format: localizedTemplate, description)
        case .validationError(let description):
            let localizedTemplate = String(localized: "error.validation")
            return String(format: localizedTemplate, description)
        case .decodingError(let description):
            let localizedTemplate = String(localized: "error.decoding")
            return String(format: localizedTemplate, description)
        case .encodingError(let description):
            let localizedTemplate = String(localized: "error.encoding")
            return String(format: localizedTemplate, description)
        case .fileSystemError(let description):
            let localizedTemplate = String(localized: "error.file_system")
            return String(format: localizedTemplate, description)
        }
    }
    
    public var localizedDescription: String {
        return errorDescription ?? String(localized: "error.unknown")
    }
}

// MARK: - Error Conversion Helpers

extension AppError {
    /// Converts a generic error to AppError, preserving AppError instances
    /// - Parameter error: The error to convert
    /// - Returns: AppError instance
    public static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        } else {
            return AppError.unknown(error.localizedDescription)
        }
    }
}