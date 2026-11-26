import CVRenderingTestSupport
import Foundation
import Synchronization
import Testing
@testable import PrestoCVComposition

/// What listens to the tips, for the launches that do not look at the store.
struct NoTips: TipsListening {
    func start() {}
}

/// What listens to the tips, and counts its starts.
final class CountingTips: TipsListening {
    private let starts = Mutex(0)
    var started: Int { starts.withLock { $0 } }

    func start() { starts.withLock { $0 += 1 } }
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

    @Test("A launch that fails starts no listener")
    func notStartedWhenFailed() async {
        let paths = CompositionTests.paths()
        defer { try? FileManager.default.removeItem(at: paths.temporary) }
        let tips = CountingTips()

        let state = await Composition.make(CompositionTests.inputs(
            paths, compileRules: CompositionTests.counting(CompositionTests.CompileCounter()),
            designs: FixedBundledSource(packages: nil), makeTips: { _ in tips }
        ))

        guard case .failed = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(tips.started == 0)
    }
}
