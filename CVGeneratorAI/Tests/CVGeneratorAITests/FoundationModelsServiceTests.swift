import Testing
import FoundationModels
@testable import CVGeneratorAI

@Suite("FoundationModelsService Tests")
struct FoundationModelsServiceTests {

    @Test("map translates every availability the framework reports")
    func mapTranslatesAvailability() {
        let cases: [(SystemLanguageModel.Availability, AIAvailability)] = [
            (.available, .available),
            (.unavailable(.deviceNotEligible), .unavailable(.deviceNotEligible)),
            (.unavailable(.appleIntelligenceNotEnabled), .unavailable(.appleIntelligenceNotEnabled)),
            (.unavailable(.modelNotReady), .unavailable(.modelNotReady)),
        ]

        for (framework, expected) in cases {
            #expect(FoundationModelsService.map(framework) == expected)
        }
    }
}
