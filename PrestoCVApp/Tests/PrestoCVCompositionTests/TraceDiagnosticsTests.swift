import DiagnosticTrace
import Foundation
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// A trace reader with fixed runs that records the calls it got.
actor TraceReaderFake: TraceReading {
    struct Unreadable: Error {}
    private let stored: [TraceRunListing]
    private(set) var copiesMadeFor: [UUID] = []
    private(set) var discards = 0

    init(runs: [TraceRunListing]) { stored = runs }

    func runs() async -> [TraceRunListing] { stored }

    func shareCopies(of id: UUID) async throws -> [URL] {
        copiesMadeFor.append(id)
        guard stored.contains(where: { $0.id == id }) else { throw Unreadable() }
        return [URL(fileURLWithPath: "/tmp/share/\(id.uuidString).json")]
    }

    func discardCopies() async { discards += 1 }
}

/// The diagnostics port over the trace: the runs in the port's own terms, the gate from `TraceAccess`, and the copies
/// passed through.
@Suite("The diagnostics adapter")
struct TraceDiagnosticsTests {
    private static let started = Date(timeIntervalSince1970: 1_800_000_000)

    /// An adapter over a closed gate and no runs
    static func reading() -> TraceDiagnostics {
        TraceDiagnostics(access: TraceAccess(isOn: { false }, reader: TraceReaderFake(runs: [])))
    }

    private static func listing(_ kind: TraceKind, _ outcome: TraceOutcome?) -> TraceRunListing {
        TraceRunListing(id: UUID(), kind: kind, started: started, outcome: outcome, summary: "Summary \(kind.rawValue)")
    }

    @Test("Diagnostics adapter maps TraceRunListing to the port types")
    func mapsListings() async {
        let listings = [
            Self.listing(.aiDraft, .finished), Self.listing(.textImport, .failed(code: "pdf.empty")),
            Self.listing(.aiDraft, .cancelled), Self.listing(.textImport, nil),
        ]
        let adapter = TraceDiagnostics(access: TraceAccess(isOn: { true }, reader: TraceReaderFake(runs: listings)))

        let runs = await adapter.runs()

        #expect(runs.map(\.id) == listings.map(\.id))
        #expect(runs.map(\.kind) == [.aiDraft, .textImport, .aiDraft, .textImport])
        #expect(runs.map(\.outcome) == [.finished, .failed, .cancelled, .unfinished])
        #expect(runs.map(\.started) == listings.map(\.started))
        #expect(runs.map(\.summary) == listings.map(\.summary))
    }

    @Test("Diagnostics adapter reports the gate from TraceAccess")
    func reportsTheGate() async {
        let open = TraceDiagnostics(access: TraceAccess(isOn: { true }, reader: TraceReaderFake(runs: [])))
        let closed = TraceDiagnostics(access: TraceAccess(isOn: { false }, reader: TraceReaderFake(runs: [])))

        #expect(await open.isAvailable())
        #expect(await !closed.isAvailable())
    }

    @Test("Diagnostics adapter passes the copies and their discard to the reader")
    func passesCopies() async throws {
        let listing = Self.listing(.aiDraft, .finished)
        let reader = TraceReaderFake(runs: [listing])
        let adapter = TraceDiagnostics(access: TraceAccess(isOn: { true }, reader: reader))

        let files = try await adapter.shareCopies(of: listing.id)
        await adapter.discardCopies()

        #expect(files.map(\.lastPathComponent) == ["\(listing.id.uuidString).json"])
        #expect(await reader.copiesMadeFor == [listing.id])
        #expect(await reader.discards == 1)
    }

    @Test("Diagnostics adapter lets a copy that cannot be made throw")
    func copyFailureThrows() async {
        let adapter = TraceDiagnostics(access: TraceAccess(isOn: { true }, reader: TraceReaderFake(runs: [])))

        await #expect(throws: TraceReaderFake.Unreadable.self) { try await adapter.shareCopies(of: UUID()) }
    }
}
