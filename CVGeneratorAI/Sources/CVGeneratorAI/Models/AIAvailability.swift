/// Whether on-device generation can run now and, when it cannot, why.
///
/// It mirrors the framework's availability without importing it, so callers and tests
/// do not need Apple Intelligence to reason about it.
public enum AIAvailability: Equatable, Sendable {
    case available
    case unavailable(Reason)

    public enum Reason: Equatable, Sendable {
        /// This device can never run the feature.
        case deviceNotEligible
        /// The device could run it, but Apple Intelligence is turned off.
        case appleIntelligenceNotEnabled
        /// Apple Intelligence is on, but the model is still downloading or preparing.
        case modelNotReady
        /// The framework gave a reason this version does not know.
        case unknown
    }
}
