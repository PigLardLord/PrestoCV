import Foundation
import PrestoCVCore

// MARK: - Error Localization Helpers

extension Error {
    /// Converts any Error to AppError and returns its localized description
    var localizedAppErrorDescription: String {
        let appError = self as? AppError ?? AppError.unknown(self.localizedDescription)
        return appError.localizedDescription
    }
    
    /// Converts any Error to AppError
    var asAppError: AppError {
        return self as? AppError ?? AppError.unknown(self.localizedDescription)
    }
}