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
            return message
        case .invalidData(let description):
            return "Invalid data: \(description)"
        case .notFound(let item):
            return "\(item) not found"
        case .networkError(let description):
            return "Network error: \(description)"
        case .validationError(let description):
            return "Validation error: \(description)"
        case .decodingError(let description):
            return "Failed to decode data: \(description)"
        case .encodingError(let description):
            return "Failed to encode data: \(description)"
        case .fileSystemError(let description):
            return "File system error: \(description)"
        }
    }
    
    public var localizedDescription: String {
        return errorDescription ?? "An unknown error occurred"
    }
}