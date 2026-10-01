import Foundation

/// The schema as committed, read from the package's source tree (it is a published file, not a resource of any target)
/// and audited once. It is first checked as strict JSON, because other readers reject or read differently what
/// `JSONDecoder` lets through. A missing or malformed file makes every test that asks for it fail.
enum CommittedSchema {
    private static let loaded = Result { try load() }

    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Schema/cvdocument.v1.schema.json")

    static func validator() throws -> SchemaValidator { try loaded.get() }

    private static func load() throws -> SchemaValidator {
        let data = try Data(contentsOf: url)
        try StrictJSON.check(data)
        return try SchemaValidator(schema: JSON(parsing: data))
    }
}
