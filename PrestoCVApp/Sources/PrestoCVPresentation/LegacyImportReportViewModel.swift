import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// What the launch's import of the released app's CVs left out: the sheet with the details each CV lost, and the notice of
/// the CVs it did not import. Confirm removes the old copies; Not now keeps them, and the sheet returns at the next launch
/// unless the person asked not to be reminded. The causes are the application's (R6); this presents them.
@MainActor
@Observable
public final class LegacyImportReportViewModel {

    public private(set) var state: LegacyReportState = .hidden
    /// The CVs that lost details, in the list's order, each with the label the list shows. Read at each launch while the
    /// old copies stay, even when the sheet does not show.
    public private(set) var leftOut: [LegacyReportRow] = []
    /// The CVs the list marks as incomplete: those the summary says lost details, while their old copy stays, whether the
    /// sheet shows or not and whether the list could be read.
    private var incomplete: Set<CVReference> = []
    /// The CVs that keep details as written for the person to check, apart: none of them is incomplete for it.
    public private(set) var toCheck: [LegacyReportRow] = []
    /// The old CVs the import did not bring in, by cause.
    public private(set) var notImported: [NotImportedCount] = []
    public private(set) var notice: LegacyImportNotice?
    /// "Don't remind me again". It counts only when the person closes the report without confirming: the old copies then
    /// stay on the device and the report does not show again.
    public var remindsNoMore = false

    public var isPresented: Bool {
        switch state {
        case .review, .removing, .keptSome: true
        case .hidden, .removed: false
        }
    }

    /// The old copies are being removed: the sheet cannot be closed.
    public var isBusy: Bool { state == .removing }
    public var notImportedTotal: Int { notImported.reduce(0) { $0 + $1.count } }

    /// The write of the choice not to be reminded, after the sheet closed.
    @ObservationIgnored var storingChoice: Task<Void, Never>?
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private let reviewing: any LegacyImportReviewing
    @ObservationIgnored private let reminder: any LegacyReportReminding
    @ObservationIgnored private let browsing: any CVBrowsing
    @ObservationIgnored private let untitled: String
    @ObservationIgnored private let numbered: @MainActor (String, Int) -> String

    /// `untitled` and `numbered` name the CVs as the list does.
    public init(
        reviewing: any LegacyImportReviewing, reminder: any LegacyReportReminding, browsing: any CVBrowsing,
        untitled: String, numbered: @escaping @MainActor (String, Int) -> String
    ) {
        self.reviewing = reviewing
        self.reminder = reminder
        self.browsing = browsing
        self.untitled = untitled
        self.numbered = numbered
    }

    /// Reads the report once. The view calls it from its `.task`.
    public func load() async {
        guard !loaded else { return }
        loaded = true
        let summary = reviewing.summary
        notImported = LegacyLeftOut.allCases.compactMap { cause in
            summary.leftOut[cause].flatMap { $0 > 0 ? NotImportedCount(cause: NotImportedCause(cause), count: $0) : nil }
        }
        notice = summary.didNotRun ? .didNotRun : notImportedTotal > 0 ? .notImported(notImportedTotal) : nil
        incomplete = Set(summary.drops.compactMap { $0.value.isEmpty ? nil : CVReference(id: $0.key) })
        guard !summary.drops.isEmpty || !summary.toCheck.isEmpty else { return }
        let listing: CVListing
        do {
            listing = try await browsing.list()
        } catch {
            return   // the old copies stay, so the next launch reports the same losses
        }
        let labels = CVListViewModel.labels(of: listing.cvs, untitled: untitled, numbered: numbered)
        leftOut = rows(of: listing.cvs, with: summary.drops.mapValues { $0.map(LegacyDetail.init) }, labels: labels)
        toCheck = rows(of: listing.cvs, with: summary.toCheck.mapValues { $0.map(LegacyDetail.init) }, labels: labels)
        guard !leftOut.isEmpty || !toCheck.isEmpty, await reminder.remindsAgain() else { return }
        state = .review
    }

    /// Whether the list marks the CV as incomplete.
    public func isIncomplete(_ reference: CVReference) -> Bool {
        incomplete.contains(reference)
    }

    /// Removes the old copies of the CVs the sheet shows, whatever the check says; a CV the sheet does not show keeps its old
    /// copy. The CVs whose old copy stays keep their mark. A second call while they are removed does nothing.
    public func confirm() async {
        guard state == .review else { return }
        state = .removing
        let shown = Set((leftOut + toCheck).map(\.id.id))
        let kept = await reviewing.removeOldCopies(of: shown)
        incomplete = incomplete.filter { !shown.contains($0.id) || kept.contains($0.id) }
        state = kept.isEmpty ? .removed : .keptSome(kept.count)
    }

    /// Not now, Done, or the sheet pulled down. From the review it keeps the choice not to be reminded, when made. Nothing
    /// closes while the old copies are removed.
    public func close() {
        switch state {
        case .review:
            state = .hidden
            if remindsNoMore { storingChoice = Task { await stopReminding() } }
        case .keptSome:
            state = .hidden
        case .hidden, .removing, .removed:
            break
        }
    }

    /// Hides the notice for this launch.
    public func hideNotice() {
        notice = nil
    }

    /// The listed CVs that have details in the group, each detail once and in the report's order.
    private func rows(of cvs: [CV], with details: [CVID: [LegacyDetail]], labels: [CVID: String]) -> [LegacyReportRow] {
        cvs.compactMap { cv in
            guard let named = details[cv.id], !named.isEmpty else { return nil }
            return LegacyReportRow(id: CVReference(id: cv.id), label: labels[cv.id] ?? untitled, details: LegacyDetail.ordered(named))
        }
    }

    private func stopReminding() async {
        do {
            try await reminder.stopReminding()
        } catch {
            remindsNoMore = false   // not kept: the report shows again at the next launch
        }
    }
}
