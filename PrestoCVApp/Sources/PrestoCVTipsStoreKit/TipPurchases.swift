#if canImport(StoreKit)
import DiagnosticLogging
import PrestoCVWorkflowPorts
import StoreKit

/// What the store answered to a purchase, before anything is finished: the transaction it sold, or why it sold none.
/// A test builds one without the store.
enum TipPurchaseAnswer: Sendable {
    case bought(TipTransaction)
    case cancelled
    /// The window of the tap closed before the sheet opened, so no purchase started.
    case windowClosed
    case pending
    case refused(TipFailure)
}

/// How what the store answered to a purchase reads as the port's values.
enum TipPurchases {
    /// A purchase the person cancelled is `cancelled`, a device that may not pay is refused as `notAllowed`, and every
    /// other fault as the offers' faults read (`unreachable` or `failed`).
    static func answer(to error: any Error) -> TipPurchaseAnswer {
        if let error = error as? StoreKitError, case .userCancelled = error { return .cancelled }
        if let error = error as? Product.PurchaseError, case .purchaseNotAllowed = error { return .refused(.notAllowed) }
        return .refused(TipProducts.failure(of: error))
    }

    /// Finishes the transaction the store sold, verified or not, since a tip grants nothing and one left unfinished comes
    /// back at every launch; one the store did not verify does not go through. A purchase whose window closed ends as one
    /// the person cancelled. The outcome is logged as a code only: never the product, the price or the transaction.
    static func settle(_ answer: TipPurchaseAnswer, logger: any DiagnosticLogger) async throws(TipFailure) -> TipPurchase {
        let ended: Result<TipPurchase, TipFailure>
        let outcome: StaticString
        switch answer {
        case .bought(let transaction):
            await transaction.finish()
            (ended, outcome) = transaction.isVerified
                ? (.success(.completed), "completed")
                : (.failure(.failed), "unverified")
        case .cancelled: (ended, outcome) = (.success(.cancelled), "cancelled")
        case .windowClosed: (ended, outcome) = (.success(.cancelled), "windowClosed")
        case .pending: (ended, outcome) = (.success(.pending), "pending")
        case .refused(.notAllowed): (ended, outcome) = (.failure(.notAllowed), "notAllowed")
        case .refused(.unreachable): (ended, outcome) = (.failure(.unreachable), "unreachable")
        case .refused(.failed): (ended, outcome) = (.failure(.failed), "failed")
        }
        logger.info(.tips, "tips.purchase.ended", .token("outcome", outcome))
        return try ended.get()
    }
}
#endif
