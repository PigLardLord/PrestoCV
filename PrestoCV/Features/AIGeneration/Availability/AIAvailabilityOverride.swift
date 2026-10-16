#if DEBUG
import Foundation
import CVGeneratorAI

/// Debug launch argument that forces the availability the app reports, for screenshots and UI tests.
///
/// Pass `-AIAvailabilityOverride <value>` with one of `available`, `deviceNotEligible`,
/// `appleIntelligenceNotEnabled`, `modelNotReady` or `unknown`. Release builds do not read it.
enum AIAvailabilityOverride {
    static let launchArgument = "AIAvailabilityOverride"

    static func availability(for value: String?) -> AIAvailability? {
        switch value {
        case "available": return .available
        case "deviceNotEligible": return .unavailable(.deviceNotEligible)
        case "appleIntelligenceNotEnabled": return .unavailable(.appleIntelligenceNotEnabled)
        case "modelNotReady": return .unavailable(.modelNotReady)
        case "unknown": return .unavailable(.unknown)
        default: return nil
        }
    }

    /// The override given on this launch, if any. It reads the launch arguments themselves: `UserDefaults` would
    /// need a privacy manifest entry for its required-reason API.
    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AIAvailability? {
        guard let flag = arguments.firstIndex(of: "-" + launchArgument), flag + 1 < arguments.endIndex else {
            return nil
        }
        return availability(for: arguments[flag + 1])
    }
}
#endif
