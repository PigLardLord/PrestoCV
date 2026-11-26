import PrestoCVWorkflowPorts
import Synchronization
import Testing

@testable import PrestoCVPresentation

@MainActor
@Suite("TipJarViewModel")
struct TipJarViewModelTests {

    private let all = [
        TipOffer(size: .small, price: "€1.99"), TipOffer(size: .medium, price: "€4.99"),
        TipOffer(size: .large, price: "€9.99"),
    ]

    private let rows = [
        TipRow(size: .small, price: "€1.99"), TipRow(size: .medium, price: "€4.99"), TipRow(size: .large, price: "€9.99"),
    ]

    @Test("the model shows loading until it has read the offers")
    func loadingFirst() {
        let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all)))

        #expect(model.state == .loading)
    }

    @Test("the offers read are shown as given")
    func offersShown() async {
        let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all)))

        await model.load()

        #expect(model.state == .offers(rows))
    }

    @Test("a device that may not pay shows the reason and asks the store nothing")
    func notAllowed() async {
        let selling = StubTips(canPay: false, result: .success(all))
        let model = TipJarViewModel(selling: selling)

        await model.load()

        #expect(model.state == .unavailable(.notAllowed))
        #expect(selling.asked.withLock { $0 } == 0)
    }

    @Test("an empty answer, an unreachable store and any other fault each show their reason")
    func reasons() async {
        for (result, reason) in [
            (Result<[TipOffer], TipFailure>.success([]), TipUnavailability.noOffers),
            (.failure(.unreachable), .unreachable),
            (.failure(.failed), .failed),
        ] {
            let model = TipJarViewModel(selling: StubTips(canPay: true, result: result))

            await model.load()

            #expect(model.state == .unavailable(reason))
        }
    }

    @Test("retry reads the offers again and shows what the store gives now")
    func retryAfterFailure() async {
        let selling = StubTips(canPay: true, result: .failure(.unreachable))
        let model = TipJarViewModel(selling: selling)
        await model.load()

        selling.result.withLock { $0 = .success(all) }
        await model.retry()

        #expect(model.state == .offers(rows))
        #expect(selling.asked.withLock { $0 } == 2)
    }
}

/// Tips with a fixed answer, which the test may change, and a count of the times the offers were asked for.
final class StubTips: TipSelling {
    let canPay: Bool
    let result: Mutex<Result<[TipOffer], TipFailure>>
    let asked = Mutex(0)

    init(canPay: Bool, result: Result<[TipOffer], TipFailure>) {
        self.canPay = canPay
        self.result = Mutex(result)
    }

    func offers() async throws(TipFailure) -> [TipOffer] {
        asked.withLock { $0 += 1 }
        return try result.withLock { $0 }.get()
    }
}
