import Foundation
import CVDesignCatalog

public struct BundleDesignSource: BundledDesignSource {
    public init() {}
    public func bundledPackages() async throws -> [(name: String, data: Data)] {
        guard let dir = Bundle.module.url(forResource: "Resources", withExtension: nil) else { throw CocoaError(.fileNoSuchFile) }
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mcvt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { ($0.deletingPathExtension().lastPathComponent, try Data(contentsOf: $0)) }
    }
}
