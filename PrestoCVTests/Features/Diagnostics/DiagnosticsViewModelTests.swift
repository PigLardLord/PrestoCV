import DiagnosticTrace
import Foundation
import Testing
@testable import PrestoCV

/// What the diagnostics screen of a test build shows (ADR 0032): nothing while the trace does not record, and otherwise
/// the stored runs, the summary of the chosen one and the files to share, exactly as the store gives them.
@MainActor
@Suite("The diagnostics screen of a test build")
struct DiagnosticsViewModelTests {

    private static let importID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private static let draftID = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    /// 26 October 2026, 07:33 UTC
    private static let started = Date(timeIntervalSince1970: 1_793_000_000)

    /// Newest first, as the store lists them
    private static let runs = [
        TraceRunListing(
            id: importID, kind: .textImport, started: started.addingTimeInterval(60), outcome: .failed(code: "empty"),
            summary: "Text import, failed (empty)"
        ),
        TraceRunListing(id: draftID, kind: .aiDraft, started: started, outcome: .finished, summary: "AI draft, finished"),
    ]

    private func viewModel(isOn: Bool = true, reader: ReaderSpy) -> DiagnosticsViewModel {
        DiagnosticsViewModel(
            access: TraceAccess(isOn: { isOn }, reader: reader), locale: Locale(identifier: "en"), calendar: { gregorianUTC }
        )
    }

    // MARK: Off

    @Test("When the trace does not record, the screen is not offered and reads no run")
    func off() async {
        let reader = ReaderSpy(runs: Self.runs)
        let model = viewModel(isOn: false, reader: reader)

        await model.checkAvailability()
        await model.load()

        #expect(!model.isAvailable)
        #expect(model.rows.isEmpty)
        #expect(model.shareFiles.isEmpty)
        #expect(await reader.calls.isEmpty)
    }

    // MARK: On

    @Test("When the trace records, the screen lists the runs newest first, with their kind, day and outcome")
    func rows() async throws {
        let model = viewModel(reader: ReaderSpy(runs: Self.runs))

        await model.checkAvailability()
        await model.load()

        #expect(model.isAvailable)
        #expect(model.rows.map(\.id) == [Self.importID, Self.draftID])
        #expect(model.rows.map(\.title) == ["diagnostics.run.import".localized, "diagnostics.run.draft".localized])
        #expect(model.rows.map(\.outcome) == [
            "diagnostics.run.outcome.failed".localized, "diagnostics.run.outcome.finished".localized,
        ])
        let time = try #require(model.rows.last?.time)
        #expect(time.contains("Oct 26, 2026"))
    }

    @Test("A run that never finished, such as one a crash stopped, says so")
    func unfinished() async {
        let open = TraceRunListing(id: Self.draftID, kind: .aiDraft, started: Self.started, outcome: nil, summary: "AI draft, open")
        let model = viewModel(reader: ReaderSpy(runs: [open]))

        await model.checkAvailability()
        await model.load()

        #expect(model.rows.map(\.outcome) == ["diagnostics.run.outcome.unfinished".localized])
    }

    @Test("The newest run is chosen first: its summary is shown and its files are handed out as the store gave them")
    func newestChosen() async {
        let reader = ReaderSpy(runs: Self.runs)
        let model = viewModel(reader: reader)

        await model.checkAvailability()
        await model.load()

        #expect(model.selection == Self.importID)
        #expect(model.summary == Self.runs[0].summary)
        #expect(model.shareFiles == ReaderSpy.files(of: Self.importID))
        #expect(await reader.calls == [.runs, .copies(Self.importID)])
    }

    @Test("Choosing another run shows its summary and hands out its files")
    func choose() async {
        let reader = ReaderSpy(runs: Self.runs)
        let model = viewModel(reader: reader)
        await model.checkAvailability()
        await model.load()

        await model.select(Self.draftID)

        #expect(model.selection == Self.draftID)
        #expect(model.summary == Self.runs[1].summary)
        #expect(model.shareFiles == ReaderSpy.files(of: Self.draftID))
    }

    @Test("A run the person picks announces where its summary is, each time, and the run chosen at load does not")
    func pickingAnnouncesTheSummary() async {
        let model = viewModel(reader: ReaderSpy(runs: Self.runs))
        await model.checkAvailability()
        await model.load()
        #expect(model.notice == nil, "Nothing is announced for the run chosen on its own")

        await model.choose(Self.draftID)
        let first = model.notice

        #expect(model.selection == Self.draftID)
        #expect(first?.text == "diagnostics.summary.announcement".localized)

        await model.choose(Self.draftID)

        #expect(model.notice != first, "Picking the same run again is announced again")
    }

    @Test("When the copies to share cannot be made, the summary is shown and nothing is handed out")
    func copiesFail() async {
        let model = viewModel(reader: ReaderSpy(runs: Self.runs, failsCopies: true))

        await model.checkAvailability()
        await model.load()

        #expect(model.summary == Self.runs[0].summary)
        #expect(model.shareFiles.isEmpty)
    }

    @Test("With no run stored, nothing is chosen and nothing is handed out")
    func empty() async {
        let reader = ReaderSpy(runs: [])
        let model = viewModel(reader: reader)

        await model.checkAvailability()
        await model.load()

        #expect(model.rows.isEmpty)
        #expect(model.selection == nil)
        #expect(model.summary.isEmpty)
        #expect(model.shareFiles.isEmpty)
        #expect(await reader.calls == [.runs])
    }

    @Test("Closing the screen discards the copies made to share")
    func finish() async {
        let reader = ReaderSpy(runs: Self.runs)
        let model = viewModel(reader: reader)
        await model.checkAvailability()
        await model.load()

        await model.finishSharing()

        #expect(model.shareFiles.isEmpty)
        #expect(await reader.calls.last == .discard)
    }
}

/// A store of runs that hands out fixed files and remembers what it was asked.
private actor ReaderSpy: TraceReading {
    enum Call: Equatable {
        case runs
        case copies(UUID)
        case discard
    }

    private struct CopyFailure: Error {}

    private(set) var calls: [Call] = []
    private let stored: [TraceRunListing]
    private let failsCopies: Bool

    init(runs: [TraceRunListing], failsCopies: Bool = false) {
        stored = runs
        self.failsCopies = failsCopies
    }

    /// The copies of a run the spy hands out: its document, then its summary.
    static func files(of id: UUID) -> [URL] {
        [URL(fileURLWithPath: "/share/\(id).json"), URL(fileURLWithPath: "/share/\(id).txt")]
    }

    func runs() async -> [TraceRunListing] {
        calls.append(.runs)
        return stored
    }

    func shareCopies(of id: UUID) async throws -> [URL] {
        calls.append(.copies(id))
        if failsCopies { throw CopyFailure() }
        return Self.files(of: id)
    }

    func discardCopies() async {
        calls.append(.discard)
    }
}
