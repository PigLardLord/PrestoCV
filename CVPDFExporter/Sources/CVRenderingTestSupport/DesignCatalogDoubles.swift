import Foundation
import CVDesignCatalog

/// A design store that cannot be reached: every operation fails.
public struct UnavailableStore: DesignStore {
    public struct Failure: Error {}
    public init() {}
    public func save(_ design: ValidatedDesign) async throws { throw Failure() }
    public func design(id: String) async throws -> ValidatedDesign? { throw Failure() }
    public func installedDesigns() async throws -> [DesignManifest] { throw Failure() }
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
public actor SpyDesignStore: DesignStore {
    public struct Failure: Error {}
    private var designs: [String: ValidatedDesign]
    private let savesFailFor: Set<String>, unreadable: Set<String>, listingFails: Bool
    /// The identifiers saved, in order; a save that failed is not recorded.
    public private(set) var savedIDs: [String] = []

    public init(installed: [ValidatedDesign] = [], savesFailFor: Set<String> = [], unreadable: Set<String> = [], listingFails: Bool = false) {
        self.designs = Dictionary(installed.map { ($0.manifest.id, $0) }, uniquingKeysWith: { $1 })
        self.savesFailFor = savesFailFor; self.unreadable = unreadable; self.listingFails = listingFails
    }

    public func save(_ design: ValidatedDesign) async throws {
        let id = design.manifest.id
        if savesFailFor.contains(id) { throw Failure() }
        designs[id] = design
        savedIDs.append(id)
    }
    public func design(id: String) async throws -> ValidatedDesign? {
        if unreadable.contains(id) { throw Failure() }
        return designs[id]
    }
    public func installedDesigns() async throws -> [DesignManifest] {
        if listingFails { throw Failure() }
        return designs.values.map(\.manifest).sorted { $0.id < $1.id }
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
