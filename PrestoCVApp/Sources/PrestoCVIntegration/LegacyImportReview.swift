import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// The report of the launch's import, read from what the import did, and the removal of the old copies by the importer
/// that kept them (`acknowledgeLosses(of:)`).
public struct LegacyImportReview: LegacyImportReviewing {
    private let outcome: LegacyImportOutcome
    private let importer: ImportLegacyStore

    /// `outcome` is what `importer` did at this launch.
    public init(outcome: LegacyImportOutcome, importer: ImportLegacyStore) {
        self.outcome = outcome; self.importer = importer
    }

    public var summary: LegacyImportSummary {
        switch outcome {
        case .ran(let report):
            let leftOut = report.failures.compactMap(\.reason.leftOut).reduce(into: [LegacyLeftOut: Int]()) { $0[$1, default: 0] += 1 }
            return LegacyImportSummary(drops: report.drops, toCheck: report.checks, leftOut: leftOut, didNotRun: false)
        case .failed:
            return LegacyImportSummary(drops: [:], toCheck: [:], leftOut: [:], didNotRun: true)
        }
    }

    public func removeOldCopies() async -> Int {
        guard case .ran(let report) = outcome else { return 0 }
        return await importer.acknowledgeLosses(of: report).failures.count
    }
}
