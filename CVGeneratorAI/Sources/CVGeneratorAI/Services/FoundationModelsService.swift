#if canImport(FoundationModels)
import DiagnosticTrace
import Foundation
import FoundationModels

/// CV generation service using Apple's FoundationModels
/// Requires iOS 26+ / macOS 26+ and Apple Intelligence-capable device
@MainActor
public final class FoundationModelsService: CVGenerationService {
    /// Where the fixed instructions travel. `.promptPrefix` is the alternative should the
    /// session's instructions misbehave on a device.
    private let instructionsDelivery: InstructionsDelivery = .session
    /// Read by the requests of the sections too (`SectionWriting`).
    let tracer: any DiagnosticTracer

    /// - Parameter tracer: Where the request to the model and its raw answer are recorded, in the open run of the draft (ADR 0032).
    public init(tracer: any DiagnosticTracer) {
        self.tracer = tracer
    }

    public func availability() -> AIAvailability {
        Self.map(SystemLanguageModel.default.availability)
    }

    public func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        if case .unavailable(let reason) = availability() {
            throw CVGenerationError.unavailable(reason)
        }

        let prompt = CVPrompt(request: request, delivery: instructionsDelivery)
        do {
            for sampling in Self.factsSampling {
                if let facts = try await facts(for: prompt, sampling: sampling) { return facts }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as CVGenerationError {
            throw failure
        } catch {
            // The framework stops a cancelled request with an error of its own, not with CancellationError.
            if Task.isCancelled {
                throw CancellationError()
            }
            let failure = Self.map(failure: error)
            tracer.record(.response, into: .aiDraft) {
                [
                    .token("call", "draft"), .flag("answered", false), .token("error", "\(failure.logCode)"),
                    .text("framework", String(describing: error)),
                ]
            }
            throw failure
        }
        throw CVGenerationError.generationFailed
    }

    /// How the first pass samples its answer, once and, when the streamed answer repeats, once more (#354). Greedy sampling gives the
    /// best facts of the evaluation, and can loop on one sentence of a description; a fresh session that samples among the five likeliest
    /// tokens wrote each answer of jobs-de with no loop. The seed is any fixed one, so that a description is drafted the same each time.
    nonisolated static let factsSampling = [
        FactsSampling(mode: .greedy, name: "greedy"), FactsSampling(mode: .random(top: 5, seed: 1), name: "top5"),
    ]

    /// One way of sampling the first pass, with the name the trace gives it.
    struct FactsSampling: Sendable {
        let mode: GenerationOptions.SamplingMode
        let name: String
    }

    /// Whether the draft's requests stream their answers: on iOS 27 and macOS 27 only. Streamed, the first pass is stopped where it
    /// repeats (`RepeatingAnswer`), and a section's answer cut by its token cap keeps its whole parts (`StreamedAnswer`).
    /// The framework of iOS 26 and macOS 26 streams a structured answer about three times slower than it answers it whole, even with
    /// the watch's checks made trivial: en-plain took 26 s answered whole on macOS 26, and streamed it failed the 90 s of
    /// `DraftingLimits`; its sections, streamed, failed their 30 s (#354). There every request asks for its whole answer: a first pass
    /// that loops ends with its limit, and a section cut by its cap is lost as a failed request.
    nonisolated static var streamsAnswers: Bool {
        if #available(iOS 27, macOS 27, *) { return true }
        return false
    }

    /// The facts of the description, asked in a fresh session: nil when the streamed answer repeats one stretch
    /// (`RepeatingAnswer`), which is stopped there.
    ///
    /// - Throws: `CVGenerationError.generationFailed` when the stream ends with no answer, and what the request throws.
    private func facts(for prompt: CVPrompt, sampling: FactsSampling) async throws -> CVData? {
        tracer.record(.request, into: .aiDraft) { prompt.traceFields(sampling: sampling.name) }
        let session = LanguageModelSession(instructions: prompt.instructions)
        let options = GenerationOptions(samplingMode: sampling.mode)
        guard Self.streamsAnswers else {
            let response = try await session.respond(to: prompt.text, generating: CVData.self, includeSchemaInPrompt: true, options: options)
            tracer.record(.response, into: .aiDraft) {
                [.token("call", "draft"), .flag("answered", true), .text("raw", response.rawContent.jsonString)]
            }
            return response.content
        }
        let stream = session.streamResponse(to: prompt.text, generating: CVData.self, includeSchemaInPrompt: true, options: options)
        let watched = try await RepeatingAnswer.watch(
            stream, texts: { $0.rawContent.texts }, length: { $0.rawContent.jsonString.utf8.count }
        )
        try Task.checkCancellation()
        guard let watched else {
            tracer.record(.response, into: .aiDraft) { [.token("call", "draft"), .flag("answered", false), .token("error", "noAnswer")] }
            throw CVGenerationError.generationFailed
        }
        let raw = watched.answer.rawContent
        guard !watched.repeats else {
            tracer.record(.response, into: .aiDraft) {
                [.token("call", "draft"), .flag("answered", false), .token("error", "repeating"), .text("raw", raw.jsonString)]
            }
            return nil
        }
        tracer.record(.response, into: .aiDraft) { [.token("call", "draft"), .flag("answered", true), .text("raw", raw.jsonString)] }
        return try CVData(raw)
    }

    /// The second pass (ADR 0031), streamed: an answer cut by its token limit keeps what the model wrote before the cut
    /// (`StreamedAnswer`, `WritingSnapshot`), and is not asked again, since greedy sampling would write it again the same (#354).
    public func writeDraft(for brief: DraftBrief) async throws -> DraftWriting? {
        let prompt = DraftWritingPrompt(brief: brief)
        let session = LanguageModelSession(instructions: prompt.instructions)

        do {
            let stream = session.streamResponse(
                to: prompt.text,
                generating: WritingAnswer.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: Self.writingTokens)
            )
            let last = try await StreamedAnswer.last(of: stream, keepingPartialAfter: Self.leavesAnAnswer(failure:))
            return last.map { $0.answer.content.snapshot.writing(for: brief, isComplete: $0.isComplete) }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Self.map(failure: error)
        }
    }

