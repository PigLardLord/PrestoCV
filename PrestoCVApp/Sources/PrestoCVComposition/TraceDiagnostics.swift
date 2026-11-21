import DiagnosticTrace
import Foundation
import PrestoCVWorkflowPorts

/// The diagnostics port over the trace (#405, ADR 0032): the gate and the stored runs of `TraceAccess`, in the port's own
/// terms, so that no trace type reaches a view model. A run that never ended is `unfinished`.
struct TraceDiagnostics: DiagnosticsReading {
    let access: TraceAccess

    func isAvailable() async -> Bool {
        await access.isOn()
    }

    func runs() async -> [DiagnosticRun] {
        await access.reader.runs().map { listing in
            DiagnosticRun(
                id: listing.id, kind: Self.kind(of: listing.kind), started: listing.started,
                outcome: Self.outcome(of: listing.outcome), summary: listing.summary
            )
        }
    }

    func shareCopies(of id: UUID) async throws -> [URL] {
        try await access.reader.shareCopies(of: id)
    }

    func discardCopies() async {
        await access.reader.discardCopies()
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
