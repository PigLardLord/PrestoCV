#if canImport(StoreKit)
import DiagnosticLogging
import StoreKit

/// The tips sold through the App Store (ADR 0040): at launch it listens to the store's transactions and finishes each one,
/// and the tip jar reads and buys through it. It is made by the composition root, which holds it for as long as the app
/// runs.
public final class StoreKitTips: Sendable {
    private let listener: TipTransactionListener
    let logger: any DiagnosticLogger

    public init(logger: any DiagnosticLogger) {
        listener = TipTransactionListener(feed: .store, logger: logger)
        self.logger = logger
    }

    /// Starts listening. A second call does nothing.
    public func start() {
        listener.start()
    }
}

extension TipTransactionFeed {
    /// The store's own: the unfinished transactions, then the updates.
    fileprivate static let store = TipTransactionFeed(
        unfinished: { stream(subscribed: {}) { Transaction.unfinished } },
        updates: { subscribed in stream(subscribed: subscribed) { Transaction.updates } }
    )

    /// The results the store gives, one by one, with what finishes each. The sequence is made inside the task that reads
    /// it, and `subscribed` is called there once its iterator exists, before the first element is awaited: that is the
    /// store's subscription, not the creation of this stream.
    private static func stream<Results: AsyncSequence>(
        subscribed: @escaping @Sendable () -> Void,
        of make: @escaping @Sendable () -> Results
    ) -> AsyncStream<TipTransaction> where Results.Element == VerificationResult<Transaction>, Results.Failure == Never {
        AsyncStream { continuation in
            let reading = Task {
                var results = make().makeAsyncIterator()
                subscribed()
                while let result = await results.next(isolation: nil) {
                    switch result {
                    case .verified(let transaction): continuation.yield(TipTransaction(isVerified: true, transaction: transaction))
                    case .unverified(let transaction, _): continuation.yield(TipTransaction(isVerified: false, transaction: transaction))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in reading.cancel() }
        }
    }
}

extension TipTransaction {
    init(isVerified: Bool, transaction: Transaction) {
        self.init(id: transaction.id, isVerified: isVerified, finish: { await transaction.finish() })
    }
}
#endif
