import Observation
import PrestoCVWorkflowPorts

/// The tip jar screen (ADR 0040): whether the offers are being read, are there, or cannot be shown, as codes the view
/// words (R13).
@MainActor
@Observable
public final class TipJarViewModel {

    public private(set) var state: TipJarState = .loading

    @ObservationIgnored private let selling: any TipSelling
    @ObservationIgnored private var latestRead = 0

    public init(selling: any TipSelling) {
        self.selling = selling
    }

    /// Reads the offers when the screen appears. A read that starts while another is still running replaces it: only
    /// the latest read sets the state, so an older one that ends late cannot overwrite a newer result.
    public func load() async {
        await read(startRead())
    }

    /// Reads the offers again after the person asks for it. The older read is replaced before the screen shows
    /// loading, so nothing it brings back can take the place of this one.
    public func retry() async {
        let number = startRead()
        state = .loading
        await read(number)
    }

    /// Takes the next read number, which makes every read started before it out of date at once.
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
