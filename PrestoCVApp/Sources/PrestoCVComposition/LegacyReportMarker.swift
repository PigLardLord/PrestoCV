import Foundation
import PrestoCVWorkflowPorts

/// The person's choice not to see the import report again: an empty file in the app's folder, outside the CV store. The
/// report shows while the file is missing.
struct LegacyReportMarker: LegacyReportReminding {
    let file: URL

    @concurrent func remindsAgain() async -> Bool {
        !FileManager.default.fileExists(atPath: file.path)
    }

    @concurrent func stopReminding() async throws(LegacyReminderFailure) {
        do {
            try Data().write(to: file, options: .atomic)
        } catch {
            throw .notKept
        }
    }
}
