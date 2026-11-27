#if canImport(StoreKit)
import PrestoCVWorkflowPorts
import StoreKit

/// The purchase of a tip (ADR 0040): the store's own sheet, then the transaction it sold finished, verified or not. A
/// purchase that waits for approval is finished by the listener when the store sends it.
extension StoreKitTips {
    public func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase {
        try await TipPurchases.settle(await Self.answer(buying: size), logger: logger)
    }

    private static func answer(buying size: TipSize) async -> TipPurchaseAnswer {
        do {
            guard let product = try await Product.products(for: [TipProducts.identifier(of: size)]).first else {
                return .refused(.failed)
            }
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                return .bought(TipTransaction(isVerified: true, transaction: transaction))
            case .success(.unverified(let transaction, _)):
                return .bought(TipTransaction(isVerified: false, transaction: transaction))
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .refused(.failed)
            }
        } catch {
            return TipPurchases.answer(to: error)
        }
    }
}
#endif
