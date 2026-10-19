import CVGeneratorAI

/// What the first run and the "New CV" screen offer for AI drafting, given whether the device can run the model now.
enum AIEntry: Equatable {
    /// The AI draft works.
    case available
    /// The AI draft is there but cannot be used yet, with a sentence that says what to do.
    case disabled(Explanation)
    /// No AI draft: the device said why it cannot run the model in words this version does not know, or the release
    /// does not ship AI drafting (`AIFeature.isShipped`).
    case hidden

    enum Explanation: Hashable {
        case turnOnAppleIntelligence
        case modelStillDownloading
        /// This device cannot run the model: the person can still write the CV or start from an example.
        case notOnThisDevice

        /// Catalog key of the sentence shown under the disabled AI draft.
        var key: String {
            switch self {
            case .turnOnAppleIntelligence: return "ai.unavailable.not_enabled"
            case .modelStillDownloading: return "ai.unavailable.model_not_ready"
            case .notOnThisDevice: return "ai.unavailable.not_on_this_device"
            }
        }
    }

    init(availability: AIAvailability, isShipped: Bool = AIFeature.isShipped) {
        guard isShipped else {
            self = .hidden
            return
        }
        switch availability {
        case .available:
            self = .available
        case .unavailable(.appleIntelligenceNotEnabled):
            self = .disabled(.turnOnAppleIntelligence)
        case .unavailable(.modelNotReady):
            self = .disabled(.modelStillDownloading)
        case .unavailable(.deviceNotEligible):
            self = .disabled(.notOnThisDevice)
        case .unavailable(.unknown):
            self = .hidden
        }
    }
}
