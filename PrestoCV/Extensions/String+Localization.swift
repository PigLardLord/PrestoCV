import Foundation
import PrestoCVCore

extension String {
    /// Returns the localized version of the string using the String Catalog system
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }
    
    /// Returns a localized string with the provided key from the String Catalog
    static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
    
    /// Returns a localized string with parameters
    static func localizedWithFormat(_ key: String, _ arguments: CVarArg...) -> String {
        let localizedString = String(localized: String.LocalizationValue(key))
        return String(format: localizedString, arguments: arguments)
    }
}

/// Helper function for parametric localization
func LocalizedString(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}

/// Helper function for parametric localization with format arguments
func LocalizedStringWithFormat(_ key: String, _ arguments: CVarArg...) -> String {
    let localizedString = String(localized: String.LocalizationValue(key))
    return String(format: localizedString, arguments: arguments)
}

// MARK: - Error Handling Helpers

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