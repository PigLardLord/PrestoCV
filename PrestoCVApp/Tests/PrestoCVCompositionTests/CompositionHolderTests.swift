#if DEBUG
import Foundation
import Observation
import Testing
@testable import PrestoCVComposition

/// The holder over a launch the test scripts: each launch waits until the test lets it end, so the test decides when a
/// launch is running and what it returns.
@MainActor
@Suite("The composition holder")
struct CompositionHolderTests {
    /// A signal the test waits for: it remembers a fire that came before the wait
    @MainActor
    final class Signal {
        private var pending = 0
        private var waiter: CheckedContinuation<Void, Never>?

        func fire() {
            if let waiter {
                self.waiter = nil
                waiter.resume()
            } else {
                pending += 1
            }
        }

        func wait() async {
            if pending > 0 {
                pending -= 1
                return
            }
            await withCheckedContinuation { waiter = $0 }
        }
    }

    /// A launch that returns the scripted states in order, each after the test released it
    @MainActor
    final class ScriptedLaunch {
        private(set) var launches = 0
        private(set) var settlements: [TraceSettlement] = []
        private var results: [CompositionState]
        private let began = Signal()
        private let released = Signal()

        init(_ results: [CompositionState]) {
            self.results = results
        }

        func launch(_ settlement: TraceSettlement) async -> CompositionState {
            launches += 1
            settlements.append(settlement)
            began.fire()
            await released.wait()
            return results.removeFirst()
        }

        /// Returns once a launch has begun that no earlier call waited for
        func nextLaunchBegan() async { await began.wait() }

        /// Lets the running launch end
        func release() { released.fire() }
    }

    private func holder(_ script: ScriptedLaunch) -> CompositionHolder {
        CompositionHolder(launch: { await script.launch($0) })
    }

    /// Returns once the holder is no longer launching
    private func settled(_ holder: CompositionHolder) async {
        for await launching in Observations({ if case .launching = holder.phase { true } else { false } }) where !launching {
            return
        }
    }

    private func readyState() async throws -> CompositionState {
        let state = await Composition.launch(arguments: ["holder-test", "-PrestoCVNextEmptyStorage"], settlement: TraceSettlement())
        guard case .ready = state else { throw NotReady(state: "\(state)") }
        return state
    }

    struct NotReady: Error { let state: String }

    @Test("A holder is launching until its first launch ends, then shows the failure with its code")
    func firstLaunchFails() async {
        let script = ScriptedLaunch([.failed(.storeUnavailable)])
        let holder = holder(script)
        guard case .launching = holder.phase else { Issue.record("expected launching"); return }

        holder.start()
        await script.nextLaunchBegan()
        guard case .launching = holder.phase else { Issue.record("expected launching while it runs"); return }
        script.release()
        await settled(holder)

        guard case .failed(.storeUnavailable) = holder.phase else { Issue.record("expected failed"); return }
        #expect(script.launches == 1)
    }

    @Test("Starting twice makes one launch")
    func startIsOnce() async {
        let script = ScriptedLaunch([.failed(.storeUnavailable)])
        let holder = holder(script)

        holder.start()
        holder.start()
        await script.nextLaunchBegan()
        script.release()
        await settled(holder)
        holder.start()

        #expect(script.launches == 1)
    }

    @Test("A retry after a failure launches again and gives the new state")
    func retryAfterFailure() async throws {
        let script = ScriptedLaunch([.failed(.contentRulesUnavailable), try await readyState()])
        let holder = holder(script)
        holder.start()
        await script.nextLaunchBegan()
        script.release()
        await settled(holder)

        holder.retry()
        guard case .launching = holder.phase else { Issue.record("expected launching after retry"); return }
        await script.nextLaunchBegan()
        script.release()
        await settled(holder)

        guard case .ready = holder.phase else { Issue.record("expected ready"); return }
        #expect(script.launches == 2)
    }

    @Test("Two retries during one launch make one launch")
    func doubleTapRetry() async {
        let script = ScriptedLaunch([.failed(.storeUnavailable), .failed(.storeUnavailable)])
        let holder = holder(script)
        holder.start()
        await script.nextLaunchBegan()
        script.release()
        await settled(holder)

        holder.retry()
        holder.retry()
        await script.nextLaunchBegan()
        holder.retry()
        script.release()
        await settled(holder)

        #expect(script.launches == 2)
        guard case .failed = holder.phase else { Issue.record("expected failed"); return }
    }

    @Test("Every launch of a holder gets the one settlement, so a retry's trace waits for the launch before it")
    func launchesShareTheSettlement() async {
        let script = ScriptedLaunch([.failed(.storeUnavailable), .failed(.storeUnavailable)])
        let holder = holder(script)
        holder.start()
        await script.nextLaunchBegan()
        script.release()
        await settled(holder)

        holder.retry()
        await script.nextLaunchBegan()
        script.release()
        await settled(holder)

        #expect(script.settlements.count == 2)
        #expect(script.settlements[0] === script.settlements[1])
    }

    @Test("A retry while the first launch runs, or after it is ready, launches nothing")
    func retryOnlyAfterFailure() async throws {
        let script = ScriptedLaunch([try await readyState()])
        let holder = holder(script)
        holder.start()
        await script.nextLaunchBegan()

        holder.retry()
        script.release()
        await settled(holder)
        holder.retry()

        guard case .ready = holder.phase else { Issue.record("expected ready"); return }
        #expect(script.launches == 1)
    }
}
#endif
