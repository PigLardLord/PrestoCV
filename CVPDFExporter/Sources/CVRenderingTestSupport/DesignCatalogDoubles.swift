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