    /// The longest answer of the second pass. A good answer is about 100 to 350 tokens; the model pads the last text of an answer
    /// with spaces and brackets up to the limit, so a higher limit only makes a padded answer slower (#354): at 400 tokens it stops
    /// after about 8 seconds, with the skills and the summary written before the roles.
    nonisolated static let writingTokens = 400

    /// Whether the second pass's stream, failing after it has started its answer, leaves the answer so far to keep: an answer cut by the
    /// token limit fails to parse as a whole, and what came before the cut was written as any other answer. A refusal, a guardrail or a
    /// window that overflows is the model's verdict on the whole answer, and keeps none of it.
    nonisolated static func leavesAnAnswer(failure error: any Error) -> Bool {
        isParsingFailure(error)
    }

    /// Whether `error` says the model's answer does not parse as the schema asks: `GeneratedContent.ParsingError` since the OS of 2027,
    /// `GenerationError.decodingFailure` before.
    nonisolated static func isParsingFailure(_ error: any Error) -> Bool {
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), error is GeneratedContent.ParsingError { return true }
        guard let generationError = error as? LanguageModelSession.GenerationError, case .decodingFailure = generationError else { return false }
        return true
    }

    // MARK: - Mapping

    /// Translates the framework's availability, keeping any reason a later OS adds as `.unknown`
    nonisolated static func map(_ availability: SystemLanguageModel.Availability) -> AIAvailability {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(.modelNotReady)
            @unknown default:
                return .unavailable(.unknown)
            }
        @unknown default:
            return .unavailable(.unknown)
        }
    }

    /// Translates any failure of a request. An answer that does not parse is the model's, which greedy sampling writes again the
    /// same: it is `generationFailed`, which is not tried again (#354). Any other failure that is no generation error comes from below
    /// the model, such as a system service that refuses to run (`SensitiveContentAnalysisML` in the simulator): the description is not
    /// its cause, and its own text is never shown.
    nonisolated static func map(failure error: any Error) -> CVGenerationError {
        if isParsingFailure(error) { return .generationFailed }
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return .serviceFailed
        }
        return map(generationError)
    }

    /// Translates the framework's generation errors into the ones the app explains to the person
    nonisolated static func map(_ error: LanguageModelSession.GenerationError) -> CVGenerationError {
        switch error {
        case .guardrailViolation, .refusal:
            return .contentNotAllowed
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguage
        case .assetsUnavailable:
            return .unavailable(.modelNotReady)
        case .rateLimited, .concurrentRequests:
            return .busy
        case .decodingFailure:
            return .generationFailed
        default:
            // A full context window is the app's own instructions and schema filling it, not a long description (that is
            // the validator's `descriptionTooLong`); an unsupported guide is a fault of the app's schema, and a later OS may
            // add errors: none is the description's
            return .serviceFailed
        }
    }
}

/// The answer of the second pass (ADR 0031), with its lists bounded: the model would otherwise fill a list until its window ends.
///
/// The skills come first: the model pads the last text of its answer up to the token limit, and a cut answer keeps the parts before
/// the cut (#354). Short lists of short names are the parts the model never pads.
@Generable
struct WritingAnswer {
    @Guide(description: "Tools, methods or techniques of the trade that fit the roles, 1 to 4 words each", .count(4...8))
    let technologies: [String]

    @Guide(description: "Ways of working with people and tasks that fit the roles, 1 to 4 words each", .count(3...5))
    let softSkills: [String]

    @Guide(description: "2 to 4 sentences on the person's profession and strengths")
    let summary: String

    @Guide(description: "One entry for each numbered role", .maximumCount(10))
    let roles: [RoleAnswer]
}

extension WritingAnswer.PartiallyGenerated {
    /// What the model had written of the answer, as plain values.
    var snapshot: WritingSnapshot {
        WritingSnapshot(
            technologies: technologies, softSkills: softSkills, summary: summary,
            roles: roles?.map { WritingSnapshot.Role(number: $0.number, text: $0.description) }
        )
    }
}

extension GeneratedContent {
    /// The texts of an answer, as `RepeatingAnswer` reads them: each string, and each list as one text with an item a line, its items
    /// also on their own.
    fileprivate var texts: [String] {
        switch kind {
        case .string(let text): [text]
        case .array(let items): [items.map { $0.jsonString + "\n" }.joined()] + items.flatMap(\.texts)
        case .structure(let properties, _): properties.values.flatMap(\.texts)
        case .null, .bool, .number: []
        @unknown default: []
        }
    }
}

@Generable
struct RoleAnswer {
    @Guide(description: "The number of the role")
    let number: Int

    @Guide(description: "1 to 2 sentences with the responsibilities typical of the role's title at its employer")
    let description: String
}
#endif
