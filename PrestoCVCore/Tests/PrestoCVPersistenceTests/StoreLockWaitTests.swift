import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

// MARK: Test doubles

/// The store's lock, taken by the test through a descriptor of its own: what another instance or another process holds.
final class ForeignLock: Sendable {
    struct NotTaken: Error {}
    private let fd: Int32

    init(_ dir: URL, exclusive: Bool = true) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fd = open(dir.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard fd >= 0, flock(fd, (exclusive ? LOCK_EX : LOCK_SH) | LOCK_NB) == 0 else { throw NotTaken() }
    }

    /// Releases the lock; a second call does nothing.
    func release() { flock(fd, LOCK_UN) }
    deinit { close(fd) }
}

/// A pause that does not wait: it counts its calls, and on the call given runs an action, such as releasing a lock.
actor PauseLog {
    private(set) var calls = 0
    private let trigger: Int, action: @Sendable () -> Void

    init(on trigger: Int = 0, _ action: @escaping @Sendable () -> Void = {}) { self.trigger = trigger; self.action = action }

    func pause() {
        calls += 1
        if calls == trigger { action() }
    }

    /// A wait whose pauses are this log's.
    nonisolated func wait(deadline: Duration = .milliseconds(100), interval: Duration = .milliseconds(25)) -> StoreOptions.LockWait {
        StoreOptions.LockWait(deadline: deadline, interval: interval) { _ in await self.pause() }
    }
}

/// A wait that only yields, with a budget no contention in a test reaches: the tests of many writers use it.
let yieldingWait = StoreOptions.LockWait(deadline: .seconds(3600), interval: .milliseconds(1)) { _ in await Task.yield() }

func repo(_ dir: URL, wait: StoreOptions.LockWait, clock: any TimeSource = SteppingClock()) -> FileCVRepository {
    FileCVRepository(directory: dir, clock: clock, options: StoreOptions(protection: .unprotected, lockWait: wait))
}

/// Runs `operation`, and if it has not returned within `bound` releases `lock`, so that a call stuck in a blocking
/// `flock` returns and the test fails instead of hanging (R10). The bound only elapses in a red run.
func releasing<T: Sendable>(_ lock: ForeignLock, after bound: Duration = .seconds(10), _ operation: () async -> T) async -> T {
    let watchdog = Task {
        do { try await Task.sleep(for: bound) } catch { return }   // cancelled: the call returned in time
        Issue.record("the call did not return within \(bound): it waits for the lock without suspending")
        lock.release()
    }
    let result = await operation()
    watchdog.cancel()
    return result
}

/// The outcome of a call, so a call can run inside `releasing`. Untyped: a closure is inferred as `throws(any Error)`.
func outcome<T>(_ call: () async throws -> T) async -> Result<T, any Error> {
    do { return .success(try await call()) } catch { return .failure(error) }
}

/// The CV files in `dir`: the names a save writes.
func storedFiles(_ dir: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".cv.json") }.sorted()
}

// MARK: Tests

