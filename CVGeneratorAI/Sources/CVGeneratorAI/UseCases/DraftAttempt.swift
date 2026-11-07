import Foundation

/// The steps of a draft, in order (ADR 0031, "A request per section"): the model extracts the facts, code gives each job its own
/// clauses of the description, then the model writes each job, the skills and, last, the summary, a request at a time.
enum DraftStep: CaseIterable, Sendable {
    /// One request extracts the facts the description states.
    case facts
    /// Code gives each job the clauses of the description that belong to it, the place after its employer and the words to avoid.
    case attribution
    /// A request per job writes its years and duties; a job whose duties the check finds too few or too short gets one repair.
    case jobs
    /// A request writes the tools of each job, one the soft skills, and one more when the check leaves too few.
    case skills
    /// A request writes the summary from the jobs and skills kept; one repair when the check rejects a sentence or finds it short.
    case summary

    var logName: StaticString {
        switch self {
        case .facts: "facts"
        case .attribution: "attribution"
        case .jobs: "jobs"
        case .skills: "skills"
        case .summary: "summary"
        }
    }
}

/// How long one call of a pass may take, and the clock its time runs on (#400): the app's is the continuous clock, a test's
/// ends the time when the test says so.
struct TimeLimit: Sendable {
    let duration: Duration
    let clock: any Clock<Duration>
}

/// How long each request of a draft may take on the device (ADR 0031). A call of the on-device model that runs past its time is
/// stopped: a model caught repeating itself would otherwise run until its window fills, minutes later (#354).
struct DraftingLimits: Sendable {
    /// How long the request that extracts the facts may take. The longest description takes about a quarter of it on a Mac.
    let extraction: TimeLimit
    /// How long each request that writes a section, or repairs one, may take.
    let section: TimeLimit

    /// - Parameter clock: The clock both times run on.
    init(extraction: Duration, section: Duration, on clock: any Clock<Duration>) {
        self.extraction = TimeLimit(duration: extraction, clock: clock)
        self.section = TimeLimit(duration: section, clock: clock)
    }

    static let standard = DraftingLimits(extraction: .seconds(90), section: .seconds(30), on: ContinuousClock())
}

/// One call of a pass of the model, within its time, tried once more when it fails below the model.
@MainActor
enum DraftAttempt {
    /// What `work` returns, within `limit`.
    ///
    /// A call that fails with `CVGenerationError.serviceFailed`, an error from below the model rather than an answer of it, is tried
    /// once more: such a failure does not come from the description. A call that runs out of time is not: the same description would
    /// take as long again.
    /// - Parameter retried: Told the error of a call that is tried once more.
    /// - Throws: `CVGenerationError.generationFailed` when the time runs out, whatever `work` throws otherwise, and CancellationError
    ///   when the task is cancelled.
    static func run<Value: Sendable>(
        within limit: TimeLimit, retried: (any Error) -> Void = { _ in },
        _ work: @escaping @Sendable @MainActor () async throws -> Value
    ) async throws -> Value {
        do {
            return try await once(within: limit, work)
        } catch CVGenerationError.serviceFailed {
            try Task.checkCancellation()
            retried(CVGenerationError.serviceFailed)
            return try await once(within: limit, work)
        }
    }

    /// One call of `work`, raced against `limit` on its clock, off the main actor (#400): the time runs in a child task of its own,
    /// so a busy main actor delays neither the end of the time nor the decision of which came first. The first to finish decides:
    /// the call's answer, its error, or the end of its time, which cancels the call. A call that answers after its time has run out
    /// is not taken.
    nonisolated private static func once<Value: Sendable>(
        within limit: TimeLimit, _ work: @escaping @Sendable @MainActor () async throws -> Value
    ) async throws -> Value {
        do {
            return try await withThrowingTaskGroup(of: CallEnd<Value>.self) { group in
                group.addTask { .answered(try await work()) }
                group.addTask {
                    try await limit.clock.sleep(for: limit.duration)
                    return .timedOut
                }
                defer { group.cancelAll() }
                guard case .answered(let value)? = try await group.next() else { throw CVGenerationError.generationFailed }
                return value
            }
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }
}

/// How one call of a pass ended: with the call's answer, or with the end of its time.
private enum CallEnd<Value: Sendable>: Sendable {
    case answered(Value)
    case timedOut
}
