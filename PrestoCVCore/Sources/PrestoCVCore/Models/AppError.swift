import Foundation

// MARK: - Application Errors

public enum AppError: LocalizedError, Equatable, Sendable {
    case fileSystemError(Error)
    case templateNotFound
    case invalidCVData
    case storageError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .templateNotFound:
            return "CV template not found"
        case .invalidCVData:
            return "Invalid CV data format"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
    
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.templateNotFound, .templateNotFound),
             (.invalidCVData, .invalidCVData):
            return true
        case (.fileSystemError(let lhsError), .fileSystemError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.storageError(let lhsMessage), .storageError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}