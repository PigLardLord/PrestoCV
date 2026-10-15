import CVGeneratorAI

/// What the "New CV" screen offers for AI drafting, given whether the device can run the model now.
enum AIEntry: Equatable {
    /// The card works.
    case available
    /// The card is there but cannot be used yet, with a sentence that says what to do.
    case disabled(Explanation)
    /// No card: this device cannot run the model, or it said why in words this version does not know.
    case hidden

    enum Explanation: Equatable {
        case turnOnAppleIntelligence
        case modelStillDownloading

        /// Catalog key of the sentence shown under the disabled card.
        var key: String {
            switch self {
            case .turnOnAppleIntelligence: return "ai.unavailable.not_enabled"
            case .modelStillDownloading: return "ai.unavailable.model_not_ready"
            }
        }
    }

    init(availability: AIAvailability) {
        switch availability {
        case .available:
            self = .available
        case .unavailable(.appleIntelligenceNotEnabled):
            self = .disabled(.turnOnAppleIntelligence)
        case .unavailable(.modelNotReady):
            self = .disabled(.modelStillDownloading)
        case .unavailable(.deviceNotEligible), .unavailable(.unknown):
            self = .hidden
        }
    }
}
