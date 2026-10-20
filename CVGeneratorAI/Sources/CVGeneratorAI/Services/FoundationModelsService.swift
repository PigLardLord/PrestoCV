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
                options: GenerationOptions(sampling: .greedy)
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
#endif
