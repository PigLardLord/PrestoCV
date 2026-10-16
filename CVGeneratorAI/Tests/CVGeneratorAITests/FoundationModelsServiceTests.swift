import Testing
import Foundation
import FoundationModels
@testable import CVGeneratorAI

@Suite("FoundationModelsService Tests")
struct FoundationModelsServiceTests {
    @Test("map translates every framework availability")
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

    @Test("map turns the framework's generation errors into the errors the app explains")
    func mapTranslatesGenerationErrors() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        let cases: [(LanguageModelSession.GenerationError, CVGenerationError)] = [
            (.exceededContextWindowSize(context), .descriptionTooLong),
            (.guardrailViolation(context), .contentNotAllowed),
            (.unsupportedLanguageOrLocale(context), .unsupportedLanguage),
            (.assetsUnavailable(context), .unavailable(.modelNotReady)),
            (.rateLimited(context), .busy),
            (.concurrentRequests(context), .busy),
            (.decodingFailure(context), .generationFailed),
            (.unsupportedGuide(context), .serviceFailed),
        ]

        for (framework, expected) in cases {
            #expect(FoundationModelsService.map(framework) == expected)
        }
    }

    @Test("A failure from below the model is a service failure, which does not blame the description")
    func mapTreatsOtherFailuresAsServiceFailures() {
        // What the simulator answers when its guardrail cannot run: an error of a system service, not a verdict on the text
        let systemRefusal = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)

        #expect(FoundationModelsService.map(failure: systemRefusal) == .serviceFailed)
    }

    @Test("A generation error keeps its own meaning when it is the failure of a request")
    func mapKeepsGenerationErrorsOfARequest() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        let cases: [(LanguageModelSession.GenerationError, CVGenerationError)] = [
            (.guardrailViolation(context), .contentNotAllowed),
            (.exceededContextWindowSize(context), .descriptionTooLong),
            (.decodingFailure(context), .generationFailed),
        ]

        for (framework, expected) in cases {
            #expect(FoundationModelsService.map(failure: framework) == expected)
        }
    }
}
