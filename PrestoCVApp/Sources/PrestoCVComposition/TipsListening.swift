import PrestoCVTipsStoreKit
import PrestoCVWorkflowPorts

/// What the composition starts at launch to listen to the store's tip transactions, and asks for the tip jar's offers.
protocol TipsListening: TipSelling {
    /// Starts listening. A second call does nothing.
    func start()
}

extension StoreKitTips: TipsListening {}
