import Foundation
import Synchronization
import PrestoCVWorkflowPorts

/// The diagnostics port with fixed runs. It records the calls it got in order, and keeps one folder of copies as the
/// trace's store does: each copy empties the folder before it writes the two files of its run, and a discard empties it.
final class DiagnosticsFake: DiagnosticsReading {
    struct CopyFailed: Error {}
    enum Call: Equatable { case copy(UUID), copied(UUID), discard }
    private struct State {
        var available: Bool
        var stored: [DiagnosticRun]
        var failing: Set<UUID> = []
        var asked = 0
        var calls: [Call] = []
        var folder: [URL] = []
        var copiesAtOnce = 0
        var mostCopiesAtOnce = 0
    }

    private let state: Mutex<State>
    /// Holds the answer of `isAvailable()` while closed, so that a test decides when the gate answers.
    let answer = Gate()
    /// Holds each `runs()` call while closed, with the runs stored when it started.
    let listing = Gate()
    /// Holds each `shareCopies` call after it started, so that a test decides when each copy is made.
    let copying = Gate()

    init(available: Bool = true, runs: [DiagnosticRun] = []) {
        state = Mutex(State(available: available, stored: runs))
    }

    var asked: Int { state.withLock { $0.asked } }
    var calls: [Call] { state.withLock { $0.calls } }
    var copiesMadeFor: [UUID] {
        calls.compactMap { if case .copy(let id) = $0 { id } else { nil } }
    }
    var discards: Int { calls.filter { $0 == .discard }.count }
    /// The files in the folder of copies now.
    var folder: [URL] { state.withLock { $0.folder } }
    var mostCopiesAtOnce: Int { state.withLock { $0.mostCopiesAtOnce } }

    func setRuns(_ runs: [DiagnosticRun]) { state.withLock { $0.stored = runs } }
    func failCopies(of id: UUID) { state.withLock { _ = $0.failing.insert(id) } }

    func isAvailable() async -> Bool {
        state.withLock { $0.asked += 1 }
        await answer.pass()
        return state.withLock { $0.available }
    }

    func runs() async -> [DiagnosticRun] {
        let stored = state.withLock { $0.stored }
        await listing.pass()
        return stored
    }

    func shareCopies(of id: UUID) async throws -> [URL] {
        state.withLock {
            $0.calls.append(.copy(id))
            $0.copiesAtOnce += 1
            $0.mostCopiesAtOnce = max($0.mostCopiesAtOnce, $0.copiesAtOnce)
        }
        await copying.pass()
        return try state.withLock {
            $0.copiesAtOnce -= 1
            $0.folder = []
            guard !$0.failing.contains(id) else { throw CopyFailed() }
            $0.folder = Self.files(of: id)
            $0.calls.append(.copied(id))
            return $0.folder
        }
    }

    func discardCopies() async {
        state.withLock {
            $0.folder = []
            $0.calls.append(.discard)
        }
    }

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
