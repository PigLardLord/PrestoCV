#if DEBUG
import Foundation
import PrestoCVWorkflowPorts

/// The import for the UI test of a read the person cancels: a read never ends by itself, and ends as cancelled when its
/// task is cancelled, so the reading state stays on the screen until the test taps Cancel or Back. It exists in Debug
/// builds only (`ReleaseHygieneTests`) and is chosen by the composition from a launch argument (`LaunchFixtures`).
struct HeldImport: CVImporting {
    /// A day stands for never: a UI test cancels the read long before.
    static let hold = Duration.seconds(86_400)

    func importCV(fromText text: String) async throws -> ImportOutcome {
        try await held()
    }

    func importCV(fromPDF data: Data) async throws -> ImportOutcome {
        try await held()
    }

    private func held() async throws -> ImportOutcome {
        try await Task.sleep(for: Self.hold)
        throw CancellationError()
    }
}
#endif
