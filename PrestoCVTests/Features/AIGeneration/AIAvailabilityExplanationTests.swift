import Testing
import CVGeneratorAI
@testable import PrestoCV

@Suite("AIAvailability explanation Tests")
struct AIAvailabilityExplanationTests {

    @Test("Every reason has an explanation in the string catalog", arguments: [
        AIAvailability.Reason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
        .unknown,
    ])
    func explanationIsTranslated(reason: AIAvailability.Reason) {
        let key = reason.explanationKey
        #expect(key.localized != key, "\(key) is missing from the string catalog")
    }

    @Test("Each reason points at its own key")
    func explanationKeysAreDistinct() {
        let reasons: [AIAvailability.Reason] = [.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unknown]
        #expect(Set(reasons.map(\.explanationKey)).count == reasons.count)
    }
}
