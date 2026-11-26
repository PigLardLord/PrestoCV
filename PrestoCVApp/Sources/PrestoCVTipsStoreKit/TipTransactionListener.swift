#if canImport(StoreKit)
import DiagnosticLogging
import Synchronization

extension LogCategory {
    /// What the app does with the tips sold through the App Store: for now, finishing the transactions it is handed.
    static let tips = LogCategory("tips")
}

/// One transaction as the listener sees it: whether the store verified it, and what finishes it. Nothing else of the
/// transaction is read, so a test builds one without the store.
struct TipTransaction: Sendable {
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
/// It walks the unfinished transactions first, then waits for the updates until it is dropped. Dropping it cancels the task.
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

    private static func listen(to feed: TipTransactionFeed, logger: any DiagnosticLogger) async {
        var finished = 0
        var unverified = 0
        for await transaction in feed.unfinished() {
            await transaction.finish()
            finished += 1
            if !transaction.isVerified { unverified += 1 }
        }
        logger.info(.tips, "tips.unfinished.finished", .count("count", finished), .count("unverified", unverified))
        for await transaction in feed.updates() {
            await transaction.finish()
            logger.info(.tips, "tips.update.finished", .flag("verified", transaction.isVerified))
        }
    }
}
#endif
