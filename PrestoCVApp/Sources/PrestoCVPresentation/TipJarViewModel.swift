import Observation
import PrestoCVWorkflowPorts

/// The window where the person tapped a tip, which a view hands to the model and the model hands on without reading it. The
/// port owns the type; the screens name it through here, as they may import no port (R5).
public typealias TipWindow = PrestoCVWorkflowPorts.TipWindow

/// The record that a Mac's window closed, which the view that builds a `TipWindow` starts at the tap. The port owns it too.
public typealias TipWindowClosure = PrestoCVWorkflowPorts.TipWindowClosure

/// The tip jar screen (ADR 0040): whether the offers are being read, are there, or cannot be shown, as codes the view
/// words (R13).
@MainActor
@Observable
public final class TipJarViewModel {

    public private(set) var state: TipJarState = .loading
    public private(set) var attempt: TipAttempt = .idle

    @ObservationIgnored private let selling: any TipSelling
    @ObservationIgnored private var latestRead = 0

    public init(selling: any TipSelling) {
        self.selling = selling
    }

    /// Reads the offers when the screen appears. A read that starts while another is still running replaces it: only
    /// the latest read sets the state, so an older one that ends late cannot overwrite a newer result. What became of an
    /// earlier tip leaves with the screen; a purchase still running keeps its row busy.
    public func load() async {
        if attempt.hasEnded { attempt = .idle }
        await read(startRead())
    }

    /// Reads the offers again after the person asks for it. The older read is replaced before the screen shows
    /// loading, so nothing it brings back can take the place of this one.
    public func retry() async {
        let number = startRead()
        state = .loading
        await read(number)
    }

    /// Buys the tip of this size through the store's sheet, which opens in the window where the person tapped, and shows
    /// what became of it. Called at the tap: the purchase starts at once, and the returned task ends with it. A tap while
    /// a purchase runs buys nothing and returns nil: only one purchase runs at a time. The person chose from the offers on
    /// screen, so a read started before the tap cannot replace them, nor hide what became of the purchase; a read started
    /// while it runs still can.
    ///
    /// `window` reads the window from the view, and only for a tap that starts a purchase: on a Mac each read starts a new
    /// watch of the window's closing in place of the last, so a refused tap that read it would end the watch of the
    /// purchase running, and that purchase could open its sheet in a window that closed.
    @discardableResult
    public func buy(_ size: TipRow.Size, in window: () -> TipWindow) -> Task<Void, Never>? {
        if case .buying = attempt { return nil }
        let tapped = window()
        startRead()
        attempt = .buying(size)
        return Task { await purchase(size, in: tapped) }
    }

    private func purchase(_ size: TipRow.Size, in window: TipWindow) async {
        do throws(TipFailure) {
            switch try await selling.purchase(TipSize(size), in: window) {
            case .completed: attempt = .thanked
            case .cancelled: attempt = .idle
            case .pending: attempt = .pending
            }
        } catch {
            switch error {
            case .notAllowed:
                // A read still running knows less than this answer: it may not bring the offers back
                startRead()
                attempt = .idle
                state = .unavailable(.notAllowed)
            case .unreachable: attempt = .unreachable
            case .failed: attempt = .failed
            }
        }
    }

    /// Takes the next read number, which makes every read started before it out of date at once.
    @discardableResult
    private func startRead() -> Int {
        latestRead += 1
        return latestRead
    }

    private func read(_ number: Int) async {
        guard selling.canPay else {
            state = .unavailable(.notAllowed)
            return
        }
        do throws(TipFailure) {
            let offers = try await selling.offers()
            guard number == latestRead else { return }
            state = offers.isEmpty ? .unavailable(.noOffers) : .offers(offers.map(TipRow.init))
        } catch {
            guard number == latestRead else { return }
            state = .unavailable(error == .unreachable ? .unreachable : .failed)
        }
    }
}

/// What the screen shows.
public enum TipJarState: Hashable, Sendable {
    case loading
    case offers([TipRow])
    case unavailable(TipUnavailability)
}

/// What became of the tip the person chose, as codes the view words (R13). A cancelled purchase shows nothing, as before it.
public enum TipAttempt: Hashable, Sendable {
    case idle
    case buying(TipRow.Size)
    case thanked
    case pending
    case failed
    case unreachable

    /// The purchase is over and its notice is on screen.
    var hasEnded: Bool {
        switch self {
        case .idle, .buying: false
        case .thanked, .pending, .failed, .unreachable: true
        }
    }
}

/// Why there is nothing to buy.
public enum TipUnavailability: Hashable, Sendable {
    case notAllowed, unreachable, noOffers, failed
}

/// One tip the screen offers: its size, which the view words, and its price as the store writes it.
public struct TipRow: Hashable, Sendable, Identifiable {
    public enum Size: Hashable, Sendable { case small, medium, large }

    public let size: Size
    public let price: String
    public var id: Size { size }

    init(size: Size, price: String) {
        self.size = size
        self.price = price
    }

    init(_ offer: TipOffer) {
        size = switch offer.size {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
        price = offer.price
    }
}

extension TipSize {
    init(_ size: TipRow.Size) {
        self = switch size {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
}
