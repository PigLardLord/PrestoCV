import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import CVDesignCatalog
@testable import CVDesignCatalogFileStore
import CVRenderingTestSupport

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

/// A pause that does not wait: it records the duration each call asks for, and on the call given runs an action, such as
/// releasing a lock.
actor PauseLog {
    private(set) var asked: [Duration] = []
    var calls: Int { asked.count }
    private let trigger: Int, action: @Sendable () -> Void

    init(on trigger: Int = 0, _ action: @escaping @Sendable () -> Void = {}) { self.trigger = trigger; self.action = action }

    func pause(_ duration: Duration) {
        asked.append(duration)
        if calls == trigger { action() }
    }

    /// A wait whose pauses are this log's: a deadline of 100 ms in pauses of 25 ms, so four pauses.
    nonisolated var wait: FileDesignStore.LockWait { wait() }

    nonisolated func wait(deadline: Duration = .milliseconds(100), interval: Duration = .milliseconds(25)) -> FileDesignStore.LockWait {
        FileDesignStore.LockWait(deadline: deadline, interval: interval) { await self.pause($0) }
    }
}

/// A deadline, an interval, and the pauses a wait under contention asks for with them.
struct LockWaitSteps: Sendable, CustomTestStringConvertible {
    let deadline: Duration, interval: Duration, pauses: [Duration]
    var testDescription: String { "deadline \(deadline), interval \(interval)" }

