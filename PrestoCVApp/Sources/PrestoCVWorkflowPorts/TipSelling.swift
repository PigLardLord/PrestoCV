/// What the tip jar screen reads (ADR 0040): whether this device may pay, and the tips on offer with their prices. The
/// screen owns this port (R3); its adapter is the store's, so that no store type reaches a view model (R5).
public protocol TipSelling: Sendable {
    /// Whether this device may pay at all: a parent's restriction or a managed device says no.
    var canPay: Bool { get }
    /// The tips on offer in the order of their sizes, with the prices the store gives. A size the store does not offer is
    /// left out. A store that cannot be reached throws `TipFailure.unreachable`, any other fault `TipFailure.failed`.
    func offers() async throws(TipFailure) -> [TipOffer]
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

/// Why the offers could not be read.
public enum TipFailure: Error, Hashable, Sendable {
    case unreachable, failed
}
