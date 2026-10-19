import Testing
import CVGeneratorAI
@testable import PrestoCV

@Suite("CVGenerationError message Tests")
struct CVGenerationErrorMessageTests {

    private static let errors: [(CVGenerationError, String)] = [
        (.unavailable(.deviceNotEligible), "ai.unavailable.device_not_eligible"),
        (.unavailable(.appleIntelligenceNotEnabled), "ai.unavailable.not_enabled"),
        (.unavailable(.modelNotReady), "ai.unavailable.model_not_ready"),
        (.unavailable(.unknown), "ai.unavailable.unknown"),
        (.descriptionTooShort, "ai.error.too_short"),
        (.descriptionTooLong, "ai.error.too_long"),
        (.contentNotAllowed, "ai.error.content_not_allowed"),
        (.unsupportedLanguage, "ai.error.unsupported_language"),
        (.busy, "ai.error.busy"),
        (.generationFailed, "ai.error.failed"),
        (.serviceFailed, "ai.unavailable.unknown"),
        (.emptyResult, "ai.error.empty_result"),
        (.languageDataUnavailable(languageCode: "en"), "ai.unavailable.language_data_not_ready"),
    ]

    @Test("Each error maps to its message key", arguments: errors)
    func errorMapsToKey(error: CVGenerationError, key: String) {
        #expect(error.messageKey == key)
    }

    @Test("Every message is in the string catalog", arguments: errors)
    func messageIsTranslated(error: CVGenerationError, key: String) {
        #expect(key.localized != key, "\(key) is missing from the string catalog")
    }
}
