import DiagnosticTrace
import Foundation
import Synchronization

/// A store that keeps every state of every run in memory, for tests to read what was recorded.
public final class RecordingTraceStore: TraceStoring {
    private struct Saved {
        var runs: [TraceRun] = []
        var sessionEvents: [TraceSessionEvent] = []
    }

    private let saved = Mutex(Saved())

    public init() {}

    public func save(_ run: TraceRun) {
        saved.withLock { $0.runs.append(run) }
    }

    public func save(sessionEvent: TraceSessionEvent) {
        saved.withLock { $0.sessionEvents.append(sessionEvent) }
    }

    /// How many states of runs were handed to the store.
    public var runWrites: Int { saved.withLock { $0.runs.count } }

    /// The latest state of each run, in the order the runs began.
    public var runs: [TraceRun] {
        saved.withLock { saved in
            var order: [UUID] = []
            var latest: [UUID: TraceRun] = [:]
            for run in saved.runs {
                if latest[run.id] == nil { order.append(run.id) }
                latest[run.id] = run
            }
            return order.compactMap { latest[$0] }
        }
    }

    /// The latest state of the newest run of a kind.
    public func latest(_ kind: TraceKind) -> TraceRun? {
        runs.last { $0.kind == kind }
    }

    public var sessionEvents: [TraceSessionEvent] { saved.withLock { $0.sessionEvents } }
}

/// A tracer that records into memory with the real recorder, on a clock that does not move, for tests of the code that
/// traces: `tracer.run(.aiDraft)?.steps`.
public final class RecordingTracer: DiagnosticTracer {
    public let store = RecordingTraceStore()
    private let recorder: TraceRecorder

    public init() {
        let ids = Mutex(0)
        recorder = TraceRecorder(
            store: store,
            build: { TraceBuild(appVersion: "test", build: "0", distribution: "test", osVersion: "test", deviceModel: "test") },
            clock: StoppedClock(),
            now: { Date(timeIntervalSince1970: 0) },
            newID: {
                let next = ids.withLock { count in
                    count += 1
                    return count
                }
                return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(truncatingIfNeeded: next)))
            }
        )
    }

    public func begin(_ kind: TraceKind) -> any TraceRunRecording { recorder.begin(kind) }

    public func record(_ name: TraceStepName, into kind: TraceKind, fields: () -> [TraceField]) {
        recorder.record(name, into: kind, fields: fields)
    }

    public func mirror(_ event: TraceEvent) { recorder.mirror(event) }

    /// The latest state of the newest run of a kind.
    public func run(_ kind: TraceKind) -> TraceRun? { store.latest(kind) }

    /// Every run, in the order they began.
    public var runs: [TraceRun] { store.runs }
}

/// A tracer whose runs keep nothing, as a closed gate's do, and which counts every call made on them: a test that a part
/// builds none of its payloads when nothing records expects `calls` to stay at zero.
public final class RefusingTracer: DiagnosticTracer {
    private let counted = Mutex(0)

    public init() {}

    /// How many steps were handed to a run, or recorded by kind.
    public var calls: Int { counted.withLock { $0 } }

    public func begin(_ kind: TraceKind) -> any TraceRunRecording { RefusedRun(tracer: self) }

    public func record(_ name: TraceStepName, into kind: TraceKind, fields: () -> [TraceField]) {
        counted.withLock { $0 += 1 }
    }

    public func mirror(_ event: TraceEvent) {}

    fileprivate func count() {
        counted.withLock { $0 += 1 }
    }

    private struct RefusedRun: TraceRunRecording {
        let tracer: RefusingTracer
        var scope: TraceScope { .suppressed }

        func record(_ name: TraceStepName, _ fields: [TraceField]) { tracer.count() }
        func finish(_ outcome: TraceOutcome) {}
    }
}

extension TraceRun {
    /// The steps with a name.
    public func steps(_ name: TraceStepName) -> [TraceStep] {
        steps.filter { $0.name == name }
    }

    /// Every text of every step, joined, for a test that looks for a word anywhere in the run.
    public var allText: String {
        steps.flatMap(\.fields).compactMap { field in
            if case .text(let text) = field.value { return text.text }
            if case .token(let token) = field.value { return token }
            return nil
        }.joined(separator: "\n")
    }
}

extension TraceStep {
    /// The value of the field with this key, or nil.
    public func value(_ key: String) -> TraceValue? {
        fields.first { $0.key == key }?.value
    }

    /// The text of the field with this key, or nil.
    public func text(_ key: String) -> String? {
        if case .text(let text) = value(key) { return text.text }
        return nil
    }
}

/// A distribution that gives one answer, or throws.
public struct FixedDistribution: DistributionReading {
    public struct Failure: Error {
        public init() {}
    }

    private let result: Result<DistributionAnswer, Failure>

    public init(_ answer: DistributionAnswer) {
        result = .success(answer)
    }

    public init(throwing failure: Failure) {
        result = .failure(failure)
    }

    public func answer() async throws -> DistributionAnswer {
        try result.get()
    }
}

/// A clock whose time never moves.
public struct StoppedClock: Clock {
    public struct Instant: InstantProtocol {
        public func advanced(by duration: Duration) -> Instant { self }
        public func duration(to other: Instant) -> Duration { .zero }
        public static func < (lhs: Instant, rhs: Instant) -> Bool { false }
    }

    public init() {}

    public var now: Instant { Instant() }
    public var minimumResolution: Duration { .zero }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
    }
}
