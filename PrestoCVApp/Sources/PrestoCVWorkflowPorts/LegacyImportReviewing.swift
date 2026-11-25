import PrestoCVDomain
import PrestoCVApplication

/// What the launch's import of the released app's CVs left out, as its report shows it.
public struct LegacyImportSummary: Sendable, Equatable {
    /// The details each stored CV lost, for the CVs whose old copy stays until the person confirms the report.
    public let drops: [CVID: [LegacyDrop]]
    /// What each stored CV keeps in another place, for the person to check; it is no loss.
    public let toCheck: [CVID: [LegacyCheck]]
    /// How many old CVs the import left out of the new store, by cause; their files stay for the next launch.
    public let leftOut: [LegacyLeftOut: Int]
    /// The import stopped before it knew the old CVs: how many it left out is unknown, and it runs again at the next launch.
    public let didNotRun: Bool

    public init(drops: [CVID: [LegacyDrop]], toCheck: [CVID: [LegacyCheck]], leftOut: [LegacyLeftOut: Int], didNotRun: Bool) {
        self.drops = drops; self.toCheck = toCheck; self.leftOut = leftOut; self.didNotRun = didNotRun
    }
}

/// The report of the launch's import and the removal of the old copies it kept. The import report owns this port (R3); its
/// adapter is `LegacyImportReview`, in `PrestoCVIntegration`. Contents, layer and allowed imports:
/// docs/architecture/modules.md.
public protocol LegacyImportReviewing: Sendable {
    var summary: LegacyImportSummary { get }
    /// Removes the old copies of the CVs in `shown`, the ones the report showed, each only while its file holds what the
    /// import read; the old copy of a CV the report did not show stays. Returns the CVs of `shown` whose old copy stays on the
    /// device: one that changed or could not be removed stays, and the next launch reports it again.
    func removeOldCopies(of shown: Set<CVID>) async -> Set<CVID>
}

/// Whether the report shows again at the next launches. The import report owns this port (R3); its adapter,
/// `LegacyReportMarker` in `PrestoCVComposition`, keeps the choice outside the CV store.
public protocol LegacyReportReminding: Sendable {
    /// False once the person asked not to be reminded.
    func remindsAgain() async -> Bool
    /// Keeps the person's choice not to be reminded; throws when it cannot be kept, and the report shows again next time.
    func stopReminding() async throws(LegacyReminderFailure)
}

public enum LegacyReminderFailure: Error, Sendable, Equatable {
    /// The choice could not be written: the report shows again at the next launch.
    case notKept
}
