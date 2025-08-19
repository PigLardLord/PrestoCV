import Foundation

// MARK: - Localization Helper

private extension String {
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }
    
    func localizedWithArgs(_ arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

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
            return message.isEmpty ? "error.unknown".localized : message
        case .invalidData(let description):
            return "error.invalid_data".localizedWithArgs(description)
        case .notFound(let item):
            return "error.not_found".localizedWithArgs(item)
        case .networkError(let description):
            return "error.network".localizedWithArgs(description)
        case .validationError(let description):
            return "error.validation".localizedWithArgs(description)
        case .decodingError(let description):
            return "error.decoding".localizedWithArgs(description)
        case .encodingError(let description):
            return "error.encoding".localizedWithArgs(description)
        case .fileSystemError(let description):
            return "error.file_system".localizedWithArgs(description)
        }
    }
    
    public var localizedDescription: String {
        return errorDescription ?? "error.unknown".localized
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