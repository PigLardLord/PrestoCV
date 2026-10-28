#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// CV generation service using Apple's FoundationModels
/// Requires iOS 26+ / macOS 26+ and Apple Intelligence-capable device
@MainActor
public final class FoundationModelsService: CVGenerationService {
    /// Where the fixed instructions travel. `.promptPrefix` is the alternative should the
    /// session's instructions misbehave on a device.
    private let instructionsDelivery: InstructionsDelivery = .session

    public init() {}

    public func availability() -> AIAvailability {
        Self.map(SystemLanguageModel.default.availability)
    }

    public func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        if case .unavailable(let reason) = availability() {
            throw CVGenerationError.unavailable(reason)
        }

        let prompt = CVPrompt(request: request, delivery: instructionsDelivery)
        let session = LanguageModelSession(instructions: prompt.instructions)

        do {
            let response = try await session.respond(
                to: prompt.text,
                generating: CVData.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(samplingMode: .greedy)
            )
            return response.content
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The framework stops a cancelled request with an error of its own, not with CancellationError.
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Self.map(failure: error)
        }
    }

    public func writeDraft(for brief: DraftBrief) async throws -> DraftWriting? {
        let prompt = DraftWritingPrompt(brief: brief)
        let session = LanguageModelSession(instructions: prompt.instructions)

        do {
            let response = try await session.respond(
                to: prompt.text,
                generating: WritingAnswer.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: Self.writingTokens)
            )
            return response.content.writing(for: brief)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Self.map(failure: error)
        }
    }

    /// The longest answer of the second pass: a summary, two sentences for each of ten roles and thirteen skills fit well within
    /// it, and a model caught repeating itself stops there instead of filling the window (#354).
    static let writingTokens = 900

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

    /// Translates any failure of a request. One that is no generation error comes from below the model, such as a
    /// system service that refuses to run (`SensitiveContentAnalysisML` in the simulator): the description is not its
    /// cause, and its own text is never shown.
    nonisolated static func map(failure error: any Error) -> CVGenerationError {
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return .serviceFailed
        }
        return map(generationError)
    }

    /// Translates the framework's generation errors into the ones the app explains to the person
    nonisolated static func map(_ error: LanguageModelSession.GenerationError) -> CVGenerationError {
        switch error {
        case .exceededContextWindowSize:
            return .descriptionTooLong
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
            // An unsupported guide is a fault of the app's schema, and a later OS may add errors: neither is the
            // description's
            return .serviceFailed
        }
    }
}

/// The answer of the second pass (ADR 0031), with its lists bounded: the model would otherwise fill a list until its window ends.
@Generable
struct WritingAnswer {
    @Guide(description: "2 to 4 sentences on the person's profession and strengths")
    let summary: String

    @Guide(description: "One entry for each numbered role", .maximumCount(10))
    let roles: [RoleAnswer]

    @Guide(description: "Tools, methods or knowledge of the trade that fit the roles, 1 to 4 words each", .count(4...8))
    let technologies: [String]

    @Guide(description: "Ways of working with people and tasks that fit the roles, 1 to 4 words each", .count(3...5))
    let softSkills: [String]

    func writing(for brief: DraftBrief) -> DraftWriting {
        DraftWriting(
            summary: summary,
            roleDescriptions: DraftWritingPrompt.descriptions(roles.map { (number: $0.number, text: $0.description) }, of: brief),
            technologies: technologies, softSkills: softSkills
        )
    }
}

@Generable
struct RoleAnswer {
    @Guide(description: "The number of the role")
    let number: Int

    @Guide(description: "1 to 2 sentences with the responsibilities typical of the role's title")
    let description: String
}
#endif
