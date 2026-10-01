import Foundation

/// The schema as committed, read from the package's source tree (it is a published file, not a resource of any target)
/// and audited once. A missing or malformed file makes every test that asks for it fail.
enum CommittedSchema {
    private static let loaded = Result { try load() }

    static func validator() throws -> SchemaValidator { try loaded.get() }

    private static func load() throws -> SchemaValidator {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: package.appendingPathComponent("Schema/cvdocument.v1.schema.json"), encoding: .utf8)
        return try SchemaValidator(schema: JSON(parsing: text))
    }
}
