import CVGeneratorAI

extension AIAvailability.Reason {
    /// Catalog key of the sentence telling the person why AI drafting cannot run.
    var explanationKey: String {
        switch self {
        case .deviceNotEligible: return "ai.unavailable.device_not_eligible"
        case .appleIntelligenceNotEnabled: return "ai.unavailable.not_enabled"
        case .modelNotReady: return "ai.unavailable.model_not_ready"
        case .unknown: return "ai.unavailable.unknown"
        }
    }
}
