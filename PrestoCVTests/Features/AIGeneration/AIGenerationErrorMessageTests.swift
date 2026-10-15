import Testing
import Foundation
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

@Suite("AIGenerationErrorMessage Tests - a failed draft is explained in words, never by a system error")
struct AIGenerationErrorMessageTests {

    @Test("Each kind of failure has its own sentence")
    func eachKindHasASentence() {
        let expected: [(CVGenerationError, String)] = [
            (.serviceUnavailable, "ai.unavailable.unknown"),
            (.invalidPrompt, "ai.error.empty_description"),
            (.descriptionTooLong, "ai.error.too_long"),
            (.invalidResponse, "ai.error.empty_result"),
            (.timeout, "ai.error.busy"),
            (.rateLimitExceeded, "ai.error.busy"),
            (.validationFailed("Generated CV validation failed"), "ai.error.failed"),
            (.unknown("anything"), "ai.error.failed"),
        ]

        for (error, key) in expected {
            #expect(AIGenerationErrorMessage.key(for: error) == key, "\(error)")
        }
    }

    @Test("An error from the system gets the general sentence")
    func systemErrorGetsTheGeneralSentence() {
        let error = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)

        #expect(AIGenerationErrorMessage.key(for: error) == "ai.error.failed")
    }

    @Test("The text of a failure never carries the domain or the code of a system error")
    func textNeverCarriesTheSystemError() {
        let raw = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)
        let errors: [Error] = [
            raw,
            CVGenerationError.unknown("Failed to generate CV: \(raw.localizedDescription)"),
            CVGenerationError.validationFailed(raw.localizedDescription),
        ]

        for error in errors {
            let message = AIGenerationErrorMessage.text(for: error)

            #expect(!message.contains("com.apple"), "\(message)")
            #expect(!message.contains("error 15"), "\(message)")
            #expect(!message.contains("operation couldn"), "\(message)")
            #expect(message == "ai.error.failed".localized)
        }
    }

    @Test("A CV that could not be saved is explained by the app's own sentence for it")
    func appErrorKeepsItsOwnSentence() {
        let error = AppError.fileSystemError("disk full")

        #expect(AIGenerationErrorMessage.text(for: error) == error.localizedDescription)
        #expect(AIGenerationErrorMessage.text(for: error).contains("disk full"))
    }

    @Test("Every sentence is looked up in the catalog")
    func everySentenceIsLocalized() {
        let keys = [
            "ai.unavailable.unknown", "ai.error.empty_description", "ai.error.too_long",
            "ai.error.empty_result", "ai.error.busy", "ai.error.failed",
        ]

        for key in keys {
            #expect(key.localized != key, "\(key) has no text")
        }
    }
}
