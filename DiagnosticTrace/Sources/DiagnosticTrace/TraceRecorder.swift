import DiagnosticLogging
import Foundation
import Synchronization

/// The tracer of a test build: keeps each open run in memory and hands every new state of it to the store, so that a crash
/// leaves the steps up to the last one written.
public final class TraceRecorder: DiagnosticTracer {
    private struct OpenRun {
        var builder: TraceRunBuilder
        let stopwatch: Stopwatch
    }

    private struct State {
        var open: [UUID: OpenRun] = [:]
        /// The newest open run of each kind, for the steps recorded by kind.
        var latest: [TraceKind: UUID] = [:]
    }

    private let store: any TraceStoring
    private let build: @Sendable () -> TraceBuild
    private let startStopwatch: @Sendable () -> Stopwatch
    private let now: @Sendable () -> Date
    private let newID: @Sendable () -> UUID
    private let state = Mutex(State())

    /// - Parameters:
    ///   - build: the build that makes the runs, read when a run begins, once the distribution has answered.
    ///   - clock: measures the time of each step since its run began.
    ///   - now: the start time of a run, and the time of a session event.
    ///   - newID: the id of a run.
    public init<C: Clock<Duration>>(
        store: any TraceStoring,
        build: @escaping @Sendable () -> TraceBuild,
        clock: C,
        now: @escaping @Sendable () -> Date,
        newID: @escaping @Sendable () -> UUID
    ) {
        self.store = store
        self.build = build
        startStopwatch = { Stopwatch(started: clock) }
        self.now = now
        self.newID = newID
    }

    public func begin(_ kind: TraceKind) -> any TraceRunRecording {
        let run = TraceRun(id: newID(), kind: kind, started: now(), build: build(), steps: [], outcome: nil)
        let stopwatch = startStopwatch()
        state.withLock { state in
            state.open[run.id] = OpenRun(builder: TraceRunBuilder(run: run), stopwatch: stopwatch)
            state.latest[kind] = run.id
        }
        return RecordedRun(recorder: self, id: run.id, kind: kind)
    }

    public func record(_ name: TraceStepName, _ fields: [TraceField], into kind: TraceKind) {
        guard let id = target(of: kind) else { return }
        record(name, fields, inRun: id)
    }

    public func mirror(_ event: TraceEvent) {
        if let kind = event.kind, let id = target(of: kind) {
            record(.event, [.token("category", event.category), .token("level", event.level), .text("line", event.line)], inRun: id)
        } else {
            store.save(sessionEvent: TraceSessionEvent(time: now(), category: event.category, level: event.level, line: event.line))
        }
    }

    /// The run a step of a kind belongs to: the run whose scope the work is in, when it is of that kind (nil once it has
    /// finished, so that its late steps do not land in a newer run), else the newest open run of the kind.
    private func target(of kind: TraceKind) -> UUID? {
        state.withLock { state in
            if let scope = TraceScope.current, scope.kind == kind {
                return state.open[scope.id] == nil ? nil : scope.id
            }
            return state.latest[kind]
        }
    }

    // MARK: Runs

    fileprivate func record(_ name: TraceStepName, _ fields: [TraceField], inRun id: UUID) {
        state.withLock { state in
            guard var open = state.open[id] else { return }
            if open.builder.append(name, fields, elapsed: open.stopwatch.elapsed) {
                store.save(open.builder.run)
            }
            state.open[id] = open
        }
    }

    fileprivate func finish(_ outcome: TraceOutcome, run id: UUID) {
        state.withLock { state in
            guard var open = state.open.removeValue(forKey: id) else { return }
            if state.latest[open.builder.run.kind] == id { state.latest[open.builder.run.kind] = nil }
            open.builder.finish(outcome)
            store.save(open.builder.run)
        }
    }
}

/// The handle of one run of the recorder.
private struct RecordedRun: TraceRunRecording {
    let recorder: TraceRecorder
    let id: UUID
    let kind: TraceKind

    var scope: TraceScope? { TraceScope(id: id, kind: kind) }

    func record(_ name: TraceStepName, _ fields: [TraceField]) {
        recorder.record(name, fields, inRun: id)
    }

    func finish(_ outcome: TraceOutcome) {
        recorder.finish(outcome, run: id)
    }
}

/// Adds steps to a run, numbers them, and keeps the run under its size cap: past it, one `truncated` step counts the
/// steps left out.
struct TraceRunBuilder {
    /// The most bytes a run keeps, roughly: its texts and words, and a fixed share for each step.
    static let sizeLimit = 1_048_576
    static let stepOverhead = 64

    private(set) var run: TraceRun
    private var size = 0
    private var leftOut = 0

    init(run: TraceRun) {
        self.run = run
    }

    /// Adds a step, or counts it as left out; returns whether the run changed.
    mutating func append(_ name: TraceStepName, _ fields: [TraceField], elapsed: Duration) -> Bool {
        guard run.outcome == nil else { return false }
        let stepSize = Self.size(of: fields)
        guard leftOut == 0, size + stepSize <= Self.sizeLimit else {
            leftOut += 1
            if leftOut > 1 { run.steps.removeLast() }
            run.steps.append(TraceStep(
                sequence: run.steps.count + 1, elapsed: elapsed, name: .truncated, fields: [.count("stepsLeftOut", leftOut)]
            ))
            return true
        }
        size += stepSize
        run.steps.append(TraceStep(sequence: run.steps.count + 1, elapsed: elapsed, name: name, fields: fields))
        return true
    }

    /// Ends the run, once.
    mutating func finish(_ outcome: TraceOutcome) {
        guard run.outcome == nil else { return }
        run.outcome = outcome
    }

    private static func size(of fields: [TraceField]) -> Int {
        fields.reduce(stepOverhead) { total, field in
            switch field.value {
            case .text(let text): total + field.key.utf8.count + text.text.utf8.count
            case .token(let token): total + field.key.utf8.count + token.utf8.count
            case .count, .flag, .duration: total + field.key.utf8.count + 16
            }
        }
    }
}
