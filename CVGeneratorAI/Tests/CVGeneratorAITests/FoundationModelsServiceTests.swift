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

    @Test("A tools request asks the tools its count says: 6 to 8 of the headline's title, 1 of another (#354, rounds 5, 6 and 13)",
          arguments: [(1...1, 80), (6...8, 180)] as [(ClosedRange<Int>, Int)])
    func toolsOfACount(count: ClosedRange<Int>, tokens: Int) throws {
        let data = try JSONEncoder().encode(FoundationModelsService.toolsSchema(count: count))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tools = try #require((root["properties"] as? [String: Any])?["tools"] as? [String: Any])

        #expect(tools["minItems"] as? Int == count.lowerBound)
        #expect(tools["maxItems"] as? Int == count.upperBound)
        #expect((tools["description"] as? String)?.hasPrefix(SectionPrompts.toolAmount(count) + " ") == true)
        #expect(FoundationModelsService.toolsTokens(most: count.upperBound) == tokens)
    }

    @Test("No tools request the drafting asks is an array of 0 to 1, which the model fails before a word: other titles ask 1 (#354, round 13)",
          arguments: [true, false])
    func toolsOfACountTheModelAnswers(isHeadline: Bool) throws {
        let count = SectionDraft.toolCount(isHeadline: isHeadline)
        let data = try JSONEncoder().encode(FoundationModelsService.toolsSchema(count: count))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tools = try #require((root["properties"] as? [String: Any])?["tools"] as? [String: Any])

        // Every input with a second title threw on its tools request (ModelManagerError 1032) and lost the written draft.
        #expect(!(tools["minItems"] as? Int == 0 && tools["maxItems"] as? Int == 1))
    }

    @Test("o1: a request for tools of one kind asks 0 to 2, so a trade with none of that kind answers none (#354, round 13)")
    func toolsOfAKindSchema() throws {
        let data = try JSONEncoder().encode(FoundationModelsService.toolsOfAKindSchema())
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let tools = try #require((root["properties"] as? [String: Any])?["tools"] as? [String: Any])

        #expect(tools["minItems"] as? Int == 0)
        #expect(tools["maxItems"] as? Int == 2)
        #expect(FoundationModelsService.toolsOfAKindTokens == 80)
        #expect(FoundationModelsService.moreQualitiesTokens(count: 3) == 76)
    }

    @Test("A job's request writes exactly the person's duties and the typical ones the job needs, 1 to 4, and its years only if said (#354, round 10)",
          arguments: [(0, 2, 2), (1, 1, 2), (2, 1, 3), (3, 0, 3), (5, 1, 4), (0, 0, 1)] as [(Int, Int, Int)])
    func dutiesOfAJob(said: Int, adding: Int, duties: Int) throws {
        #expect(FoundationModelsService.jobDuties(said: said, adding: adding) == duties)
        let data = try JSONEncoder().encode(FoundationModelsService.jobSchema(duties: duties))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let properties = try #require(root["properties"] as? [String: Any])
        let list = try #require(properties["duties"] as? [String: Any])

        // Asked for 2 to 4, the request wrote 4 for a job that needed one more, and the extra ones said a duty again.
        #expect(list["minItems"] as? Int == duties)
        #expect(list["maxItems"] as? Int == duties)
        #expect(Set(properties.keys) == ["startYear", "endYear", "duties"])
        #expect((root["required"] as? [String]).map(Set.init) == ["duties"])
    }
}