@Suite("R12 · the wait for the store lock is bounded and never holds a thread", .timeLimit(.minutes(1)))
struct StoreLockWaitTests {
    @Test("lock held by another descriptor: the wait ends in lockTimeout")
    func lockTimeout() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let foreign = try ForeignLock(dir)
        let pauses = PauseLog()
        let result = await releasing(foreign) { await outcome { try await repo(dir, wait: pauses.wait()).create(named("Ada")) } }
        #expect(result.failure as? RepositoryError == .storeUnavailable(.lockTimeout))
        #expect(await pauses.calls == 4)   // a deadline of 100 ms in pauses of 25 ms
        #expect(storedFiles(dir).isEmpty)
    }

    @Test("a lock held past the deadline leaves the stored CV as it was")
    func lockTimeoutKeepsTheFile() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let stored = try await repo(dir).create(named("Ada"))
        let before = try Data(contentsOf: dir.appendingPathComponent(fileName(stored.id)))
        let foreign = try ForeignLock(dir)
        var renamed = stored; renamed.rename("Grace")
        let result = await releasing(foreign) { await outcome { try await repo(dir, wait: PauseLog().wait()).update(renamed) } }
        #expect(result.failure as? RepositoryError == .storeUnavailable(.lockTimeout))
        #expect(try Data(contentsOf: dir.appendingPathComponent(fileName(stored.id))) == before)
    }

    @Test("the lock is released during the wait: the operation completes")
    func releasedDuringTheWait() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let foreign = try ForeignLock(dir)
        let pauses = PauseLog(on: 3) { foreign.release() }
        let r = repo(dir, wait: pauses.wait())
        let result = await releasing(foreign) { await outcome { try await r.create(named("Ada")) } }
        #expect(result.success?.revision == 1)
        #expect(await pauses.calls == 3)
        #expect(storedFiles(dir) == [fileName(id1)])
        #expect(try await r.list().cvs.map(\.id) == [id1])
    }

    @Test("a listing waits for the lock like a write, and ends in lockTimeout")
    func listingWaits() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await repo(dir).create(named("Ada"))
        let foreign = try ForeignLock(dir)
        let pauses = PauseLog()
        let result = await releasing(foreign) { await outcome { try await repo(dir, wait: pauses.wait()).list() } }
        #expect(result.failure as? RepositoryError == .storeUnavailable(.lockTimeout))
        #expect(await pauses.calls == 4)
    }

    @Test("a cancelled call keeps waiting until the deadline, and ends in lockTimeout, not in another error")
    func cancelledCallKeepsWaiting() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let foreign = try ForeignLock(dir)
        let pauses = PauseLog()
        let r = repo(dir, wait: pauses.wait())
        let result = await releasing(foreign) {
            let call = Task { await outcome { try await r.create(named("Ada")) } }
            call.cancel()
            return await call.value
        }
        #expect(result.failure as? RepositoryError == .storeUnavailable(.lockTimeout))
        #expect(await pauses.calls == 4)
    }

    @Test("an interval of zero or less cannot make the wait endless: it ends in lockTimeout after a bounded number of pauses",
          arguments: [Duration.zero, .milliseconds(-25)])
    func nonpositiveIntervalStaysBounded(interval: Duration) async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let foreign = try ForeignLock(dir)
        // A regression retries forever: the cap releases the lock at the 1000th pause, so the call ends and the test fails.
        let pauses = PauseLog(on: 1000) { foreign.release() }
        let wait = pauses.wait(deadline: .milliseconds(10), interval: interval)
        let result = await releasing(foreign) { await outcome { try await repo(dir, wait: wait).create(named("Ada")) } }
        #expect(result.failure as? RepositoryError == .storeUnavailable(.lockTimeout))
        #expect(await pauses.calls == 10)   // a deadline of 10 ms in steps of the smallest interval, 1 ms
        #expect(storedFiles(dir).isEmpty)
    }

    @Test("the app's own pause, on a cancelled call: it waits to the deadline and ends in lockTimeout, not in a cancellation")
    func standardPauseIgnoresCancellation() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let foreign = try ForeignLock(dir)
        let wait = StoreOptions.LockWait(deadline: .milliseconds(100), interval: .milliseconds(25), pause: StoreOptions.LockWait.standardPause)
        let r = repo(dir, wait: wait)
        let clock = ContinuousClock()
        let started = clock.now
        let result = await releasing(foreign) {
            let call = Task { await outcome { try await r.create(named("Ada")) } }
            call.cancel()
            return await call.value
        }
        #expect(result.failure as? RepositoryError == .storeUnavailable(.lockTimeout))
        #expect(clock.now - started >= .milliseconds(50))   // generous: four real pauses of 25 ms
        #expect(storedFiles(dir).isEmpty)
    }

    @Test("a waiting save does not block the executor")
    func waitingSaveFreesTheExecutor() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let executor = OneThreadExecutor(); defer { executor.stop() }
        let foreign = try ForeignLock(dir)
        let (entered, enter) = AsyncStream.makeStream(of: Void.self)
        let (gate, open) = AsyncStream.makeStream(of: Void.self)
        let wait = StoreOptions.LockWait(deadline: .seconds(3600), interval: .milliseconds(25)) { _ in
            enter.yield()
            for await _ in gate {}   // suspends until the test opens the gate
        }
        let clock = ThreadNotingClock(executor)
        let r = repo(dir, wait: wait, clock: clock)
        let saving = Task(executorPreference: executor) {
            let result = await outcome { try await r.create(named("Ada")) }
            enter.finish()   // a save that never paused ends the wait for the pause
            return result
        }

        let paused = await releasing(foreign) { await signalled(entered) }
        #expect(paused, "the save never reached the pause")
        // While the save waits, the executor's only thread runs another task.
        let ran = await releasing(foreign) { await Task(executorPreference: executor) { executor.isCurrent }.value }
        #expect(ran)

        foreign.release(); open.finish()
        #expect(await saving.value.success?.revision == 1)
        #expect(clock.sawOnlyTheExecutor, "the store's work ran off the executor, so the test shows nothing")
    }

    @Test("contention on both instances never loses an update")
    func contentionLosesNothing() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let stores = [repo(dir, wait: yieldingWait), repo(dir, wait: yieldingWait)]
        let ids = (0..<8).map { _ in CVID(UUID()) }
        let start = Barrier(count: ids.count)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (n, id) in ids.enumerated() {
                group.addTask {
                    await start.arrive()
                    _ = try await stores[n % 2].create(named("CV \(n)", id: id))
                }
            }
            try await group.waitForAll()
        }
        let listing = try await stores[0].list()
        #expect(Set(listing.cvs.map(\.id)) == Set(ids))
        #expect(listing.issues.isEmpty)
    }

    @Test(".lock is a symbolic link or a directory: cannotLock, not lockTimeout", arguments: ["link", "directory"])
    func lockNotAFile(kind: String) async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lock = dir.appendingPathComponent(".lock")
        if kind == "link" {
            try FileManager.default.createSymbolicLink(at: lock, withDestinationURL: dir.appendingPathComponent("elsewhere"))
        } else {
            try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: false)
        }
        let pauses = PauseLog()
        await #expect(throws: RepositoryError.storeUnavailable(.cannotLock)) { _ = try await repo(dir, wait: pauses.wait()).create(named("Ada")) }
        #expect(await pauses.calls == 0)
        #expect(storedFiles(dir).isEmpty)
    }

    @Test("the app's wait is ten seconds, in pauses of 25 milliseconds")
    func standardWait() {
        let wait = StoreOptions().lockWait
        #expect(wait.deadline == .seconds(10))
        #expect(wait.interval == .milliseconds(25))
    }
}

