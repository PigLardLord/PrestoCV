#if canImport(StoreKit)
import PrestoCVWorkflowPorts
import StoreKit
import Testing
@testable import PrestoCVTipsStoreKit

@Suite("The tips on offer")
struct TipProductsTests {
    @Test("the offers come smallest first, whatever order the store gave them in")
    func smallestFirst() {
        let offers = TipProducts.offers(from: [
            ("com.PigLardLord.prestocv.tip.large", "€9.99"), ("com.PigLardLord.prestocv.tip.small", "€1.99"),
            ("com.PigLardLord.prestocv.tip.medium", "€4.99"),
        ])

        #expect(offers == [
            TipOffer(size: .small, price: "€1.99"), TipOffer(size: .medium, price: "€4.99"), TipOffer(size: .large, price: "€9.99"),
        ])
    }

    @Test("a size the store did not give is left out, and a product that is not a tip is ignored")
    func missingAndForeign() {
        let offers = TipProducts.offers(from: [("com.PigLardLord.prestocv.tip.medium", "€4.99"), ("other", "€0.99")])

        #expect(offers == [TipOffer(size: .medium, price: "€4.99")])
    }

    @Test("the identifiers asked for are the three tips")
    func identifiersAskedFor() {
        #expect(TipProducts.identifiers.count == 3)
        #expect(Set(TipProducts.identifiers).count == 3)
    }

    @Test("a network error is unreachable, any other fault failed")
    func failures() {
        #expect(TipProducts.failure(of: StoreKitError.networkError(URLError(.notConnectedToInternet))) == .unreachable)
        #expect(TipProducts.failure(of: StoreKitError.unknown) == .failed)
        #expect(TipProducts.failure(of: URLError(.timedOut)) == .failed)
    }
}
#endif
