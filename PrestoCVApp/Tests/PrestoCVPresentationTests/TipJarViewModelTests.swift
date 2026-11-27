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

    @Test("an older request that ends while a retry waits leaves the screen loading")
    func olderRequestEndsDuringRetry() async {
        let selling = GatedTips()
        let model = TipJarViewModel(selling: selling)
        var arrivals = selling.arrivals.makeAsyncIterator()

        let older = Task { await model.load() }
        await arrivals.next()
        let newer = Task { await model.retry() }
        await arrivals.next()

        selling.finish(request: 0, with: .failure(.failed))
        await older.value
        #expect(model.state == .loading)

        selling.finish(request: 1, with: .success(all))
        await newer.value
        #expect(model.state == .offers(rows))
    }

    // MARK: - Buying a tip

    @Test("a completed purchase thanks the person, buys the size chosen and keeps the offers")
    func completedPurchaseThanks() async {
        let selling = StubTips(canPay: true, result: .success(all), purchased: .success(.completed))
        let model = TipJarViewModel(selling: selling)
        await model.load()

        await model.buy(.medium)

        #expect(model.attempt == .thanked)
        #expect(selling.bought.withLock { $0 } == [.medium])
        #expect(model.state == .offers(rows))
    }

    @Test("a purchase waiting for approval says so and keeps the offers")
    func pendingPurchase() async {
        let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all), purchased: .success(.pending)))
        await model.load()

        await model.buy(.small)

        #expect(model.attempt == .pending)
        #expect(model.state == .offers(rows))
    }

    @Test("a purchase the person cancels leaves the screen as it was")
    func cancelledPurchase() async {
        let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all), purchased: .success(.cancelled)))
        await model.load()

        await model.buy(.large)

        #expect(model.attempt == .idle)
        #expect(model.state == .offers(rows))
    }

    @Test("a purchase that fails says it did not go through, and an unreachable store says so, both keeping the offers")
    func failedPurchase() async {
        for (failure, attempt) in [(TipFailure.failed, TipAttempt.failed), (.unreachable, .unreachable)] {
            let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all), purchased: .failure(failure)))
            await model.load()

            await model.buy(.small)

            #expect(model.attempt == attempt)
            #expect(model.state == .offers(rows))
        }
    }

    @Test("a device the store says may not pay shows the reason in place of the offers")
    func purchaseNotAllowed() async {
        let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all), purchased: .failure(.notAllowed)))
        await model.load()

        await model.buy(.small)

        #expect(model.state == .unavailable(.notAllowed))
        #expect(model.attempt == .idle)
    }

    @Test("while a purchase runs, its row shows it and a second tap buys nothing")
    func secondTapWhileBuying() async {
        let selling = GatedTips()
        let model = TipJarViewModel(selling: selling)
        var arrivals = selling.arrivals.makeAsyncIterator()
        let loading = Task { await model.load() }
        await arrivals.next()
        selling.finish(request: 0, with: .success(all))
        await loading.value

        let first = Task { await model.buy(.small) }
        await arrivals.next()
        #expect(model.attempt == .buying(.small))
        await model.buy(.large)
        #expect(selling.bought.withLock { $0 } == [.small])
        #expect(model.attempt == .buying(.small))

        selling.finishPurchase(with: .success(.completed))
        await first.value
        #expect(model.attempt == .thanked)
    }

    @Test("an offers read that ends after a purchase found the device may not pay does not bring the offers back")
    func olderReadAfterPurchase() async {
        let selling = GatedTips()
        let model = TipJarViewModel(selling: selling)
        var arrivals = selling.arrivals.makeAsyncIterator()
        let loading = Task { await model.load() }
        await arrivals.next()
        selling.finish(request: 0, with: .success(all))
        await loading.value

        let reading = Task { await model.load() }
        await arrivals.next()
        let buying = Task { await model.buy(.small) }
        await arrivals.next()
        selling.finishPurchase(with: .failure(.notAllowed))
        await buying.value
        selling.finish(request: 1, with: .success(all))
        await reading.value

        #expect(model.state == .unavailable(.notAllowed))
    }

    @Test("the thank-you and the other notices of a purchase are gone when the screen opens again")
    func noticesLeaveWithTheScreen() async {
        let answers: [Result<TipPurchase, TipFailure>] = [
            .success(.completed), .success(.pending), .failure(.failed), .failure(.unreachable),
        ]
        for purchased in answers {
            let model = TipJarViewModel(selling: StubTips(canPay: true, result: .success(all), purchased: purchased))
            await model.load()
            await model.buy(.small)

            await model.load()

            #expect(model.attempt == .idle)
            #expect(model.state == .offers(rows))
        }
    }

    @Test("a purchase still running when the screen reads the offers again keeps its row busy")
    func readWhileBuying() async {
        let selling = GatedTips()
        let model = TipJarViewModel(selling: selling)
        var arrivals = selling.arrivals.makeAsyncIterator()
        let loading = Task { await model.load() }
        await arrivals.next()
        selling.finish(request: 0, with: .success(all))
        await loading.value
        let buying = Task { await model.buy(.medium) }
        await arrivals.next()

        let reading = Task { await model.load() }
        await arrivals.next()
        selling.finish(request: 1, with: .success(all))
        await reading.value

        #expect(model.attempt == .buying(.medium))
        selling.finishPurchase(with: .success(.cancelled))
        await buying.value
    }
}

