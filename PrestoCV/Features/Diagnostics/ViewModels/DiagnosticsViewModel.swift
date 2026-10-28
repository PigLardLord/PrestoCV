import Combine
import DiagnosticTrace
import Foundation

/// Whether the trace of a test build records on this launch, and the runs it stored (ADR 0032). The composition root
/// builds it: in an App Store build the trace never records, so the diagnostics screen is never offered.
struct TraceAccess: Sendable {
    /// Whether the trace records on this launch, once the build has its answer
    let isOn: @Sendable () async -> Bool
    /// The stored runs, and the copies of their files to share
    let reader: any TraceReading
}

/// What the diagnostics screen of a TestFlight or Debug build shows (ADR 0032): whether it is offered, the stored runs,
/// the summary of the chosen one and the files to share. The files are the store's own copies, handed out as they are,
/// and nothing leaves the device but through the person's share.
@MainActor
final class DiagnosticsViewModel: ObservableObject {
    /// A stored run, as the screen lists it
    struct Row: Identifiable, Equatable {
        let id: UUID
        /// An AI draft or an import
        let title: String
        /// When the run started
        let time: String
        /// How it ended, or that it never did
        let outcome: String
    }

    /// The screen is offered: the trace records on this launch
    @Published private(set) var isAvailable = false
    /// The stored runs, newest first
    @Published private(set) var rows: [Row] = []
    /// The chosen run
    @Published private(set) var selection: UUID?
    /// The plain-text summary of the chosen run, as it is shared
    @Published private(set) var summary = ""
    /// The files of the chosen run to share: its document, then its summary. Empty while there is none to share
    @Published private(set) var shareFiles: [URL] = []

    private let access: TraceAccess
    private let locale: Locale
    private let calendar: () -> Calendar
    private var listings: [TraceRunListing] = []

    /// - Parameters:
    ///   - locale: The language the times are told in, the app's own.
    ///   - calendar: The calendar and the time zone the times are told in.
    init(access: TraceAccess, locale: Locale, calendar: @escaping () -> Calendar) {
        self.access = access
        self.locale = locale
        self.calendar = calendar
    }

    /// Finds out whether the screen is offered on this launch.
    func checkAvailability() async {
        isAvailable = await access.isOn()
    }

    /// Reads the stored runs, and chooses the newest one.
    func load() async {
        guard isAvailable else { return }
        listings = await access.reader.runs()
        let calendar = calendar()
        let time = Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        rows = listings.map { listing in
            Row(id: listing.id, title: Self.title(of: listing.kind), time: listing.started.formatted(time), outcome: Self.outcome(listing.outcome))
        }
        if let newest = listings.first {
            await select(newest.id)
        } else {
            selection = nil
            summary = ""
            shareFiles = []
        }
    }

    /// Chooses a run: shows its summary, and makes the copies of its files to share.
    func select(_ id: UUID) async {
        guard let listing = listings.first(where: { $0.id == id }) else { return }
        selection = id
        summary = listing.summary
        do {
            shareFiles = try await access.reader.shareCopies(of: id)
        } catch {
            // The store logs why; with no copy there is nothing to share
            shareFiles = []
        }
    }

    /// Discards the copies made to share, once the screen is closed.
    func finishSharing() async {
        shareFiles = []
        await access.reader.discardCopies()
    }

    // MARK: Texts

    private static func title(of kind: TraceKind) -> String {
        switch kind {
        case .aiDraft: "diagnostics.run.draft".localized
        case .textImport: "diagnostics.run.import".localized
        }
    }

    private static func outcome(_ outcome: TraceOutcome?) -> String {
        switch outcome {
        case .finished: "diagnostics.run.outcome.finished".localized
        case .failed: "diagnostics.run.outcome.failed".localized
        case .cancelled: "diagnostics.run.outcome.cancelled".localized
        case nil: "diagnostics.run.outcome.unfinished".localized
        }
    }
}
