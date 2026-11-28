import Synchronization

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
    /// device that may not pay `TipFailure.notAllowed`, a store that cannot be reached `TipFailure.unreachable`. The store's
    /// sheet opens in `window`, the window where the person tapped: an app with several windows must say which one. A
    /// purchase whose window has closed by the time the sheet would open starts nothing and ends as `cancelled`.
    func purchase(_ size: TipSize, in window: TipWindow) async throws(TipFailure) -> TipPurchase
}

/// The window where the person asked for a tip, as the adapter needs it to open the store's sheet there, and nothing a
/// screen or its model can read: the view that knows its window hands it over, and only the adapter opens it (R5). The
/// window is held weakly, so a window the person closes before the sheet opens is not kept alive, and the adapter reads it
/// again, on the main actor, when the purchase starts.
public struct TipWindow: Sendable {
    private let read: (@MainActor @Sendable () -> (any Sendable)?)?
    private let closure: TipWindowClosure?

    /// The window the view is in: its scene, or a Mac's window, which only the adapter knows how to read. A scene tells
    /// its own state, so nothing watches it.
    public init<Window: AnyObject & Sendable>(weak window: Window) {
        read = { [weak window] in window }
        closure = nil
    }

    /// The window the view is in, with the record of its closing (`TipWindowClosure`), whose watch the view started at the
    /// tap, before the purchase begins: a Mac's window does not say that it closed.
    public init<Window: AnyObject & Sendable>(weak window: Window, closure: TipWindowClosure) {
        read = { [weak window] in window }
        self.closure = closure
    }

    private init() {
        read = nil
        closure = nil
    }

    /// No window known: the store picks the place of its sheet.
    public static let unknown = TipWindow()

    /// Whether a window was known at the tap, though it may have gone since.
    public var isKnown: Bool { read != nil }

    /// Whether the window was seen closing since the tap, even if it still exists: a closed window that is not released may
    /// stay among the app's windows. Always false for a window nothing watches.
    public var hasClosed: Bool { closure?.hasClosed ?? false }

    /// The window as it is now: nil once nothing else keeps it, and for `unknown`.
    @MainActor
    public func current() -> (any Sendable)? {
        read?()
    }
}

/// The record that a window closed since the tap. A Mac's window that is not released when closed may stay listed among the
/// app's windows, and a window of a hidden app is not visible, so only its closing says that it is gone. The view that
/// builds the `TipWindow` knows the platform: it starts the watch at the tap and calls `markClosed()` when the window
/// closes.
public final class TipWindowClosure: Sendable {
    private let closed = Mutex(false)

    public init() {}

    /// Records the closing, from whichever thread the window closes on.
    public func markClosed() {
        closed.withLock { $0 = true }
    }

    /// Whether the closing was recorded.
    public var hasClosed: Bool { closed.withLock { $0 } }
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
