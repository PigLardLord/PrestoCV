import CVBundledDesigns
import CVDesignCatalog
import CVRenderingTestSupport
import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
import PrestoCVIntegration
import Synchronization
import Testing
@testable import PrestoCVComposition

/// The check of the bundled designs once the app is open (#566), over an in-memory store and a fake gate: the real bundled
/// packages, no rendering, and a clock that moves one step per read.
@Suite("The design bootstrap")
struct DesignBootstrapTests {
    private static let bundled = ["minimal", "modern", "professional"]
    /// The designs as the app offers them: the default design first, then the others by identifier
    private static let offered = ["professional", "minimal", "modern"]
    private static let step = Duration.milliseconds(5)

    private static func bootstrap(
        store: any DesignStore, source: any BundledDesignSource = BundleDesignSource(), gate: any DesignRenderingGate,
        logger: any DiagnosticLogger = RecordingLogger()
    ) -> DesignBootstrap {
        DesignBootstrap(store: store, source: source, gate: gate, logger: logger, clock: TickingClock(step: step))
    }

    /// Runs the check as the app does, and gives the designs once it is over.
    private static func outcome(of bootstrap: DesignBootstrap) async -> CheckedDesignsSnapshot {
        await bootstrap.checked().current
    }

    /// Runs the check alone, and gives what it told: each identifier, and whether a design came with it.
    private static func told(by bootstrap: DesignBootstrap) async -> [Told] {
        let record = Record()
        await bootstrap.check { id, design in record.told.withLock { $0.append(Told(id: id, held: design != nil)) } }
        return record.told.withLock { $0 }
    }

    private struct Told: Equatable, Sendable {
        let id: String
        let held: Bool
    }

    private final class Record: Sendable {
        let told = Mutex<[Told]>([])
    }

    @Test("The first check renders and installs the three bundled designs, and the next launch offers them at once and renders none")
    func firstAndSecondLaunch() async {
        let store = InMemoryDesignStore()
        let first = FakeRenderingGate()
        let second = FakeRenderingGate()

        let installed = await Self.outcome(of: Self.bootstrap(store: store, gate: first))
        let before = await Self.bootstrap(store: store, gate: second).installed()
        let again = await Self.outcome(of: Self.bootstrap(store: store, gate: second))

        #expect(await first.verified == Self.offered)
        #expect(installed.designs.map(\.manifest.id) == Self.offered)
        #expect(installed.status == .ready)
        #expect(before.map(\.manifest.id) == Self.bundled)
        #expect(await second.verified.isEmpty)
        #expect(again.designs.map(\.manifest.id) == Self.offered)
    }

    @Test("The check tells each bundled design once the store holds it, the default design first")
    func toldInOrder() async {
        let told = await Self.told(by: Self.bootstrap(store: InMemoryDesignStore(), gate: FakeRenderingGate()))

        #expect(told == Self.offered.map { Told(id: $0, held: true) })
    }

    @Test("The installed designs keep the preview each package brings, for the look picker")
    func installedDesignsKeepTheirPreviews() async throws {
        let store = InMemoryDesignStore()

        let designs = await Self.outcome(of: Self.bootstrap(store: store, gate: FakeRenderingGate()))

        let previews = designs.designs.compactMap(\.previewPNG)
        #expect(previews.count == Self.bundled.count, "every bundled design has a preview")
        #expect(Set(previews).count == previews.count, "no two designs share one")
        for id in Self.bundled {
            let stored = try await GetDesign(store: store)(id: id)
            #expect(designs.designs.first { $0.manifest.id == id }?.previewPNG == stored.previewPNG)
        }
    }

    @Test("A bundle that cannot be read, with no default design installed, leaves the designs unavailable")
    func unreadableBundle() async {
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(
            store: InMemoryDesignStore(), source: FixedBundledSource(packages: nil), gate: FakeRenderingGate(), logger: logger
        ))

