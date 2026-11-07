import Synchronization
@testable import CVGeneratorAI

/// A clock whose sleeps end only when the test says the time ran out (`runOut()`), or when their task is cancelled: a limit on it
/// never runs out by itself, however long the call or a busy main actor takes (#400). Its `now` is the continuous clock's.
final class TestCallClock: Clock, Sendable {
    typealias Instant = ContinuousClock.Instant

    private struct State {
        var sleepers: [(id: Int, wake: CheckedContinuation<Void, any Error>)] = []
        var nextID = 0
        /// Times that ran out while nobody slept: the next sleeps end at once.
        var owed = 0
    }

    private let state = Mutex(State())

    var now: Instant { .now }
    var minimumResolution: Duration { .zero }

    /// Ends the oldest sleep still running, or the next one to start.
    func runOut() {
        let woken = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            guard !state.sleepers.isEmpty else {
                state.owed += 1
                return nil
            }
            return state.sleepers.removeFirst().wake
        }
        woken?.resume()
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = state.withLock { state in
            defer { state.nextID += 1 }
            return state.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (wake: CheckedContinuation<Void, any Error>) in
                let outcome = state.withLock { state -> Result<Void, any Error>? in
                    if Task.isCancelled { return .failure(CancellationError()) }
                    if state.owed > 0 {
                        state.owed -= 1
                        return .success(())
                    }
                    state.sleepers.append((id, wake))
                    return nil
                }
                if let outcome { wake.resume(with: outcome) }
            }
        } onCancel: {
            let woken = state.withLock { state -> CheckedContinuation<Void, any Error>? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return state.sleepers.remove(at: index).wake
            }
            woken?.resume(throwing: CancellationError())
        }
    }
}

extension DraftingLimits {
    /// The app's times, on `clock`: a request of a draft, or its claim check, runs out of time only when the test says so.
    static func onTestClock(_ clock: TestCallClock = TestCallClock()) -> DraftingLimits {
        DraftingLimits(
            extraction: .seconds(90), section: .seconds(30),
            claimCheck: ClaimCheckLimits(batchSize: ClaimCheckLimits.standard.batchSize, time: ClaimCheckLimits.standard.time, on: clock),
            on: clock
        )
    }
}
