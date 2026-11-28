#if canImport(StoreKit)
import PrestoCVWorkflowPorts
import StoreKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The purchase of a tip (ADR 0040): the store's own sheet, then the transaction it sold finished, verified or not. A
/// purchase that waits for approval is finished by the listener when the store sends it.
extension StoreKitTips {
    /// The sheet opens in `window` if it is still open once the tip's product has loaded: a scene in the background still
    /// is, and so is a Mac's window in the Dock or of a hidden app (Cmd-H). A purchase whose window has closed (a scene that
    /// disconnected, a Mac's window closed, or one that is gone) does not start: no sheet opens in another window, nothing is
    /// charged, no error shows, and it ends as `cancelled`, as when the person cancels in the sheet, logged under its own
    /// code. Without a window known at the tap, the store picks the place of its sheet.
    public func purchase(_ size: TipSize, in window: TipWindow) async throws(TipFailure) -> TipPurchase {
        try await TipPurchases.settle(await Self.answer(buying: size, in: window), logger: logger)
    }

    /// Starts the purchase where `TipSheetPlace` says, checking the window on the main actor with nothing awaited before
    /// the store's call: `purchase()` picks a scene itself, which in an app with several windows may be another one. Nil
    /// when the window has closed and nothing started.
    @MainActor
    private static func start(_ product: Product, in window: TipWindow) async throws -> Product.PurchaseResult? {
        #if os(macOS)
        let place = TipSheetPlace<NSWindow>.of(window) { MacWindowFacts(of: $0).isOpen }
        if case .window(let shown) = place { return try await product.purchase(confirmIn: shown) }
        #else
        let place = TipSheetPlace<UIScene>.of(window) { $0.activationState != .unattached }
        if case .window(let scene) = place { return try await product.purchase(confirmIn: scene) }
        #endif
        if case .closed = place { return nil }
        return try await product.purchase()
    }

    private static func answer(buying size: TipSize, in window: TipWindow) async -> TipPurchaseAnswer {
        do {
            guard let product = try await Product.products(for: [TipProducts.identifier(of: size)]).first else {
                return .refused(.failed)
            }
            guard let result = try await start(product, in: window) else { return .windowClosed }
            switch result {
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
