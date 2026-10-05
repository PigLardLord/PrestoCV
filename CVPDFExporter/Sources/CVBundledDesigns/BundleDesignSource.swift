import Foundation
import CVDesignCatalog

/// The design packages shipped in this target's `Designs` resource folder, served as raw bytes.
public struct BundleDesignSource: BundledDesignSource {
    public init() {}

    /// - Throws: `CocoaError(.fileNoSuchFile)` when the `Designs` resource folder is missing, and the file system's error
    ///   when a package cannot be read.
    public func bundledPackages() async throws -> [(name: String, data: Data)] {
        guard let folder = Bundle.module.url(forResource: "Designs", withExtension: nil) else { throw CocoaError(.fileNoSuchFile) }
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mcvt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { ($0.deletingPathExtension().lastPathComponent, try Data(contentsOf: $0)) }
    }
}
