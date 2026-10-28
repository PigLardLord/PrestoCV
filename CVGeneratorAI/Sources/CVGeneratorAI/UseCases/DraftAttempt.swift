import Foundation

/// How long each pass of a draft may take on the device (ADR 0031). A call of the on-device model that runs past its time is stopped:
/// a model caught repeating itself would otherwise run until its window fills, minutes later (#354).
struct DraftingLimits: Equatable, Sendable {
    /// How long the first pass, which extracts the facts, may take. The longest description takes about a quarter of it on a Mac.
    let extraction: Duration
    /// How long the second pass, which writes around the facts, may take.
    let writing: Duration

    static let standard = DraftingLimits(extraction: .seconds(90), writing: .seconds(45))
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
