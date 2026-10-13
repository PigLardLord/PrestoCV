import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Default Upsert Tests

/// Registries that only add and remove entries get `upsertTemplate` from the protocol extension
@Suite("Template Registry Default Upsert")
struct TemplateRegistryUpsertTests {

    private static func entry(_ id: String, version: String) -> TemplateEntry {
        TemplateEntry(
            id: id,
            name: id.capitalized,
            version: version,
            source: .bundled,
            installedAt: Date(timeIntervalSince1970: 0),
            previewPath: "\(id)_preview.png"
        )
    }

    @Test("upsertTemplate adds an entry the registry does not have")
    func upsertAddsMissingEntry() async throws {
        // Given
        let registry = AddRemoveOnlyRegistry()

        // When
        try await registry.upsertTemplate(Self.entry("new", version: "1.0.0"))

        // Then
        #expect(registry.entries.map(\.id) == ["new"])
    }

    @Test("upsertTemplate replaces the entry with the same ID")
    func upsertReplacesExistingEntry() async throws {
        // Given
        let registry = AddRemoveOnlyRegistry()
        try await registry.addTemplate(Self.entry("evolving", version: "1.0.0"))

        // When
        try await registry.upsertTemplate(Self.entry("evolving", version: "1.1.0"))

        // Then
        #expect(registry.entries.map(\.version) == ["1.1.0"])
    }

    @Test("upsertTemplate passes on any error other than a missing entry")
    func upsertPassesOnOtherErrors() async throws {
        // Given
        let registry = AddRemoveOnlyRegistry()
        registry.removalError = TemplateRegistryError.ioError("disk full")

        // When/Then
        await #expect(throws: TemplateRegistryError.self) {
            try await registry.upsertTemplate(Self.entry("any", version: "1.0.0"))
        }
    }
}

/// A registry written the way mocks are: it implements the original requirements and nothing else
final class AddRemoveOnlyRegistry: TemplateRegistryProtocol, @unchecked Sendable {
    private(set) var entries: [TemplateEntry] = []
    var removalError: Error?

    func loadRegistry() async throws -> TemplateRegistry { TemplateRegistry(entries: entries) }
    func saveRegistry(_ registry: TemplateRegistry) async throws { entries = registry.entries }

    func addTemplate(_ entry: TemplateEntry) async throws {
        if entries.contains(where: { $0.id == entry.id }) {
            throw TemplateRegistryError.templateAlreadyExists(entry.id)
        }
        entries.append(entry)
    }

    func removeTemplate(id: String) async throws {
        if let removalError {
            throw removalError
        }
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw TemplateRegistryError.templateNotFound(id)
        }
        entries.remove(at: index)
    }

    func getTemplate(id: String) async throws -> TemplateEntry? { entries.first { $0.id == id } }
    func getAllTemplates() async throws -> [TemplateEntry] { entries }
    func refreshRegistry() async throws -> TemplateRegistry { TemplateRegistry(entries: entries) }
    func extractPreview(from base64: String, templateId: String) async throws -> URL {
        throw TemplateRegistryError.invalidPreviewData
    }
}