// MARK: Helpers of the executor test

/// Whether `stream` yields an element before it ends.
func signalled(_ stream: AsyncStream<Void>) async -> Bool {
    for await _ in stream { return true }
    return false
}

/// Lets tasks through only once `count` of them have arrived, so they start together. No sleep.
actor Barrier {
    private let count: Int
    private var waiting: [CheckedContinuation<Void, Never>] = []
    init(count: Int) { self.count = count }

    func arrive() async {
        if waiting.count + 1 == count {
            waiting.forEach { $0.resume() }; waiting.removeAll()
        } else {
            await withCheckedContinuation { waiting.append($0) }
        }
    }
}

/// A task executor with one thread of its own: while something holds that thread, no task that prefers it runs.
final class OneThreadExecutor: TaskExecutor, @unchecked Sendable {   // `jobs`, `stopped` and `thread` are guarded by `condition`
    private let condition = NSCondition()
    private var jobs: [UnownedJob] = [], stopped = false
    private var thread: pthread_t?

    init() { Thread { [self] in run() }.start() }

    /// Whether the caller runs on the executor's thread. `Thread.current.name` does not tell on Linux.
    var isCurrent: Bool {
        condition.lock(); defer { condition.unlock() }
        return thread.map { pthread_equal($0, pthread_self()) != 0 } ?? false
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        condition.lock(); jobs.append(job); condition.signal(); condition.unlock()
    }

    /// Ends the thread once the jobs enqueued so far have run.
    func stop() { condition.lock(); stopped = true; condition.signal(); condition.unlock() }

    private func run() {
        condition.lock(); thread = pthread_self(); condition.unlock()
        while true {
            condition.lock()
            while jobs.isEmpty, !stopped { condition.wait() }
            guard !jobs.isEmpty else { condition.unlock(); return }
            let job = jobs.removeFirst()
            condition.unlock()
            job.runSynchronously(on: asUnownedTaskExecutor())
        }
    }
}

/// A clock that notes whether every reading came from the executor's thread: the store's own work ran there.
final class ThreadNotingClock: TimeSource, @unchecked Sendable {   // `offThread` is guarded by `lock`
    private let executor: OneThreadExecutor, stepping = SteppingClock(), lock = NSLock()
    private var readings = 0, offThread = 0
    init(_ executor: OneThreadExecutor) { self.executor = executor }

    func now() -> Date {
        let on = executor.isCurrent
        lock.lock(); readings += 1; if !on { offThread += 1 }; lock.unlock()
        return stepping.now()
    }

    var sawOnlyTheExecutor: Bool { lock.lock(); defer { lock.unlock() }; return readings > 0 && offThread == 0 }
}

extension Result {
    var success: Success? { if case .success(let value) = self { value } else { nil } }
    var failure: Failure? { if case .failure(let error) = self { error } else { nil } }
}
