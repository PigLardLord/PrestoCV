import PrestoCVTipsStoreKit

/// What the composition starts at launch to listen to the store's tip transactions.
protocol TipsListening: Sendable {
    /// Starts listening. A second call does nothing.
    func start()
}

extension StoreKitTips: TipsListening {}
