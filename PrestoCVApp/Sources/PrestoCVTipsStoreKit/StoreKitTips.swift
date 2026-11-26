#if canImport(StoreKit)
import DiagnosticLogging
import StoreKit

/// The tips sold through the App Store (ADR 0040), as far as the app launches: it listens to the store's transactions and
/// finishes each one. It is made by the composition root, which holds it for as long as the app runs.
public final class StoreKitTips: Sendable {
    private let listener: TipTransactionListener

    public init(logger: any DiagnosticLogger) {
        listener = TipTransactionListener(feed: .store, logger: logger)
    }

    /// Starts listening. A second call does nothing.
    public func start() {
        listener.start()
    }
}

extension TipTransactionFeed {
    /// The store's own: the unfinished transactions, then the updates.
    fileprivate static let store = TipTransactionFeed(
        unfinished: { stream { Transaction.unfinished } }, updates: { stream { Transaction.updates } }
    )

    /// The results the store gives, one by one, with what finishes each. The sequence is made inside the task that reads it.
    private static func stream<Results: AsyncSequence>(
        of make: @escaping @Sendable () -> Results
    ) -> AsyncStream<TipTransaction> where Results.Element == VerificationResult<Transaction>, Results.Failure == Never {
        AsyncStream { continuation in
            let reading = Task {
                for await result in make() {
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
    fileprivate init(isVerified: Bool, transaction: Transaction) {
        self.init(isVerified: isVerified, finish: { await transaction.finish() })
    }
}
#endif
