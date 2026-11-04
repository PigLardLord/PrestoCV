import Testing
import CVGeneratorAI
@testable import PrestoCV

@Suite("CVGenerationError message Tests - what the AI screen says for each error, on the iPhone or iPad and on the Mac")
struct CVGenerationErrorMessageTests {

    /// The errors whose words do not depend on the platform.
    private static let sameEverywhere: [(CVGenerationError, String)] = [
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

    /// Every error on every platform, with the key of its message.
    private static let table: [(CVGenerationError, AIPlatform, String)] =
        AIPlatform.allCases.flatMap { platform in sameEverywhere.map { ($0.0, platform, $0.1) } } + [
            (.unavailable(.appleIntelligenceNotEnabled), .iPhoneOrIPad, "ai.unavailable.not_enabled"),
            (.unavailable(.deviceNotEligible), .iPhoneOrIPad, "ai.unavailable.not_on_this_device"),
            // Every Mac that runs the app can run Apple Intelligence: it is turned on in System Settings
            (.unavailable(.appleIntelligenceNotEnabled), .mac, "ai.unavailable.not_enabled.mac"),
            (.unavailable(.deviceNotEligible), .mac, "ai.unavailable.not_enabled.mac"),
        ]

    @Test("Each error maps to its message key on each platform", arguments: table)
    func errorMapsToKey(error: CVGenerationError, platform: AIPlatform, key: String) {
        #expect(error.messageKey(on: platform) == key)
    }

    @Test("An unavailable model is explained as the AI entry explains it", arguments: [
        AIAvailability.Reason.modelNotReady, .appleIntelligenceNotEnabled, .deviceNotEligible, .unknown,
    ], AIPlatform.allCases)
    func unavailableMatchesTheEntry(reason: AIAvailability.Reason, platform: AIPlatform) {
        let entry = AIEntry(availability: .unavailable(reason), platform: platform, isShipped: true)

        #expect(CVGenerationError.unavailable(reason).messageKey(on: platform) == entry.explanationKey)
    }

    @Test("A Mac never reads the wording of an iPhone", arguments: table.filter { $0.1 == .mac })
    func theMacReadsNoIPhoneWording(error: CVGenerationError, platform: AIPlatform, key: String) {
        #expect(key != "ai.unavailable.not_on_this_device")
        #expect(key != "ai.unavailable.not_enabled")
    }

    @Test("Every message is in the string catalog", arguments: table)
    func messageIsTranslated(error: CVGenerationError, platform: AIPlatform, key: String) {
        #expect(key.localized != key, "\(key) is missing from the string catalog")
    }
}
