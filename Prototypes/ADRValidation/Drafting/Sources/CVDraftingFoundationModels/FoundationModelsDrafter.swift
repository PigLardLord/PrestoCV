#if canImport(FoundationModels)
import FoundationModels
import CVDrafting

public enum DraftingUnavailable: Error { case notImplementedInPrototype }

/// Adapter: @Generable schema types would live here, internal, never leaving the target.
public struct FoundationModelsDrafter: DraftGenerating {
    public init() {}
    public func availability() async -> DraftAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.appleIntelligenceNotEnabled): .appleIntelligenceDisabled
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable: .modelNotReady
        }
    }
    /// Not implemented in the prototype: never return an empty draft as if it were a result (R14).
    public func draft(from description: String, language: String) async throws -> CVDraft {
        throw DraftingUnavailable.notImplementedInPrototype
    }
}
#endif
