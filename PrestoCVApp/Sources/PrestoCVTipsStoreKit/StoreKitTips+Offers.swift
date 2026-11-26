#if canImport(StoreKit)
import PrestoCVWorkflowPorts
import StoreKit

/// The tips on offer (ADR 0040): what the tip jar screen reads. Only this file knows the product identifiers.
extension StoreKitTips: TipSelling {
    public var canPay: Bool {
        AppStore.canMakePayments
    }

    public func offers() async throws(TipFailure) -> [TipOffer] {
        let products: [Product]
        do {
            products = try await Product.products(for: TipProducts.identifiers)
        } catch {
            throw TipProducts.failure(of: error)
        }
        return TipProducts.offers(from: products.map { ($0.id, $0.displayPrice) })
    }
}

/// The three consumables and how what the store says about them reads as the port's values.
enum TipProducts {
    static let identifiers = [
        "com.PigLardLord.prestocv.tip.small", "com.PigLardLord.prestocv.tip.medium", "com.PigLardLord.prestocv.tip.large",
    ]

    /// The offers of the products the store gave, smallest first. A product that is not one of the three is left out.
    static func offers(from products: [(id: String, price: String)]) -> [TipOffer] {
        TipSize.allCases.compactMap { size in
            products.first { $0.id == identifier(of: size) }.map { TipOffer(size: size, price: $0.price) }
        }
    }

    /// A store that cannot be reached is `unreachable`; every other fault is `failed`.
    static func failure(of error: any Error) -> TipFailure {
        guard let error = error as? StoreKitError, case .networkError = error else { return .failed }
        return .unreachable
    }

    private static func identifier(of size: TipSize) -> String {
        switch size {
        case .small: identifiers[0]
        case .medium: identifiers[1]
        case .large: identifiers[2]
        }
    }
}
#endif
