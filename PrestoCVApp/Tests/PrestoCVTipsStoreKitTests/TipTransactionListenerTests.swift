#if canImport(StoreKit)
import DiagnosticLogging
import Synchronization
import Testing
@testable import PrestoCVTipsStoreKit

@Suite("The listener of the tip transactions")
struct TipTransactionListenerTests {
    @Test("every unfinished transaction is finished, verified or not, and the count is logged")
    func unfinishedAreFinished() async {
        let world = World(unfinished: [true, false, true])
        let listener = world.makeListener()

        listener.start()
        let entry = await world.logger.next()

        #expect(world.finishes.count == 3, "each of the three is finished, the unverified one too")
        #expect(entry?.event.description == "tips.unfinished.finished")
        #expect(entry?.level == .info)
        #expect(entry?.fields == [.count("count", 3), .count("unverified", 1)])
    }

    @Test("with no unfinished transaction the count logged is zero")
    func nothingUnfinished() async {
        let world = World(unfinished: [])
        let listener = world.makeListener()

        listener.start()
        let entry = await world.logger.next()

        #expect(world.finishes.count == 0)
        #expect(entry?.fields == [.count("count", 0), .count("unverified", 0)])
    }

    @Test("a transaction that arrives is finished and logged by whether it was verified", arguments: [true, false])
    func updateIsFinished(verified: Bool) async {
        let world = World(unfinished: [])
        let listener = world.makeListener()
        listener.start()
        _ = await world.logger.next()

        world.updates.send(id: 100, verified: verified)
        let entry = await world.logger.next()

        #expect(world.finishes.count == 1)
        #expect(entry?.event.description == "tips.update.finished")
        #expect(entry?.fields == [.flag("verified", verified)])
    }

    @Test("the id of an update is not kept: the same one handed over again is finished again")
    func updateIdsAreNotRetained() async {
        let world = World(unfinished: [])
        let listener = world.makeListener()
        listener.start()
        _ = await world.logger.next()

        world.updates.send(id: 100, verified: true)
        world.updates.send(id: 100, verified: true)
        _ = await world.logger.next()
        _ = await world.logger.next()

        #expect(world.finishes.count == 2, "only the ids of the unfinished stream are remembered, and 100 was not one")
    }

    @Test("an id seen in both streams is finished once, and forgotten after its update")
    func unfinishedIdIsSkippedOnceInTheUpdates() async {
        let world = World(unfinished: [true])
        let listener = world.makeListener()
        world.updates.send(id: 1, verified: true)
        world.updates.send(id: 1, verified: true)

        listener.start()
        _ = await world.logger.next()
        _ = await world.logger.next()

        #expect(world.finishes.order == ["unfinished", "update"], "the first update of 1 is the overlap and is skipped; the id is then forgotten, so a later one is finished")
    }

    @Test("a transaction both streams hand over is finished and logged once")
    func transactionInBothStreamsIsFinishedOnce() async {
        let world = World(unfinished: [true, true])
        let listener = world.makeListener()
        world.updates.send(id: 2, verified: true)
        world.updates.send(id: 100, verified: false)

        listener.start()
        let unfinished = await world.logger.next()
        let update = await world.logger.next()

        #expect(unfinished?.fields == [.count("count", 2), .count("unverified", 0)])
        #expect(update?.fields == [.flag("verified", false)], "the update of 2, finished with the unfinished ones, is skipped: 100 is the first update logged")
        #expect(world.finishes.order == ["unfinished", "unfinished", "update"], "the unfinished 1 and 2, then only 100 from the updates")
    }

    @Test("the unfinished are all finished before the first update is read")
    func unfinishedComeFirst() async {
        let world = World(unfinished: [true, true])
        let listener = world.makeListener()
        world.updates.send(id: 100, verified: true)

        listener.start()
        _ = await world.logger.next()
        _ = await world.logger.next()

        #expect(world.finishes.order == ["unfinished", "unfinished", "update"])
    }

    @Test("an update delivered while an unfinished transaction is still being finished is finished without another launch")
    func updateDuringTheDrainIsFinished() async {
        let finishes = FinishLog()
        let subscribed = Inbox<Void>()
        let release = Inbox<Void>()
        let started = Inbox<Void>()
        let logger = InboxLogger()
        let held = TipTransaction(id: 1, isVerified: true, finish: {
            started.put(())
            _ = await release.next()
            finishes.record("unfinished")
        })
        let update = TipTransaction(id: 100, isVerified: true, finish: { finishes.record("update") })
        let listener = TipTransactionListener(
            feed: TipTransactionFeed(
                unfinished: { AsyncStream { continuation in continuation.yield(held); continuation.finish() } },
                updates: {
                    // Like the store's: nothing is delivered before the stream is first read.
                    let sent = Mutex(false)
                    return AsyncStream {
                        subscribed.put(())
                        guard sent.withLock({ let was = $0; $0 = true; return !was }) else {
                            try? await Task.sleep(for: .seconds(60))
                            return nil
                        }
                        return update
                    }
                }
            ),
            logger: logger
        )

        listener.start()
        _ = await started.next()
        let read = await subscribed.next()
        release.put(())
        _ = await logger.next()
        _ = await logger.next()

        #expect(read != nil, "the updates are read while the unfinished transaction is still being finished")
        #expect(finishes.order == ["unfinished", "update"], "the update is finished in the same launch")
    }

