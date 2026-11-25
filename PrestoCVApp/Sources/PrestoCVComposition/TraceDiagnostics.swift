import DiagnosticTrace
import Foundation
import PrestoCVWorkflowPorts

/// The diagnostics port over the trace (#405, ADR 0032): the gate and the stored runs of `TraceAccess`, in the port's own
/// terms, so that no trace type reaches a view model. A run that never ended is `unfinished`. Each adapter holds copies of
/// its own, so that one screen's copies and discard never touch another's, such as the same screen in a second window.
struct TraceDiagnostics: DiagnosticsReading {
    let access: TraceAccess
    /// Whose copies these are, in the trace's folder of copies: a new id for each adapter
    let holder = UUID()

    @concurrent func isAvailable() async -> Bool {
        await access.isOn()
    }

    @concurrent func runs() async -> [DiagnosticRun] {
        await access.reader.runs().map { listing in
            DiagnosticRun(
                id: listing.id, kind: Self.kind(of: listing.kind), started: listing.started,
                outcome: Self.outcome(of: listing.outcome), summary: listing.summary
            )
        }
    }

    @concurrent func shareCopies(of id: UUID) async throws -> [URL] {
        try await access.reader.shareCopies(of: id, for: holder)
    }

    @concurrent func discardCopies() async {
        await access.reader.discardCopies(for: holder)
    }

    private static func kind(of kind: TraceKind) -> DiagnosticRunKind {
        switch kind {
        case .aiDraft: .aiDraft
        case .textImport: .textImport
        }
    }

    private static func outcome(of outcome: TraceOutcome?) -> DiagnosticRunOutcome {
        switch outcome {
        case .finished: .finished
        case .failed: .failed
        case .cancelled: .cancelled
        case nil: .unfinished
        }
    }
}
