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
}