import Observation
import PrestoCVWorkflowPorts

/// The tip jar screen (ADR 0040): whether the offers are being read, are there, or cannot be shown, as codes the view
/// words (R13).
@MainActor
@Observable
public final class TipJarViewModel {

    public private(set) var state: TipJarState = .loading

    @ObservationIgnored private let selling: any TipSelling

    public init(selling: any TipSelling) {
        self.selling = selling
    }

    /// Reads the offers when the screen appears.
    public func load() async {
        guard selling.canPay else {
            state = .unavailable(.notAllowed)
            return
        }
        do throws(TipFailure) {
            let offers = try await selling.offers()
            state = offers.isEmpty ? .unavailable(.noOffers) : .offers(offers.map(TipRow.init))
        } catch {
            state = .unavailable(error == .unreachable ? .unreachable : .failed)
        }
    }

    /// Reads the offers again after the person asks for it.
    public func retry() async {
        state = .loading
        await load()
    }
}

/// What the screen shows.
public enum TipJarState: Hashable, Sendable {
    case loading
    case offers([TipRow])
    case unavailable(TipUnavailability)
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
