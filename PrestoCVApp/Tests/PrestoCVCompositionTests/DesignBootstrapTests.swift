import CVBundledDesigns
import CVDesignCatalog
import CVRenderingTestSupport
import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
import Testing
@testable import PrestoCVComposition

/// The sync of the bundled designs at launch, over an in-memory store and a fake gate: the real bundled packages, no
/// rendering, and a clock that moves one step per read.
@Suite("The design bootstrap")
struct DesignBootstrapTests {
    private static let bundled = ["minimal", "modern", "professional"]
    private static let step = Duration.milliseconds(5)

    private static func bootstrap(
        store: any DesignStore, source: any BundledDesignSource = BundleDesignSource(), gate: any DesignRenderingGate,
        logger: any DiagnosticLogger = RecordingLogger()
    ) -> DesignBootstrap {
        DesignBootstrap(store: store, source: source, gate: gate, logger: logger, clock: TickingClock(step: step))
    }

    /// Runs the bootstrap and gives its failure, or nil when it went on.
    private static func failure(of bootstrap: DesignBootstrap) async -> CompositionFailure? {
        do throws(CompositionFailure) {
            _ = try await bootstrap.run()
            return nil
        } catch {
            return error
        }
    }

    @Test("The first launch renders and installs the three bundled designs, and the second renders none")
    func firstAndSecondLaunch() async throws {
        let store = InMemoryDesignStore()
        let first = FakeRenderingGate()
        let second = FakeRenderingGate()

        let installed = try await Self.bootstrap(store: store, gate: first).run()
        let again = try await Self.bootstrap(store: store, gate: second).run()

        #expect(await first.verified == Self.bundled)
        #expect(installed.installed.map(\.id) == Self.bundled)
        #expect(installed.defaultDesign.id == "professional")
        #expect(await second.verified.isEmpty)
        #expect(again.installed.map(\.id) == Self.bundled)
    }

    @Test("A bundle that cannot be read, with no default design installed, fails with bundledDesignsUnavailable")
    func unreadableBundle() async {
        let store = InMemoryDesignStore()

        let failure = await Self.failure(of: Self.bootstrap(store: store, source: FixedBundledSource(packages: nil), gate: FakeRenderingGate()))

        #expect(failure == .bundledDesignsUnavailable)
    }

    @Test("A bundle that cannot be read is tolerated while the store gives the default design")
    func unreadableBundleOverInstalledDesigns() async throws {
        let store = InMemoryDesignStore()
        _ = try await Self.bootstrap(store: store, gate: FakeRenderingGate()).run()
        let logger = RecordingLogger()

        let designs = try await Self.bootstrap(store: store, source: FixedBundledSource(packages: nil), gate: FakeRenderingGate(), logger: logger).run()

        #expect(designs.installed.map(\.id) == Self.bundled)
        let failed = try #require(logger.entry("designs.syncFailed"))
        #expect(failed.level == .notice)
        #expect(failed.value("reason") == .token("bundledDesignsUnavailable"))
        #expect(logger.entry("designs.unavailable") == nil)
    }

    @Test("A store that cannot list its designs fails with designStoreUnavailable, and nothing is rendered")
    func unavailableStore() async {
        let gate = FakeRenderingGate()
        let logger = RecordingLogger()

        let failure = await Self.failure(of: Self.bootstrap(store: UnavailableStore(), gate: gate, logger: logger))

        #expect(failure == .designStoreUnavailable)
        #expect(await gate.verified.isEmpty)
        #expect(logger.entry("designs.syncFailed")?.value("reason") == .token("designStoreUnavailable"))
        let unavailable = logger.entry("designs.unavailable")
        #expect(unavailable?.level == .error)
        #expect(unavailable?.value("failure") == .token("designStoreUnavailable"))
    }

    @Test("A store that cannot save fails with designStoreUnavailable, and installs nothing")
    func unwritableStore() async {
        let store = SpyDesignStore(savesFailFor: Set(Self.bundled))
        let logger = RecordingLogger()

        let failure = await Self.failure(of: Self.bootstrap(store: store, gate: FakeRenderingGate(), logger: logger))

        #expect(failure == .designStoreUnavailable)
        #expect(await store.savedIDs.isEmpty)
        let synced = logger.entry("designs.synced")
        #expect(synced?.level == .notice)
        #expect(synced?.value("failed") == .count(3))
    }

