#if canImport(StoreKit)
import DiagnosticLogging
import Synchronization

extension LogCategory {
    /// What the app does with the tips sold through the App Store: for now, finishing the transactions it is handed.
    static let tips = LogCategory("tips")
}

/// One transaction as the listener sees it: the store's id for it, whether the store verified it, and what finishes it.
/// Nothing else of the transaction is read, so a test builds one without the store. The id tells a transaction that both
/// streams hand over from two that are different; it is never logged.
struct TipTransaction: Sendable {
    let id: UInt64
    let isVerified: Bool
    let finish: @Sendable () async -> Void
}

/// Where the transactions come from: the ones the app was never told it finished, which end, and the ones that arrive
/// while the app runs, which do not. Each call makes a new stream.
struct TipTransactionFeed: Sendable {
    let unfinished: @Sendable () -> AsyncStream<TipTransaction>
    let updates: @Sendable () -> AsyncStream<TipTransaction>
}

/// Finishes every tip transaction the store hands over, verified or not, and grants nothing. A tip is a consumable: a
/// transaction left unfinished comes back at every launch.
///
/// It subscribes to the updates first, so none is missed while it finishes the unfinished transactions, then finishes the
/// unfinished ones, then the updates, until it is dropped. Dropping it cancels the task.
final class TipTransactionListener: Sendable {
    private let feed: TipTransactionFeed
    private let logger: any DiagnosticLogger
    private let task = Mutex<Task<Void, Never>?>(nil)

    init(feed: TipTransactionFeed, logger: any DiagnosticLogger) {
        self.feed = feed
        self.logger = logger
    }

    deinit {
        task.withLock { $0?.cancel() }
    }

    /// Starts listening. A second call does nothing.
    func start() {
        task.withLock { current in
            guard current == nil else { return }
            let feed = feed
            let logger = logger
            current = Task { await Self.listen(to: feed, logger: logger) }
        }
    }

    /// Finishes the unfinished transactions, then each update. The updates are read from the start, by a task that only
    /// buffers them (the drain starts once it has subscribed), so one the store delivers while the unfinished ones are being finished is kept, not lost. The store
    /// hands a transaction that is unfinished at launch to the updates too, once: the ids of the unfinished stream are
    /// kept, an update with one of them is skipped and its id dropped. The ids of the updates are not kept, so the set is
    /// bounded by the transactions unfinished at launch and empties as the overlaps arrive. Only this task finishes
    /// transactions and reads the ids, so they need no lock.
    private static func listen(to feed: TipTransactionFeed, logger: any DiagnosticLogger) async {
        let (buffered, buffer) = AsyncStream<TipTransaction>.makeStream()
        let (subscribed, subscription) = AsyncStream<Void>.makeStream()
        // One group holds the reader and the drain, so cancelling the listener cancels both, a suspended finish included.
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var updates = feed.updates().makeAsyncIterator()
                subscription.yield()
                subscription.finish()
                while let transaction = await updates.next() { buffer.yield(transaction) }
                buffer.finish()
            }
            group.addTask {
                for await _ in subscribed { break }
                var pending = Set<UInt64>()
                var finished = 0
                var unverified = 0
                for await transaction in feed.unfinished() where pending.insert(transaction.id).inserted {
                    await transaction.finish()
                    finished += 1
                    if !transaction.isVerified { unverified += 1 }
                }
                logger.info(.tips, "tips.unfinished.finished", .count("count", finished), .count("unverified", unverified))
                for await transaction in buffered where pending.remove(transaction.id) == nil {
                    await transaction.finish()
                    logger.info(.tips, "tips.update.finished", .flag("verified", transaction.isVerified))
                }
            }
        }
    }
}
#endif