    static let cases = [
        LockWaitSteps(deadline: .milliseconds(100), interval: .seconds(60), pauses: [.milliseconds(100)]),
        LockWaitSteps(deadline: .milliseconds(100), interval: .milliseconds(75), pauses: [.milliseconds(75), .milliseconds(25)]),
        LockWaitSteps(deadline: .milliseconds(100), interval: .milliseconds(25), pauses: Array(repeating: .milliseconds(25), count: 4)),
    ]
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

extension Result {
    var success: Success? { if case .success(let value) = self { value } else { nil } }
    var failure: Failure? { if case .failure(let error) = self { error } else { nil } }
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

// MARK: Tests

@Suite("FileDesignStore · the wait for the lock is bounded and never holds a thread (#99)", .timeLimit(.minutes(1)))
struct FileDesignStoreLockWaitTests {
    @Test("a save while the lock is held elsewhere ends in lockTimeout, and writes nothing")
    func saveTimesOut() async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog()
            let design = try DesignStoreContract.design(id: "clean")
            let result = await releasing(foreign) { await outcome { try await FileDesignStore(directory: dir, lockWait: pauses.wait).save(design) } }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await pauses.calls == 4)
            #expect(!FileManager.default.fileExists(atPath: dir.index.path))
            #expect(dir.designFiles.isEmpty)
        }
    }

    @Test("a read while an exclusive lock is held elsewhere ends in lockTimeout", arguments: ["design", "installed"])
    func readTimesOut(call: String) async throws {
        try await inTemporaryStore { dir in
            try await FileDesignStore(directory: dir).save(DesignStoreContract.design(id: "clean"))
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog()
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait)
            let result = await releasing(foreign) {
                await outcome { call == "design" ? try await store.design(id: "clean")?.manifest.id : try await store.installedDesigns().first?.id }
            }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await pauses.calls == 4)
        }
    }

    @Test("the lock is released during a save's wait: the design is saved once")
    func saveCompletesAfterRelease() async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog(on: 3) { foreign.release() }
            let design = try DesignStoreContract.design(id: "clean")
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait)
            let result = await releasing(foreign) { await outcome { try await store.save(design) } }
            #expect(result.success != nil)
            #expect(await pauses.calls == 3)
            #expect(try await store.installedDesigns() == [design.manifest])
            #expect(dir.designFiles == ["clean.1.mcvt"])
        }
    }

    @Test("a shared reader waits for an exclusive writer held elsewhere, and reads once it is released")
    func readerWaitsForWriter() async throws {
        try await inTemporaryStore { dir in
            let design = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(design)
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog(on: 3) { foreign.release() }
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait)
            let result = await releasing(foreign) { await outcome { try await store.design(id: "clean") } }
            #expect(result.success??.manifest == design.manifest)
            #expect(await pauses.calls == 3)
        }
    }

    @Test("a shared lock held elsewhere lets a reader through at once, and makes a writer wait")
    func sharedLockElsewhere() async throws {
        try await inTemporaryStore { dir in
            let design = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(design)
            let foreign = try ForeignLock(dir, exclusive: false)
            let reads = PauseLog(), writes = PauseLog()
            let read = await releasing(foreign) { await outcome { try await FileDesignStore(directory: dir, lockWait: reads.wait).installedDesigns() } }
            #expect(read.success == [design.manifest])
            #expect(await reads.calls == 0)
            let bold = try DesignStoreContract.design(id: "bold")
            let write = await releasing(foreign) { await outcome { try await FileDesignStore(directory: dir, lockWait: writes.wait).save(bold) } }
            #expect(write.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await writes.calls == 4)
        }
    }

    @Test("a cancelled save keeps waiting until the deadline, and ends in lockTimeout, not in another error")
    func cancelledSaveKeepsWaiting() async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog()
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait)
            let design = try DesignStoreContract.design(id: "clean")
            let result = await releasing(foreign) {
                let call = Task { await outcome { try await store.save(design) } }
                call.cancel()
                return await call.value
            }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await pauses.calls == 4)
        }
    }

    @Test("an interval of zero or less cannot make the wait endless: it ends in lockTimeout after a bounded number of pauses",
          arguments: [Duration.zero, .milliseconds(-25)])
    func nonpositiveIntervalStaysBounded(interval: Duration) async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            // A regression retries forever: the cap releases the lock at the 1000th pause, so the call ends and the test fails.
            let pauses = PauseLog(on: 1000) { foreign.release() }
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait(deadline: .milliseconds(10), interval: interval))
            let design = try DesignStoreContract.design(id: "clean")
            let result = await releasing(foreign) { await outcome { try await store.save(design) } }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await pauses.calls == 10)   // a deadline of 10 ms in steps of the smallest interval, 1 ms
            #expect(dir.designFiles.isEmpty)
        }
    }

    @Test("a deadline and an interval near the largest duration: the wait ends in lockTimeout after two pauses, without overflowing")
    func hugeDurationsDoNotOverflow() async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog(on: 1000) { foreign.release() }
            // Int64.max seconds is 1/18.45 of the largest duration: the first pause stays under the deadline, a second full interval would pass the largest.
            let deadline = Duration.seconds(Int64.max) * 18 + .seconds(Int64.max / 5 * 2)
            let interval = Duration.seconds(Int64.max) * 9 + .seconds(Int64.max / 10 * 3)
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait(deadline: deadline, interval: interval))
            let design = try DesignStoreContract.design(id: "clean")
            let result = await releasing(foreign) { await outcome { try await store.save(design) } }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await pauses.asked == [interval, deadline - interval])   // the second pause asks only for what is left
            #expect(dir.designFiles.isEmpty)
        }
    }

    @Test("each pause asks for the interval, or only for what is left of the deadline: the wait never passes the deadline",
          arguments: LockWaitSteps.cases)
    func pausesStayWithinTheDeadline(steps: LockWaitSteps) async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            let pauses = PauseLog(on: 1000) { foreign.release() }
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait(deadline: steps.deadline, interval: steps.interval))
            let design = try DesignStoreContract.design(id: "clean")
            let result = await releasing(foreign) { await outcome { try await store.save(design) } }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(await pauses.asked == steps.pauses)
            #expect(dir.designFiles.isEmpty)
        }
    }

    @Test("the app's own pause, on a cancelled save: it waits to the deadline and ends in lockTimeout, not in a cancellation")
    func standardPauseIgnoresCancellation() async throws {
        try await inTemporaryStore { dir in
            let foreign = try ForeignLock(dir)
            let wait = FileDesignStore.LockWait(deadline: .milliseconds(100), interval: .milliseconds(25), pause: FileDesignStore.LockWait.standardPause)
            let store = FileDesignStore(directory: dir, lockWait: wait)
            let design = try DesignStoreContract.design(id: "clean")
            let clock = ContinuousClock()
            let started = clock.now
            let result = await releasing(foreign) {
                let call = Task { await outcome { try await store.save(design) } }
                call.cancel()
                return await call.value
            }
            #expect(result.failure as? FileDesignStoreError == .lockTimeout)
            #expect(clock.now - started >= .milliseconds(50))   // generous: four real pauses of 25 ms
            #expect(dir.designFiles.isEmpty)
        }
    }

    @Test("contention on both instances loses no save and no read")
    func contentionLosesNothing() async throws {
        try await inTemporaryStore { dir in
            let yielding = FileDesignStore.LockWait(deadline: .seconds(3600), interval: .milliseconds(1)) { _ in await Task.yield() }
            let stores = [FileDesignStore(directory: dir, lockWait: yielding), FileDesignStore(directory: dir, lockWait: yielding)]
            let designs = try (0..<8).map { try DesignStoreContract.design(id: "design-\($0)") }
            let start = Barrier(count: designs.count * 2)
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (n, design) in designs.enumerated() {
                    group.addTask { await start.arrive(); try await stores[n % 2].save(design) }
                    group.addTask { await start.arrive(); _ = try await stores[(n + 1) % 2].installedDesigns() }
                }
                try await group.waitForAll()
            }
            #expect(try await stores[0].installedDesigns() == designs.map(\.manifest).sorted { $0.id < $1.id })
        }
    }

    @Test(".lock is a symbolic link or a directory: unavailable, not lockTimeout", arguments: ["link", "directory"])
    func lockNotAFile(kind: String) async throws {
        try await inTemporaryStore { dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let lock = dir.appendingPathComponent(".lock")
            if kind == "link" {
                try FileManager.default.createSymbolicLink(at: lock, withDestinationURL: dir.appendingPathComponent("elsewhere"))
            } else {
                try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: false)
            }
            let pauses = PauseLog()
            let store = FileDesignStore(directory: dir, lockWait: pauses.wait)
            await #expect(throws: FileDesignStoreError.storeUnavailable) { try await store.save(DesignStoreContract.design(id: "clean")) }
            await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.installedDesigns() }
            #expect(await pauses.calls == 0)
            #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("elsewhere").path))
        }
    }

    @Test("the app's wait is ten seconds, in pauses of 25 milliseconds")
    func standardWait() {
        #expect(FileDesignStore.LockWait.standard.deadline == .seconds(10))
        #expect(FileDesignStore.LockWait.standard.interval == .milliseconds(25))
    }
}
