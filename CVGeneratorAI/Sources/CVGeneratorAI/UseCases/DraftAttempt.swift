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

/// How long each request of a draft may take on the device (ADR 0031). A call of the on-device model that runs past its time is
/// stopped: a model caught repeating itself would otherwise run until its window fills, minutes later (#354).
struct DraftingLimits: Equatable, Sendable {
    /// How long the request that extracts the facts may take. The longest description takes about a quarter of it on a Mac.
    let extraction: Duration
    /// How long each request that writes a section, or repairs one, may take.
    let section: Duration

    static let standard = DraftingLimits(extraction: .seconds(90), section: .seconds(30))
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
        within limit: Duration, retried: (any Error) -> Void = { _ in },
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

    private static func once<Value: Sendable>(
        within limit: Duration, _ work: @escaping @Sendable @MainActor () async throws -> Value
    ) async throws -> Value {
        let call = Task { @MainActor in try await work() }
        let deadline = Deadline()
        let timer = Task { @MainActor in
            try await Task.sleep(for: limit)
            deadline.passed = true
            call.cancel()
        }
        defer { timer.cancel() }
        do {
            return try await withTaskCancellationHandler { try await call.value } onCancel: { call.cancel() }
        } catch {
            try Task.checkCancellation()
            // A call stopped by its deadline reports the cancellation, or an error of its own.
            if deadline.passed { throw CVGenerationError.generationFailed }
            throw error
        }
    }

    /// Whether the time of a call ran out.
    @MainActor
    private final class Deadline {
        var passed = false
    }
}
