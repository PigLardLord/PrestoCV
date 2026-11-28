import CVRenderingTestSupport
import Foundation
import Synchronization
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// What listens to the tips, for the launches that do not look at the store.
struct NoTips: TipsListening {
    func start() {}
    var canPay: Bool { false }
    func offers() async throws(TipFailure) -> [TipOffer] { [] }
    func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase { throw .notAllowed }
}

/// What listens to the tips, and counts its starts.
final class CountingTips: TipsListening {
    private let starts = Mutex(0)
    var started: Int { starts.withLock { $0 } }

    func start() { starts.withLock { $0 += 1 } }
    var canPay: Bool { false }
    func offers() async throws(TipFailure) -> [TipOffer] { [] }
    func purchase(_ size: TipSize) async throws(TipFailure) -> TipPurchase { throw .notAllowed }
}

/// The listening to the store's tip transactions, at the launch.
@MainActor
@Suite("The tips at launch")
struct TipsAtLaunchTests {
    @Test("A launch that is ready starts the listener once and holds it")
    func startedOnceWhenReady() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let tips = CountingTips()

        let composition = try CompositionTests.ready(await Composition.make(CompositionTests.inputs(
            paths, compileRules: CompositionTests.counting(CompositionTests.CompileCounter()),
            makeTips: { _ in tips }
        )))

        #expect(tips.started == 1, "the composition starts its listener once, at the launch")
        #expect(composition.tips is CountingTips, "and holds it for as long as it lives")
    }

    @Test("A launch that fails still starts the listener, and holds it")
    func startedWhenFailed() async {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let settlement = TraceSettlement()
        weak var weakTips: CountingTips?

        do {
            let tips = CountingTips()
            weakTips = tips
            let state = await Composition.make(CompositionTests.inputs(
                paths, settlement: settlement, compileRules: CompositionTests.counting(CompositionTests.CompileCounter()),
                designs: FixedBundledSource(packages: nil), makeTips: { _ in tips }
            ))
            guard case .failed = state else {
                Issue.record("expected failed, got \(state)")
                return
            }
            #expect(tips.started == 1, "the store's transactions are finished even when the launch fails")
        }
        #expect(weakTips != nil, "the failed launch leaves no composition, so the settlement of the launches holds the listener")
        withExtendedLifetime(settlement) {}
    }

    @Test("A launch that fails before its paths are checked still starts the listener")
    func startedWhenTheCheckFails() async {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let tips = CountingTips()

        let state = await Composition.make(CompositionTests.inputs(
            paths, compileRules: CompositionTests.counting(CompositionTests.CompileCounter()),
            check: { () throws(CompositionFailure) in throw .storeUnavailable }, makeTips: { _ in tips }
        ))

        guard case .failed = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(tips.started == 1)
    }

    @Test("A retry after a failure reuses the listener the first launch started")
    func retryDoesNotMakeASecond() async throws {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let settlement = TraceSettlement()
        let tips = CountingTips()
        let made = Mutex(0)
        let makeTips: Composition.MakeTips = { _ in
            made.withLock { $0 += 1 }
            return tips
        }

        _ = await Composition.make(CompositionTests.inputs(
            paths, settlement: settlement, compileRules: CompositionTests.counting(CompositionTests.CompileCounter()),
            designs: FixedBundledSource(packages: nil), makeTips: makeTips
        ))
        let composition = try CompositionTests.ready(await Composition.make(CompositionTests.inputs(
            paths, settlement: settlement, compileRules: CompositionTests.counting(CompositionTests.CompileCounter()),
            makeTips: makeTips
        )))

        #expect(made.withLock { $0 } == 1, "one listener for the process, not one per launch")
        #expect(tips.started == 1)
        #expect(composition.tips is CountingTips)
    }
}
