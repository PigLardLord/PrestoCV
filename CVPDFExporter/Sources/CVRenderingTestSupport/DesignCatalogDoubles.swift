import Foundation
import CVDesignCatalog

/// A design store that cannot be reached: every operation fails.
public struct UnavailableStore: DesignStore {
    public struct Failure: Error {}
    public init() {}
    public func save(_ design: ValidatedDesign) async throws { throw Failure() }
    public func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave { throw Failure() }
    public func design(id: String) async throws -> ValidatedDesign? { throw Failure() }
    public func installedDesigns() async throws -> [DesignManifest] { throw Failure() }
    public func installedOrigins() async throws -> [String: DesignOrigin] { throw Failure() }
}

/// A bundled source with a fixed list of packages; `nil` is a source that cannot be read.
public struct FixedBundledSource: BundledDesignSource {
    public struct Unreachable: Error {}
    public let packages: [(name: String, data: Data)]?
    public init(packages: [(name: String, data: Data)]?) { self.packages = packages }
    public func bundledPackages() async throws -> [(name: String, data: Data)] {
        guard let packages else { throw Unreachable() }
        return packages
    }
}

/// An in-memory design store for the sync tests: it records the identifiers it saved, and can be told which calls fail.
/// A design it starts with has the origin the test gives it, or none, as one installed before origins were recorded.
public actor SpyDesignStore: DesignStore {
    public struct Failure: Error {}
    private var designs: [String: ValidatedDesign]
    private var origins: [String: DesignOrigin]
    private let savesFailFor: Set<String>, unreadable: Set<String>, listingFails: Bool
    /// The identifiers saved, in order; a save that failed is not recorded.
    public private(set) var savedIDs: [String] = []

    public init(installed: [ValidatedDesign] = [], origins: [String: DesignOrigin] = [:], savesFailFor: Set<String> = [],
                unreadable: Set<String> = [], listingFails: Bool = false) {
        self.designs = Dictionary(installed.map { ($0.manifest.id, $0) }, uniquingKeysWith: { $1 })
        self.origins = origins
        self.savesFailFor = savesFailFor; self.unreadable = unreadable; self.listingFails = listingFails
    }

    public func save(_ design: ValidatedDesign) async throws {
        let id = design.manifest.id
        if savesFailFor.contains(id) { throw Failure() }
        designs[id] = design
        origins[id] = .imported
        savedIDs.append(id)
    }
    public func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave {
        let id = design.manifest.id
        if savesFailFor.contains(id) { throw Failure() }
        let outcome: ConditionalSave
        if let installed = designs[id] { outcome = design.manifest.version > installed.manifest.version ? .upgraded : .keptInstalled } else { outcome = .installed }
        if outcome != .keptInstalled {
            designs[id] = design
            origins[id] = .bundled
            savedIDs.append(id)
        }
        return outcome
    }
    public func design(id: String) async throws -> ValidatedDesign? {
        if unreadable.contains(id) { throw Failure() }
        return designs[id]
    }
    public func installedDesigns() async throws -> [DesignManifest] {
        if listingFails { throw Failure() }
        return designs.values.map(\.manifest).sorted { $0.id < $1.id }
    }
    public func installedOrigins() async throws -> [String: DesignOrigin] {
        if listingFails { throw Failure() }
        return origins
    }
}

/// A rendering gate for tests: it accepts every design except those it refuses with an error or is cancelled on, and
/// records the identifiers it was asked to verify.
public actor FakeRenderingGate: DesignRenderingGate {
    public struct Refusal: Error {}
    private let refusing: Set<String>, cancellingOn: Set<String>
    public private(set) var verified: [String] = []

    public init(refusing: Set<String> = [], cancellingOn: Set<String> = []) { self.refusing = refusing; self.cancellingOn = cancellingOn }

    public func verify(_ design: ValidatedDesign) async throws {
        let id = design.manifest.id
        verified.append(id)
        if cancellingOn.contains(id) { throw CancellationError() }
        if refusing.contains(id) { throw Refusal() }
    }
}

/// A rendering gate that holds `verify` for one design until the test calls `release()`, so a test can act while a
/// render is in flight. Other designs pass at once.
public actor SuspendingRenderingGate: DesignRenderingGate {
    private let holding: String
    private let entered: AsyncStream<Void>, enteredSignal: AsyncStream<Void>.Continuation
    private let released: AsyncStream<Void>, releaseSignal: AsyncStream<Void>.Continuation

    public init(holding id: String) {
        holding = id
        (entered, enteredSignal) = AsyncStream.makeStream(of: Void.self)
        (released, releaseSignal) = AsyncStream.makeStream(of: Void.self)
    }

    public func verify(_ design: ValidatedDesign) async throws {
        guard design.manifest.id == holding else { return }
        enteredSignal.yield()
        for await _ in released { return }
        try Task.checkCancellation()
    }

    /// Waits until `verify` holds the design: true, or false after `timeout`, when the caller records the issue.
    public func waitUntilEntered(timeout: Duration = .seconds(10)) async -> Bool {
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

    /// Lets the held `verify` return.
    public func release() { releaseSignal.yield() }
}
