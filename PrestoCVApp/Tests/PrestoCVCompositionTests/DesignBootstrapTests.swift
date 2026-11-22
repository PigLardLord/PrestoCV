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
        #expect(installed.installed.map(\.manifest.id) == Self.bundled)
        #expect(installed.defaultDesign.id == "professional")
        #expect(await second.verified.isEmpty)
        #expect(again.installed.map(\.manifest.id) == Self.bundled)
    }

    @Test("The installed designs keep the preview each package brings, for the look picker")
    func installedDesignsKeepTheirPreviews() async throws {
        let store = InMemoryDesignStore()

        let designs = try await Self.bootstrap(store: store, gate: FakeRenderingGate()).run()

        let previews = designs.installed.compactMap(\.previewPNG)
        #expect(previews.count == Self.bundled.count, "every bundled design has a preview")
        #expect(Set(previews).count == previews.count, "no two designs share one")
        for id in Self.bundled {
            let stored = try await GetDesign(store: store)(id: id)
            #expect(designs.installed.first { $0.manifest.id == id }?.previewPNG == stored.previewPNG)
        }
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

        #expect(designs.installed.map(\.manifest.id) == Self.bundled)
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
        #expect(designs.installed.map(\.manifest.id) == Self.bundled)
    }

    @Test("A launch cancelled while the store waits for its lock is designSyncInterrupted, whether the wait then lists or times out", arguments: [false, true])
    func cancelledDuringTheStoreWait(timesOut: Bool) async throws {
        let store = HeldStore(timesOut: timesOut)
        _ = try await Self.bootstrap(store: store, gate: FakeRenderingGate()).run()
        await store.arm()

        let launch = Task { await Self.failure(of: Self.bootstrap(store: store, gate: FakeRenderingGate())) }
        try #require(await store.waitUntilEntered())
        launch.cancel()
        await store.release()

        #expect(await launch.value == .designSyncInterrupted)
    }

    @Test("A design the store cannot read is left out at launch, and the launch goes on with the others")
    func unreadableDesign() async throws {
        let logger = RecordingLogger()

        let designs = try await Self.bootstrap(store: SpyDesignStore(unreadable: ["modern"]), gate: FakeRenderingGate(), logger: logger).run()

        #expect(designs.installed.map(\.manifest.id) == ["minimal", "professional"])
        let unreadable = try #require(logger.entry("designs.unreadable"))
        #expect(unreadable.level == .notice)
        #expect(unreadable.category == .designs)
        #expect(unreadable.value("leftOut") == .count(1))
    }

    @Test("A bundled design whose package is damaged in the store is written again at the next launch and offered, default or not",
          arguments: [["professional"], ["modern"], ["minimal", "modern", "professional"]])
    func damagedBundledDesignIsRepaired(damaged: Set<String>) async throws {
        let shipped = try await BundleDesignSource().bundledPackages().map { try DesignPackageValidator().validate($0.data) }
        let store = SpyDesignStore(installed: shipped, origins: Dictionary(uniqueKeysWithValues: Self.bundled.map { ($0, .bundled) }), unreadable: damaged)
        let gate = FakeRenderingGate()
        let logger = RecordingLogger()

        let designs = try await Self.bootstrap(store: store, gate: gate, logger: logger).run()

        #expect(designs.installed.map(\.manifest.id) == Self.bundled)
        #expect(designs.defaultDesign.id == "professional")
        #expect(await gate.verified == Self.bundled.filter(damaged.contains))
        let synced = try #require(logger.entry("designs.synced"))
        #expect(synced.level == .info)
        #expect(synced.value("repaired") == .count(damaged.count))
        #expect(synced.value("unchanged") == .count(Self.bundled.count - damaged.count))
        #expect(logger.entry("designs.unreadable") == nil)
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

        #expect(designs.installed.map(\.manifest.id) == ["minimal", "professional"])
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

        #expect(designs.installed.map(\.manifest.id) == Self.bundled)
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
        let counts = ["installed", "upgraded", "unchanged", "adopted", "repaired", "rejected", "notRendered", "failed", "conflicts"].map { synced.value($0) }
        #expect(counts == [.count(3), .count(0), .count(0), .count(0), .count(0), .count(0), .count(0), .count(0), .count(0)])
        #expect(synced.value("elapsed") == .duration(Self.step))
        #expect(logger.events == ["designs.synced"])
    }
}

/// An in-memory store that, once armed, holds its next listing the way the file store's lock wait does: the wait sleeps in
/// a task of its own, so it ignores the caller's cancellation, and then lists or times out.
private actor HeldStore: DesignStore {
    struct LockTimeout: Error {}
    private let store = InMemoryDesignStore()
    private let timesOut: Bool
    private var armed = false
    private let entered: AsyncStream<Void>, enteredSignal: AsyncStream<Void>.Continuation
    private let released: AsyncStream<Void>, releaseSignal: AsyncStream<Void>.Continuation

    init(timesOut: Bool) {
        self.timesOut = timesOut
        (entered, enteredSignal) = AsyncStream.makeStream(of: Void.self)
        (released, releaseSignal) = AsyncStream.makeStream(of: Void.self)
    }

    /// Holds the next listing until `release()`.
    func arm() { armed = true }

    /// Lets the held listing go on.
    func release() { releaseSignal.yield() }

    /// Waits until a listing is held: true, or false after `timeout`.
    func waitUntilEntered(timeout: Duration = .seconds(10)) async -> Bool {
        let stream = entered
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { for await _ in stream { return true }; return false }
            group.addTask {
                do { try await Task.sleep(for: timeout) } catch { return false }
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    func installedDesigns() async throws -> [DesignManifest] {
        if armed {
            armed = false
            enteredSignal.yield()
            let released = released
            await Task { for await _ in released { return } }.value
            if timesOut { throw LockTimeout() }
        }
        return try await store.installedDesigns()
    }

    @discardableResult func save(_ design: ValidatedDesign) async throws -> ImportSave { try await store.save(design) }
    func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave { try await store.saveIfNewer(design) }
    func design(id: String) async throws -> ValidatedDesign? { try await store.design(id: id) }
    func installedOrigins() async throws -> [String: DesignOrigin] { try await store.installedOrigins() }
    func adoptAsBundled(_ design: ValidatedDesign) async throws -> Bool { try await store.adoptAsBundled(design) }
}
