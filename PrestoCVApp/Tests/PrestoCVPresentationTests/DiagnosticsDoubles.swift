import Foundation
import Synchronization
import PrestoCVWorkflowPorts

/// The diagnostics port with fixed runs. It records the calls it got, and the copies it made are one file a run.
final class DiagnosticsFake: DiagnosticsReading {
    struct CopyFailed: Error {}
    private struct State {
        var available: Bool
        var stored: [DiagnosticRun]
        var failing: Set<UUID> = []
        var asked = 0
        var copiesOf: [UUID] = []
        var discards = 0
    }

    private let state: Mutex<State>
    /// Holds the answer of `isAvailable()` while closed, so that a test decides when the gate answers.
    let answer = Gate()
    /// Holds each `shareCopies` call after it started, so that a test decides when each copy is made.
    let copying = Gate()

    init(available: Bool = true, runs: [DiagnosticRun] = []) {
        state = Mutex(State(available: available, stored: runs))
    }

    var asked: Int { state.withLock { $0.asked } }
    var copiesMadeFor: [UUID] { state.withLock { $0.copiesOf } }
    var discards: Int { state.withLock { $0.discards } }

    func setRuns(_ runs: [DiagnosticRun]) { state.withLock { $0.stored = runs } }
    func failCopies(of id: UUID) { state.withLock { _ = $0.failing.insert(id) } }

    func isAvailable() async -> Bool {
        state.withLock { $0.asked += 1 }
        await answer.pass()
        return state.withLock { $0.available }
    }

    func runs() async -> [DiagnosticRun] { state.withLock { $0.stored } }

    func shareCopies(of id: UUID) async throws -> [URL] {
        state.withLock { $0.copiesOf.append(id) }
        await copying.pass()
        if state.withLock({ $0.failing.contains(id) }) { throw CopyFailed() }
        return Self.files(of: id)
    }

    func discardCopies() async { state.withLock { $0.discards += 1 } }

    /// The two files a run's copies are: its document, then its summary.
    static func files(of id: UUID) -> [URL] {
        [URL(fileURLWithPath: "/tmp/share/\(id.uuidString).json"), URL(fileURLWithPath: "/tmp/share/\(id.uuidString).txt")]
    }
}

extension DiagnosticRun {
    /// A run started `seconds` after a fixed instant.
    static func run(
        _ number: Int, at seconds: TimeInterval, kind: DiagnosticRunKind = .aiDraft,
        outcome: DiagnosticRunOutcome = .finished
    ) -> DiagnosticRun {
        DiagnosticRun(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", number))") ?? UUID(), kind: kind,
            started: Date(timeIntervalSince1970: 1_800_000_000 + seconds), outcome: outcome, summary: "Summary of run \(number)"
        )
    }
}

extension Gate {
    /// Whether `count` calls are held at the gate within five seconds; a test that never gets there fails and does not hang.
    func holds(_ count: Int) async throws -> Bool {
        for _ in 0..<5_000 {
            if await waiting >= count { return true }
            try await Task.sleep(for: .milliseconds(1))
        }
        return false
    }
}
