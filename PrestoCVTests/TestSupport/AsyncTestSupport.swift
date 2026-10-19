import Foundation

/// Sleeps that last until the test ends them, so that a test decides when "a few seconds" have passed. A sleep whose
/// task is cancelled ends at once with `CancellationError`, as `Task.sleep` does.
actor HeldSleeps {
    private var sleepers: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var cancelled: Set<UUID> = []
    private(set) var startedCount = 0
    private var startWaiters = CountWaiters()

    var sleepingCount: Int { sleepers.count }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                start(id, continuation)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    /// Ends every sleep going on: their time has passed.
    func endAll() {
        let ending = sleepers.values
        sleepers = [:]
        ending.forEach { $0.resume() }
    }

    /// Returns once `count` sleeps have started since this was made, or when the task that waits is cancelled.
    func waitUntilStarted(_ count: Int) async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                startWaiters.add(id, waitingFor: count, continuation, reached: startedCount)
            }
        } onCancel: {
            Task { await self.stopWaiting(id) }
        }
    }

    private func stopWaiting(_ id: UUID) {
        startWaiters.cancel(id)
    }

    private func start(_ id: UUID, _ continuation: CheckedContinuation<Void, Error>) {
        guard !cancelled.contains(id) else {
            continuation.resume(throwing: CancellationError())
            return
        }
        sleepers[id] = continuation
        startedCount += 1
        startWaiters.reach(startedCount)
    }

    private func cancel(_ id: UUID) {
        guard let continuation = sleepers.removeValue(forKey: id) else {
            cancelled.insert(id)
            return
        }
        continuation.resume(throwing: CancellationError())
    }
}

/// Waiters for a count to reach a value. Each is resumed once: when the count gets there, or when it stops waiting.
struct CountWaiters {
    private var waiters: [UUID: (count: Int, continuation: CheckedContinuation<Void, Never>)] = [:]
    private var stopped: Set<UUID> = []

    mutating func add(_ id: UUID, waitingFor count: Int, _ continuation: CheckedContinuation<Void, Never>, reached: Int) {
        guard reached < count, !stopped.contains(id) else {
            continuation.resume()
            return
        }
        waiters[id] = (count, continuation)
    }

    mutating func reach(_ value: Int) {
        for (id, waiter) in waiters where waiter.count <= value {
            waiters[id] = nil
            waiter.continuation.resume()
        }
    }

    mutating func cancel(_ id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else {
            stopped.insert(id)
            return
        }
        waiter.continuation.resume()
    }
}

/// The bound on a wait for something that must happen. It is generous: it costs time only when the code is broken, and
/// the test host may be busy with suites that run beside it.
let patience: Duration = .seconds(60)

/// Runs `operation`, and tells whether it finished within `timeout`. The operation must end when it is cancelled.
func finishes(within timeout: Duration = patience, _ operation: @escaping @Sendable () async -> Void) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            await operation()
            return !Task.isCancelled
        }
        group.addTask {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return true
            }
            return false
        }
        let first = await group.next() ?? false
        group.cancelAll()
        return first
    }
}
