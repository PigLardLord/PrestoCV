/// What the tip jar screen reads and buys (ADR 0040): whether this device may pay, the tips on offer with their prices, and
/// the purchase of one. The screen owns this port (R3); its adapter is the store's, so that no store type reaches a view
/// model (R5).
public protocol TipSelling: Sendable {
    /// Whether this device may pay at all: a parent's restriction or a managed device says no.
    var canPay: Bool { get }
    /// The tips on offer in the order of their sizes, with the prices the store gives. A size the store does not offer is
    /// left out. A store that cannot be reached throws `TipFailure.unreachable`, any other fault `TipFailure.failed`.
    func offers() async throws(TipFailure) -> [TipOffer]
    /// Buys the tip of this size through the store's own purchase sheet, and finishes what the store sold, verified or not:
    /// a tip unlocks nothing, so nothing is granted or kept. A tip the store did not verify throws `TipFailure.failed`, a
    /// device that may not pay `TipFailure.notAllowed`, a store that cannot be reached `TipFailure.unreachable`.
    func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase
}

/// The three sizes of a tip, smallest first.
public enum TipSize: Hashable, Sendable, CaseIterable {
    case small, medium, large
}

/// One tip on offer: its size and its price as the store writes it for this person.
public struct TipOffer: Hashable, Sendable {
    public let size: TipSize
    public let price: String

    public init(size: TipSize, price: String) {
        self.size = size
        self.price = price
    }
}

/// How a purchase the store answered ended: the tip was paid, the person cancelled it in the store's sheet, or it waits for
/// someone's approval (Ask to Buy, a slow payment), which the store then sends at a later launch or while the app runs.
public enum TipPurchase: Hashable, Sendable {
    case completed, cancelled, pending
}

/// Why the offers could not be read, or a tip could not be bought.
public enum TipFailure: Error, Hashable, Sendable {
    case notAllowed, unreachable, failed
}
