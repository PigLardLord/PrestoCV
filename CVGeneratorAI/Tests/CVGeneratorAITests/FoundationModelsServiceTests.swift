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

    @Test("An answer that does not parse is generationFailed, which is not tried again: the model writes it again the same (#354)")
    func mapTreatsAnAnswerThatDoesNotParseAsTheModels() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        #expect(FoundationModelsService.isParsingFailure(LanguageModelSession.GenerationError.decodingFailure(context)))
        #expect(FoundationModelsService.map(failure: LanguageModelSession.GenerationError.decodingFailure(context)) == .generationFailed)

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            // What the OS of 2027 throws for an answer cut by its token limit, which was a service failure and was asked again
            let cut = GeneratedContent.ParsingError(rawContent: "{\"technologies\": [\"Exc", debugDescription: "cut")
            #expect(FoundationModelsService.isParsingFailure(cut))
            #expect(FoundationModelsService.map(failure: cut) == .generationFailed)
        }
    }

    @Test("Only an answer that does not parse leaves what the stream wrote before it; a verdict on the answer leaves none")
    func onlyAParsingFailureLeavesAnAnswer() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        #expect(FoundationModelsService.leavesAnAnswer(failure: LanguageModelSession.GenerationError.decodingFailure(context)))
        for verdict: LanguageModelSession.GenerationError in [
            .guardrailViolation(context), .exceededContextWindowSize(context), .rateLimited(context),
        ] {
            #expect(!FoundationModelsService.leavesAnAnswer(failure: verdict))
        }
        #expect(!FoundationModelsService.leavesAnAnswer(failure: NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)))
        #expect(!FoundationModelsService.isParsingFailure(CancellationError()))
    }

    @Test("The second pass's answer lists the skills before the texts, and its token limit is 400 (#354)")
    func writingAnswerPutsTheSkillsFirst() throws {
        let names = ["technologies", "softSkills", "summary", "roles"]
        let data = try JSONEncoder().encode(WritingAnswer.generationSchema)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let declared = object?["x-order"] as? [String] {
            #expect(declared == names)
        } else {
            let schema = String(decoding: data, as: UTF8.self)
            let order = names.map { name in
                schema.range(of: "\"\(name)\"").map { schema.distance(from: schema.startIndex, to: $0.lowerBound) }
            }
            #expect(order.allSatisfy { $0 != nil })
            #expect(order.compactMap { $0 } == order.compactMap { $0 }.sorted())
        }
        #expect(FoundationModelsService.writingTokens == 400)
    }

    @Test("The tools request asks 2 or 3 tools for every job, a job with no lines of its own too (#354, round 5)", arguments: [1, 3])
    func twoOrThreeToolsForEveryJob(count: Int) throws {
        let data = try JSONEncoder().encode(FoundationModelsService.toolsSchema(count: count))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let jobs = try #require((root["properties"] as? [String: Any])?["jobs"] as? [String: Any])
        let entry = try #require((root["$defs"] as? [String: Any])?["JobTools"] as? [String: Any])
        let tools = try #require((entry["properties"] as? [String: Any])?["tools"] as? [String: Any])

        #expect(jobs["minItems"] as? Int == count && jobs["maxItems"] as? Int == count, "one entry for each of \(count) jobs")
        // Allowed none, the request answered none for a job with no lines of its own, and the next one filled it with roles.
        #expect(tools["minItems"] as? Int == 2, "no job goes without tools")
        #expect(tools["maxItems"] as? Int == 3)
    }
}
