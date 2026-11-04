import Foundation
import CVRendering

/// The heading tables the package ships, read from this target's own bundle (R13). The composition root passes it to
/// `HeadingsCatalog` on Apple platforms and Linux; an Android app passes a source that reads the same files from its
/// assets (ADR 0026).
public struct BundleHeadingTableSource: HeadingTableSource {
    public init() {}

    public func index() throws -> Data {
        guard let url = Bundle.module.url(forResource: "Headings/index", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: url)
    }

    public func table(_ tag: String) throws -> Data? {
        guard let url = Bundle.module.url(forResource: "Headings/\(tag)", withExtension: "json") else { return nil }
        return try Data(contentsOf: url)
    }
}