    @Test("A store that cannot read the default design fails with designStoreUnavailable")
    func unreadableDefaultDesign() async {
        let store = SpyDesignStore(unreadable: ["professional"])

        let failure = await Self.failure(of: Self.bootstrap(store: store, gate: FakeRenderingGate()))

        #expect(failure == .designStoreUnavailable)
    }

    @Test("A cancelled sync is designSyncInterrupted; the designs saved before it stay saved, and the next launch renders only the others")
    func interruptedSync() async throws {
        let store = InMemoryDesignStore()
        let interrupted = FakeRenderingGate(cancellingOn: ["modern"])
        let next = FakeRenderingGate()
        let logger = RecordingLogger()

        let failure = await Self.failure(of: Self.bootstrap(store: store, gate: interrupted, logger: logger))
        let designs = try await Self.bootstrap(store: store, gate: next).run()

        #expect(failure == .designSyncInterrupted)
        #expect(await interrupted.verified == ["minimal", "modern"])
        #expect(logger.entry("designs.interrupted")?.level == .info)
        #expect(logger.entry("designs.unavailable") == nil)
        #expect(await next.verified == ["modern", "professional"])
        #expect(designs.installed.map(\.id) == Self.bundled)
    }

    @Test("A cancelled source is designSyncInterrupted")
    func cancelledSource() async {
        let failure = await Self.failure(of: Self.bootstrap(store: InMemoryDesignStore(), source: CancelledBundledSource(), gate: FakeRenderingGate()))

        #expect(failure == .designSyncInterrupted)
    }

    @Test("A design the gate refuses is left out, and the launch goes on with the others")
    func refusedDesign() async throws {
        let logger = RecordingLogger()

        let designs = try await Self.bootstrap(
            store: InMemoryDesignStore(), gate: FakeRenderingGate(refusing: ["modern"]), logger: logger
        ).run()

        #expect(designs.installed.map(\.id) == ["minimal", "professional"])
        let synced = logger.entry("designs.synced")
        #expect(synced?.level == .notice)
        #expect(synced?.value("notRendered") == .count(1))
        #expect(synced?.value("installed") == .count(2))
    }

    @Test("A package the validator rejects is left out, and the launch goes on with the others")
    func rejectedPackage() async throws {
        let packages = try await BundleDesignSource().bundledPackages() + [(name: "broken", data: Data("not a package".utf8))]
        let logger = RecordingLogger()

        let designs = try await Self.bootstrap(
            store: InMemoryDesignStore(), source: FixedBundledSource(packages: packages), gate: FakeRenderingGate(), logger: logger
        ).run()

        #expect(designs.installed.map(\.id) == Self.bundled)
        #expect(logger.entry("designs.synced")?.value("rejected") == .count(1))
    }

    @Test("A default design the gate refuses, with none installed, fails with bundledDesignsUnavailable")
    func refusedDefaultDesign() async {
        let failure = await Self.failure(of: Self.bootstrap(store: InMemoryDesignStore(), gate: FakeRenderingGate(refusing: ["professional"])))

        #expect(failure == .bundledDesignsUnavailable)
    }

    @Test("A sync with nothing left out is logged at info with its counts and the time it took")
    func syncedLine() async throws {
        let logger = RecordingLogger()

        _ = try await Self.bootstrap(store: InMemoryDesignStore(), gate: FakeRenderingGate(), logger: logger).run()

        let synced = try #require(logger.entry("designs.synced"))
        #expect(synced.level == .info)
        #expect(synced.category == .designs)
        let counts = ["installed", "upgraded", "unchanged", "adopted", "rejected", "notRendered", "failed", "conflicts"].map { synced.value($0) }
        #expect(counts == [.count(3), .count(0), .count(0), .count(0), .count(0), .count(0), .count(0), .count(0)])
        #expect(synced.value("elapsed") == .duration(Self.step))
        #expect(logger.events == ["designs.synced"])
    }
}
