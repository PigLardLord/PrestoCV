import Testing
import Foundation
@testable import PrestoCVCore

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    // MARK: - AppError Tests
    
    @Test("AppError conforms to Equatable")
    func appErrorConformsToEquatable() {
        let error1 = AppError.unknown("test error")
        let error2 = AppError.unknown("test error")
        let error3 = AppError.unknown("different error")
        let error4 = AppError.invalidData("test error")
        
        #expect(error1 == error2)
        #expect(error1 != error3)
        #expect(error1 != error4)
    }
    
    @Test("AppError provides correct localized descriptions")
    func appErrorProvidesLocalizedDescriptions() {
        let unknownError = AppError.unknown("Something went wrong")
        let invalidDataError = AppError.invalidData("Invalid input data")
        let notFoundError = AppError.notFound("User")
        
        // In test environment, localized strings fall back to their keys
        // since the String Catalog is not available in the Swift Package
        #expect(unknownError.localizedDescription == "Something went wrong")
        #expect(invalidDataError.localizedDescription == "error.invalid_data")
        #expect(notFoundError.localizedDescription == "error.not_found")
    }
    
    @Test("AppError can be converted from generic errors")
    func appErrorCanBeConvertedFromGenericErrors() {
        let genericError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        let appError = AppError.unknown(genericError.localizedDescription)
        
        #expect(appError.localizedDescription == "Generic error")
    }
    
    @Test("AppError.from preserves AppError instances")
    func appErrorFromPreservesAppErrorInstances() {
        let originalAppError = AppError.invalidData("Invalid JSON")
        let preservedError = AppError.from(originalAppError)
        
        #expect(preservedError == originalAppError)
    }
    
    @Test("AppError.from converts generic errors to AppError.unknown")
    func appErrorFromConvertsGenericErrors() {
        let genericError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
        let convertedError = AppError.from(genericError)
        
        if case .unknown(let message) = convertedError {
            #expect(message == "Not found")
        } else {
            #expect(Bool(false), "Expected AppError.unknown")
        }
    }
    
    // MARK: - Additional Edge Case Tests
    
    @Test("AppError handles empty error messages")
    func appErrorHandlesEmptyMessages() {
        let emptyUnknownError = AppError.unknown("")
        let emptyInvalidDataError = AppError.invalidData("")
        let emptyNotFoundError = AppError.notFound("")
        
        // For empty unknown message, it falls back to localized "error.unknown" 
        #expect(emptyUnknownError.localizedDescription == "error.unknown")
        #expect(emptyInvalidDataError.localizedDescription == "error.invalid_data")
        #expect(emptyNotFoundError.localizedDescription == "error.not_found")
    }
    
    @Test("AppError handles nil user info in NSError conversion")
    func appErrorHandlesNilUserInfo() {
        let errorWithoutUserInfo = NSError(domain: "TestDomain", code: 500, userInfo: nil)
        let convertedError = AppError.from(errorWithoutUserInfo)
        
        if case .unknown(let message) = convertedError {
            // Should fall back to a default description
            #expect(!message.isEmpty)
        } else {
            #expect(Bool(false), "Expected AppError.unknown")
        }
    }
    
    @Test("AppError handles extremely long error messages")
    func appErrorHandlesLongMessages() {
        let longMessage = String(repeating: "Very long error message. ", count: 100) // ~2600 characters
        let longError = AppError.unknown(longMessage)
        
        #expect(longError.localizedDescription == longMessage)
    }
    
    @Test("AppError handles special characters in messages")
    func appErrorHandlesSpecialCharacters() {
        let specialMessage = "Error with special chars: 🚫💥 áéíóú ñ ç 中文 日本語 한국어"
        let specialError = AppError.invalidData(specialMessage)
        
        #expect(specialError.localizedDescription == "error.invalid_data")
    }
    
    @Test("AppError equality with different cases")
    func appErrorEqualityDifferentCases() {
        let unknown1 = AppError.unknown("test")
        let unknown2 = AppError.unknown("test")
        let invalidData = AppError.invalidData("test")
        let notFound = AppError.notFound("test")
        
        #expect(unknown1 == unknown2)
        #expect(unknown1 != invalidData)
        #expect(unknown1 != notFound)
        #expect(invalidData != notFound)
        
        // Same type, different messages
        let unknown3 = AppError.unknown("different")
        #expect(unknown1 != unknown3)
    }
}