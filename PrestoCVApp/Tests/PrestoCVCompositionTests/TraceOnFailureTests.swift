import CVBundledDesigns
import CVRenderingTestSupport
import CVRenderingWebKitSupport
import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import PrestoCVCoreTestSupport
import Testing
import WebKit
@testable import PrestoCVComposition

/// A launch that may not record removes what an earlier install stored (ADR 0032), also when the composition fails: the
/// error screen must not leave a person's CV text on the device.
@MainActor
@Suite("The trace purge when the composition fails")
struct TraceOnFailureTests {
    private static let marker = "Zwiebelmarker"

    private static func base() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TraceOnFailureTests-\(UUID().uuidString)", isDirectory: true)
    }

    private static func inputs(
        _ paths: AppPaths,
        gate: TraceLaunchGate = .asking(FixedDistribution(.production)),
        settlement: TraceSettlement = TraceSettlement(),
        settleDeadline: @escaping @Sendable () async -> Void = TraceOnFailureTests.neverFires,
        check: @escaping @MainActor () throws(CompositionFailure) -> Void = TraceOnFailureTests.passes,
        compileRules: @escaping Composition.CompileRules
    ) -> Composition.Inputs {
        Composition.Inputs(
            paths: paths,
            clock: SteppingClock(),
            ids: SequentialIDGenerator(),
            log: RecordingLogger(),
            gate: gate,
            device: TraceDevice(appVersion: "1.0", build: "1", osVersion: "iOS 26.5", model: "iPhone17,1"),
            settlement: settlement,
            samples: paths.root.appendingPathComponent("Samples", isDirectory: true),
            copyFolders: [],
            compileRules: compileRules,
            designs: BundleDesignSource(),
            makeGate: { _, _, _ in FakeRenderingGate() },
            settleDeadline: settleDeadline,
            check: check,
            prepare: {},
            wrapListEditing: { $0 },
            wrapStore: { $0 },
            wrapImport: { $0 },
            backgroundTime: NoBackgroundTime(),
            appLanguage: .preferred(["en"]),
            sharesWithStandIn: false,
            legacyStore: EmptyLegacyStore()
        )
    }

    /// A check that every path passes.
    private static let passes: @MainActor () throws(CompositionFailure) -> Void = {}

    /// A deadline that never fires: nothing waits for it to end.
    private static let neverFires: @Sendable () async -> Void = {
        for await _ in AsyncStream<Void> { _ in } {}
    }

    private static let failingRules: Composition.CompileRules = {
        @MainActor () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList in throw .contentRulesUnavailable
    }

    /// Stores one run, as an earlier TestFlight install did.
    private static func storeARun(in paths: AppPaths) async {
        let earlier = TraceChain(
            directory: paths.trace, shareDirectory: paths.traceShare, gate: .asking(FixedDistribution(.sandbox)),
            device: TraceDevice(appVersion: "1.0", build: "1", osVersion: "iOS 26.5", model: "iPhone17,1"),
            log: RecordingLogger(), after: nil
        )
        #expect(await earlier.access.isOn())
        let run = earlier.tracer.begin(.textImport)
        run.record(.input, .text("text", marker))
        run.finish(.finished)
        #expect(await earlier.access.reader.runs().count == 1)
    }

    @Test("Rules that cannot be compiled still purge the traces of an earlier install before make returns")
    func purgesWhenTheRulesFail() async {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
        await Self.storeARun(in: paths)
        #expect(FileManager.default.fileExists(atPath: paths.trace.path))

        let state = await Composition.make(Self.inputs(paths, compileRules: Self.failingRules))

        guard case .failed(.contentRulesUnavailable) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: paths.trace.path), "The traces are purged when make returns")
    }

    @Test("A store folder that cannot be made still purges the traces of an earlier install before make returns")
    func purgesWhenTheStoreFails() async throws {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
        await Self.storeARun(in: paths)
        #expect(FileManager.default.fileExists(atPath: paths.trace.path))
        // A regular file where the store folder belongs, so that making the store fails while the trace folder stays
        try Data("x".utf8).write(to: paths.store)

        let state = await Composition.make(Self.inputs(paths, compileRules: Self.failingRules))

        guard case .failed(.storeUnavailable) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: paths.trace.path), "The traces are purged when make returns")
    }

    @Test("Paths that fail their check purge nothing: the trace chain never starts on them")
    func failedCheckPurgesNothing() async {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
        await Self.storeARun(in: paths)
        #expect(FileManager.default.fileExists(atPath: paths.trace.path))

        let state = await Composition.make(Self.inputs(
            paths, check: { () throws(CompositionFailure) in throw .launchFixturesRejected }, compileRules: Self.failingRules
        ))

        guard case .failed(.launchFixturesRejected) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: paths.trace.path), "No trace is purged through paths that failed their check")
    }

    @Test("A distribution that never answers does not hold back the error state, and the purge waits for the answer",
          .timeLimit(.minutes(1)))
    func failedStateDoesNotWaitForTheAnswer() async {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
        await Self.storeARun(in: paths)
        let distribution = HeldDistribution()

        let state = await Composition.make(Self.inputs(
            paths, gate: .asking(distribution), settleDeadline: {}, compileRules: Self.failingRules
        ))

        guard case .failed(.contentRulesUnavailable) = state else {
            Issue.record("expected failed, got \(state)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: paths.trace.path), "No purge without an answer")
        await distribution.answer(with: .production)
    }

    @Test("A retry records nothing until the failed launch's trace has settled, and its runs then survive that launch's purge",
          .timeLimit(.minutes(1)))
    func retryWaitsForTheFailedLaunchTrace() async throws {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
        await Self.storeARun(in: paths)
        let settlement = TraceSettlement()
        let late = HeldDistribution()
        let failed = await Composition.make(Self.inputs(
            paths, gate: .asking(late), settlement: settlement, settleDeadline: {}, compileRules: Self.failingRules
        ))
        guard case .failed(.contentRulesUnavailable) = failed else {
            Issue.record("expected failed, got \(failed)")
            return
        }

        // The retry: the distribution answers open at once, but the first launch has not answered yet
        let retried = await Composition.make(Self.inputs(
            paths, gate: .asking(FixedDistribution(.sandbox)), settlement: settlement,
            compileRules: { @MainActor () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList in
                try await SecureWebViewConfiguration.compileRules()
            }
        ))
        guard case .ready(let composition) = retried else {
            Issue.record("expected ready, got \(retried)")
            return
        }
        let early = composition.tracer.begin(.textImport)
        early.record(.input, .text("text", Self.marker))
        early.finish(.finished)
        #expect(
            await composition.traceAccess.reader.runs().count == 1,
            "Only the run of the earlier install: the retry records nothing before the first launch has settled"
        )

        // The first launch now learns that it may not record, and purges what the earlier install stored
        await late.answer(with: .production)
        #expect(await composition.traceAccess.isOn())
        let after = composition.tracer.begin(.textImport)
        after.record(.input, .text("text", "after"))
        after.finish(.finished)
        await settlement.settled()

        let runs = await composition.traceAccess.reader.runs()
        #expect(runs.count == 1, "The retry's run stays, the purge of the first launch did not take it")
    }
}
