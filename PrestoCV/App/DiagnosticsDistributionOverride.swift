#if DEBUG
import DiagnosticTrace
import Foundation

/// The answer a UI test gives a Debug build in place of the store's: `-diagnosticsDistribution sandbox` runs the trace as
/// a TestFlight install does, `production` or `unknown` as an App Store install or an unknown one does (ADR 0032). It is
/// read only by Debug builds, so a Release build has no way to turn the trace on.
enum DiagnosticsDistributionOverride {
    static let launchArgument = "diagnosticsDistribution"

    /// The answer given on this launch, if any. It reads the launch arguments themselves: `UserDefaults` would need a
    /// privacy manifest entry for its required-reason API.
    static func current(arguments: [String]) -> (any DistributionReading)? {
        guard let flag = arguments.firstIndex(of: "-" + launchArgument), flag + 1 < arguments.endIndex,
              let given = DistributionAnswer(rawValue: arguments[flag + 1]) else {
            return nil
        }
        return GivenDistribution(given: given)
    }

    /// A distribution that answers what the launch arguments say.
    private struct GivenDistribution: DistributionReading {
        let given: DistributionAnswer

        func answer() async throws -> DistributionAnswer {
            given
        }
    }
}
#endif