        #expect(designs.status == .unavailable)
        #expect(designs.designs.isEmpty)
        #expect(logger.entry("designs.unavailable")?.value("failure") == .token("bundledDesignsUnavailable"))
    }

    @Test("A bundle that cannot be read is tolerated while the store gives the default design")
    func unreadableBundleOverInstalledDesigns() async throws {
        let store = InMemoryDesignStore()
        await Self.bootstrap(store: store, gate: FakeRenderingGate()).check { _, _ in }
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(
            store: store, source: FixedBundledSource(packages: nil), gate: FakeRenderingGate(), logger: logger
        ))

        #expect(designs.status == .ready)
        #expect(designs.designs.map(\.manifest.id) == Self.offered)
        let failed = try #require(logger.entry("designs.syncFailed"))
        #expect(failed.level == .notice)
        #expect(failed.value("reason") == .token("bundledDesignsUnavailable"))
        #expect(logger.entry("designs.unavailable") == nil)
    }

    @Test("A store that cannot list its designs leaves the designs unavailable, and nothing is rendered")
    func unavailableStore() async {
        let gate = FakeRenderingGate()
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(store: UnavailableStore(), gate: gate, logger: logger))

        #expect(designs.status == .unavailable)
        #expect(designs.designs.isEmpty)
        #expect(await gate.verified.isEmpty)
        #expect(logger.entry("designs.syncFailed")?.value("reason") == .token("designStoreUnavailable"))
        let unavailable = logger.entry("designs.unavailable")
        #expect(unavailable?.level == .error)
        #expect(unavailable?.value("failure") == .token("designStoreUnavailable"))
    }

    @Test("A store that cannot save leaves the designs unavailable, and installs nothing")
    func unwritableStore() async {
        let store = SpyDesignStore(savesFailFor: Set(Self.bundled))
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(store: store, gate: FakeRenderingGate(), logger: logger))

        #expect(designs.status == .unavailable)
        #expect(await store.savedIDs.isEmpty)
        let synced = logger.entry("designs.synced")
        #expect(synced?.level == .notice)
        #expect(synced?.value("failed") == .count(3))
        #expect(logger.entry("designs.unavailable")?.value("failure") == .token("designStoreUnavailable"))
    }

    @Test("A store that cannot read the default design leaves the designs unavailable, and offers the others")
    func unreadableDefaultDesign() async {
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(
            store: SpyDesignStore(unreadable: ["professional"]), gate: FakeRenderingGate(), logger: logger
        ))

        #expect(designs.status == .unavailable)
        #expect(designs.designs.map(\.manifest.id) == ["minimal", "modern"])
        #expect(logger.entry("designs.unavailable")?.value("failure") == .token("designStoreUnavailable"))
    }

    @Test("A cancelled check keeps the designs saved before it: the next launch offers them at once and renders only the others")
    func interruptedSync() async {
        let store = InMemoryDesignStore()
        let interrupted = FakeRenderingGate(cancellingOn: ["modern"])
        let next = FakeRenderingGate()
        let logger = RecordingLogger()

        await Self.bootstrap(store: store, gate: interrupted, logger: logger).check { _, _ in }
        let before = await Self.bootstrap(store: store, gate: next).installed()
        let designs = await Self.outcome(of: Self.bootstrap(store: store, gate: next))

        #expect(await interrupted.verified == Self.offered)
        #expect(logger.entry("designs.interrupted")?.level == .info)
        #expect(logger.entry("designs.unavailable") == nil)
        #expect(before.map(\.manifest.id) == ["minimal", "professional"])
        #expect(await next.verified == ["modern"])
        #expect(designs.designs.map(\.manifest.id) == Self.offered)
    }

    @Test("A check cancelled while the store waits for its lock is interrupted, whether the wait then lists or times out", arguments: [false, true])
    func cancelledDuringTheStoreWait(timesOut: Bool) async throws {
        let store = HeldStore(timesOut: timesOut)
        await Self.bootstrap(store: store, gate: FakeRenderingGate()).check { _, _ in }
        await store.arm()
        let logger = RecordingLogger()

        let check = Task { await Self.bootstrap(store: store, gate: FakeRenderingGate(), logger: logger).check { _, _ in } }
        try #require(await store.waitUntilEntered())
        check.cancel()
        await store.release()
        await check.value

        #expect(logger.entry("designs.interrupted")?.level == .info)
        #expect(logger.entry("designs.unavailable") == nil)
    }

    @Test("A design the store cannot read is left out, and the others are offered")
    func unreadableDesign() async throws {
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(
            store: SpyDesignStore(unreadable: ["modern"]), gate: FakeRenderingGate(), logger: logger
        ))

        #expect(designs.status == .ready)
        #expect(designs.designs.map(\.manifest.id) == ["professional", "minimal"])
        let unreadable = try #require(logger.entry("designs.unreadable"))
        #expect(unreadable.level == .notice)
        #expect(unreadable.category == .designs)
        #expect(unreadable.value("leftOut") == .count(1))
    }

    @Test("An installed design the store cannot read is left out of the designs offered at once")
    func unreadableInstalledDesign() async throws {
        let shipped = try await BundleDesignSource().bundledPackages().map { try DesignPackageValidator().validate($0.data) }
        let logger = RecordingLogger()
        let bootstrap = Self.bootstrap(store: SpyDesignStore(installed: shipped, unreadable: ["modern"]), gate: FakeRenderingGate(), logger: logger)

        let designs = await bootstrap.installed()

        #expect(designs.map(\.manifest.id) == ["minimal", "professional"])
        #expect(logger.entry("designs.unreadable")?.value("leftOut") == .count(1))
    }

    @Test("A bundled design whose package is damaged in the store is written again by the check and offered, default or not",
          arguments: [["professional"], ["modern"], ["minimal", "modern", "professional"]])
    func damagedBundledDesignIsRepaired(damaged: Set<String>) async throws {
        let shipped = try await BundleDesignSource().bundledPackages().map { try DesignPackageValidator().validate($0.data) }
        let store = SpyDesignStore(installed: shipped, origins: Dictionary(uniqueKeysWithValues: Self.bundled.map { ($0, .bundled) }), unreadable: damaged)
        let gate = FakeRenderingGate()
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(store: store, gate: gate, logger: logger))

        #expect(designs.status == .ready)
        #expect(designs.designs.map(\.manifest.id) == Self.offered)
        #expect(await gate.verified == Self.offered.filter(damaged.contains))
        let synced = try #require(logger.entry("designs.synced"))
        #expect(synced.level == .info)
        #expect(synced.value("repaired") == .count(damaged.count))
        #expect(synced.value("unchanged") == .count(Self.bundled.count - damaged.count))
        #expect(logger.entry("designs.unreadable")?.value("leftOut") == .count(damaged.count), "before the check repairs them")
    }

    @Test("A cancelled source is interrupted, and tells no design")
    func cancelledSource() async {
        let logger = RecordingLogger()

        let told = await Self.told(by: Self.bootstrap(
            store: InMemoryDesignStore(), source: CancelledBundledSource(), gate: FakeRenderingGate(), logger: logger
        ))

        #expect(told.isEmpty)
        #expect(logger.entry("designs.interrupted") != nil)
        #expect(logger.entry("designs.unavailable") == nil)
    }

    @Test("A design the gate refuses is told without a design and never offered; the others are")
    func refusedDesign() async {
        let logger = RecordingLogger()
        let bootstrap = Self.bootstrap(store: InMemoryDesignStore(), gate: FakeRenderingGate(refusing: ["modern"]), logger: logger)

        let told = await Self.told(by: bootstrap)

        #expect(told == [Told(id: "professional", held: true), Told(id: "minimal", held: true), Told(id: "modern", held: false)])
        let synced = logger.entry("designs.synced")
        #expect(synced?.level == .notice)
        #expect(synced?.value("notRendered") == .count(1))
        #expect(synced?.value("installed") == .count(2))
        let designs = await Self.outcome(of: Self.bootstrap(store: InMemoryDesignStore(), gate: FakeRenderingGate(refusing: ["modern"])))
        #expect(designs.designs.map(\.manifest.id) == ["professional", "minimal"])
    }

    @Test("A package the validator rejects is left out, and the others are offered")
    func rejectedPackage() async throws {
        let packages = try await BundleDesignSource().bundledPackages() + [(name: "broken", data: Data("not a package".utf8))]
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(
            store: InMemoryDesignStore(), source: FixedBundledSource(packages: packages), gate: FakeRenderingGate(), logger: logger
        ))

        #expect(designs.designs.map(\.manifest.id) == Self.offered)
        #expect(logger.entry("designs.synced")?.value("rejected") == .count(1))
    }

    @Test("A default design the gate refuses, with none installed, leaves the designs unavailable and offers the others")
    func refusedDefaultDesign() async {
        let logger = RecordingLogger()

        let designs = await Self.outcome(of: Self.bootstrap(
            store: InMemoryDesignStore(), gate: FakeRenderingGate(refusing: ["professional"]), logger: logger
        ))

        #expect(designs.status == .unavailable)
        #expect(designs.designs.map(\.manifest.id) == ["minimal", "modern"])
        #expect(logger.entry("designs.unavailable")?.value("failure") == .token("bundledDesignsUnavailable"))
    }

    @Test("A check with nothing left out is logged at info with its counts and the time it took")
    func syncedLine() async throws {
        let logger = RecordingLogger()

        await Self.bootstrap(store: InMemoryDesignStore(), gate: FakeRenderingGate(), logger: logger).check { _, _ in }

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
    func replaceBundled(_ design: ValidatedDesign) async throws -> Bool { try await store.replaceBundled(design) }
}