/// Tips whose every offers call, and the first purchase, wait until the test finishes them, so the test decides the order
/// they end in. `arrivals` yields once per call that waits, when it is waiting.
final class GatedTips: TipSelling {
    let canPay = true
    let arrivals: AsyncStream<Void>
    private let arrived: AsyncStream<Void>.Continuation
    private let pending = Mutex<[CheckedContinuation<Result<[TipOffer], TipFailure>, Never>]>([])
    private let purchases = Mutex<[CheckedContinuation<Result<TipPurchase, TipFailure>, Never>]>([])
    let bought = Mutex<[TipSize]>([])

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

    /// The first purchase waits until the test finishes it; a later one completes at once, so a purchase that should not
    /// have started shows in `bought` without holding the test.
    func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase {
        guard bought.withLock({ sizes in
            sizes.append(size)
            return sizes.count == 1
        }) else { return .completed }
        let result = await withCheckedContinuation { continuation in
            purchases.withLock { $0.append(continuation) }
            arrived.yield()
        }
        return try result.get()
    }

    /// Ends the offers call that came `request`th (from 0) with `result`.
    func finish(request: Int, with result: Result<[TipOffer], TipFailure>) {
        pending.withLock { $0[request] }.resume(returning: result)
    }

    /// Ends the first purchase with `result`.
    func finishPurchase(with result: Result<TipPurchase, TipFailure>) {
        purchases.withLock { $0[0] }.resume(returning: result)
    }
}

/// Tips with fixed answers, which the test may change, a count of the times the offers were asked for and the sizes
/// bought.
final class StubTips: TipSelling {
    let canPay: Bool
    let result: Mutex<Result<[TipOffer], TipFailure>>
    let purchased: Mutex<Result<TipPurchase, TipFailure>>
    let asked = Mutex(0)
    let bought = Mutex<[TipSize]>([])

    init(
        canPay: Bool, result: Result<[TipOffer], TipFailure>,
        purchased: Result<TipPurchase, TipFailure> = .success(.completed)
    ) {
        self.canPay = canPay
        self.result = Mutex(result)
        self.purchased = Mutex(purchased)
    }

    func offers() async throws(TipFailure) -> [TipOffer] {
        asked.withLock { $0 += 1 }
        return try result.withLock { $0 }.get()
    }

    func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase {
        bought.withLock { $0.append(size) }
        return try purchased.withLock { $0 }.get()
    }
}
