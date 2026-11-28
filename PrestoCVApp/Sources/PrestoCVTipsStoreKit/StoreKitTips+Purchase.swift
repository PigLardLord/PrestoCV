#if canImport(StoreKit)
import PrestoCVWorkflowPorts
import StoreKit

/// The purchase of a tip (ADR 0040): the store's own sheet, then the transaction it sold finished, verified or not. A
/// purchase that waits for approval is finished by the listener when the store sends it.
extension StoreKitTips {
    public func purchase(_ size: TipSize, in window: TipWindow) async throws(TipFailure) -> TipPurchase {
        try await TipPurchases.settle(await Self.answer(buying: size, in: window), logger: logger)
    }

    /// Starts the purchase in the scene the view gave, so that the sheet opens in the window of the tap: `purchase()`
    /// picks a scene itself, which in an app with several windows may be another one. Without a scene (a window the
    /// view could not tell, or a platform with no scenes) the store picks.
    private static func start(_ product: Product, in window: TipWindow) async throws -> Product.PurchaseResult {
        #if canImport(UIKit)
        if let scene = window.handle as? UIScene {
            return try await product.purchase(confirmIn: scene)
        }
        #endif
        return try await product.purchase()
    }

    private static func answer(buying size: TipSize, in window: TipWindow) async -> TipPurchaseAnswer {
        do {
            guard let product = try await Product.products(for: [TipProducts.identifier(of: size)]).first else {
                return .refused(.failed)
            }
            switch try await start(product, in: window) {
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
