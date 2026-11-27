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

    @Test("an older request that ends after a newer one does not replace the newer result")
    func olderRequestEndsLast() async {
        let selling = GatedTips()
        let model = TipJarViewModel(selling: selling)
        var arrivals = selling.arrivals.makeAsyncIterator()

        let older = Task { await model.load() }
        await arrivals.next()
        let newer = Task { await model.retry() }
        await arrivals.next()

        selling.finish(request: 1, with: .success(all))
        await newer.value
        selling.finish(request: 0, with: .failure(.failed))
        await older.value

        #expect(model.state == .offers(rows))
    }
}

/// Tips whose every `offers()` call waits until the test finishes it, so the test decides the order they end in.
final class GatedTips: TipSelling {
    let canPay = true
    let arrivals: AsyncStream<Void>
    private let arrived: AsyncStream<Void>.Continuation
    private let pending = Mutex<[CheckedContinuation<Result<[TipOffer], TipFailure>, Never>]>([])

    init() {
        (arrivals, arrived) = AsyncStream.makeStream()
    }

    func offers() async throws(TipFailure) -> [TipOffer] {
        let result = await withCheckedContinuation { continuation in
            pending.withLock { $0.append(continuation) }
            arrived.yield()
        }
        return try result.get()
    }

    /// Ends the call that came `request`th (from 0) with `result`.
    func finish(request: Int, with result: Result<[TipOffer], TipFailure>) {
        pending.withLock { $0[request] }.resume(returning: result)
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