    @Test("a second start does not read the feed again")
    func startIsOnce() async {
        let world = World(unfinished: [true])
        let listener = world.makeListener()

        listener.start()
        listener.start()
        _ = await world.logger.next()

        #expect(world.reads.unfinished == 1, "the unfinished transactions are read once")
        #expect(world.reads.updates == 1, "the updates are read once")
    }

    @Test("dropping the listener ends its reading of the updates")
    func droppingEndsTheReading() async {
        let world = World(unfinished: [])
        var listener: TipTransactionListener? = world.makeListener()
        listener?.start()
        _ = await world.logger.next()

        listener = nil

        #expect(await world.updates.ended.next() != nil, "the stream of the updates is cancelled once the listener is gone")
    }
}

// MARK: - The world of a test

/// Feeds the test controls, and what a listener over them finished, read and logged.
private struct World {
    let unfinished: [Bool]
    let logger = InboxLogger()
    let finishes: FinishLog
    let reads = FeedReads()
    let updates: UpdatesFeed

    init(unfinished: [Bool]) {
        let finishes = FinishLog()
        self.unfinished = unfinished
        self.finishes = finishes
        updates = UpdatesFeed(finishes: finishes)
    }

    func makeListener() -> TipTransactionListener {
        let finishes = finishes
        let reads = reads
        let updates = updates
        let items = unfinished.enumerated().map { index, verified in
            TipTransaction(id: UInt64(index + 1), isVerified: verified, finish: { finishes.record("unfinished") })
        }
        return TipTransactionListener(
            feed: TipTransactionFeed(
                unfinished: {
                    reads.readUnfinished()
                    return AsyncStream { continuation in
                        for item in items { continuation.yield(item) }
                        continuation.finish()
                    }
                },
                updates: {
                    reads.readUpdates()
                    return updates.stream
                }
            ),
            logger: logger
        )
    }
}

/// The updates the test sends, and a signal for when the listener stops reading them.
private final class UpdatesFeed: Sendable {
    let stream: AsyncStream<TipTransaction>
    let ended = Inbox<Void>()
    private let continuation: AsyncStream<TipTransaction>.Continuation
    private let finishes: FinishLog

    init(finishes: FinishLog) {
        let ended = ended
        let (stream, continuation) = AsyncStream<TipTransaction>.makeStream()
        continuation.onTermination = { _ in ended.put(()) }
        self.stream = stream
        self.continuation = continuation
        self.finishes = finishes
    }

    func send(id: UInt64, verified: Bool) {
        let finishes = finishes
        continuation.yield(TipTransaction(id: id, isVerified: verified, finish: { finishes.record("update") }))
    }
}

/// Which finish ran, in order.
private final class FinishLog: Sendable {
    private let recorded = Mutex<[String]>([])

    func record(_ source: String) { recorded.withLock { $0.append(source) } }
    var order: [String] { recorded.withLock { $0 } }
    var count: Int { order.count }
}

/// How many times each stream was asked for.
private final class FeedReads: Sendable {
    private let counts = Mutex<[Int]>([0, 0])

    func readUnfinished() { counts.withLock { $0[0] += 1 } }
    func readUpdates() { counts.withLock { $0[1] += 1 } }
    var unfinished: Int { counts.withLock { $0[0] } }
    var updates: Int { counts.withLock { $0[1] } }
}

/// What has been put and what a caller waits for, in order. A wait that gets nothing in ten seconds gives nil, so a
/// missing event fails the test instead of hanging it.
private final class Inbox<Element: Sendable>: Sendable {
    private struct State {
        var queued: [Element] = []
        var waiting: CheckedContinuation<Element?, Never>?
    }

    private let state = Mutex(State())

    func put(_ element: Element) {
        let waiting = state.withLock { state -> CheckedContinuation<Element?, Never>? in
            guard let waiting = state.waiting else {
                state.queued.append(element)
                return nil
            }
            state.waiting = nil
            return waiting
        }
        waiting?.resume(returning: element)
    }

    func next() async -> Element? {
        let timer = Task {
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }
            self.giveUp()
        }
        defer { timer.cancel() }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Element?, Never>) in
            let ready = state.withLock { state -> Element? in
                guard state.queued.isEmpty else { return state.queued.removeFirst() }
                state.waiting = continuation
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }

    private func giveUp() {
        let waiting = state.withLock { state -> CheckedContinuation<Element?, Never>? in
            defer { state.waiting = nil }
            return state.waiting
        }
        waiting?.resume(returning: nil)
    }
}

/// A logger the test can wait on: each entry is handed over once, in order.
private final class InboxLogger: DiagnosticLogger {
    private let entries = Inbox<LogEntry>()

    func log(_ entry: LogEntry) { entries.put(entry) }

    func next() async -> LogEntry? { await entries.next() }
}
#endif
