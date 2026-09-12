import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - TemplateSource Tests

@Suite("TemplateSource Tests")
struct TemplateSourceTests {

    @Test("TemplateSource has all required cases")
    func templateSource_hasAllCases() {
        let allCases = TemplateSource.allCases

        #expect(allCases.contains(.bundled))
        #expect(allCases.contains(.airDrop))
        #expect(allCases.contains(.email))
        #expect(allCases.contains(.chat))
        #expect(allCases.contains(.other))
    }

    @Test("TemplateSource is Codable")
    func templateSource_isCodable() throws {
        let source = TemplateSource.bundled
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(TemplateSource.self, from: encoded)

        #expect(decoded == source)
    }
}

// MARK: - TemplateEntry Tests

@Suite("TemplateEntry Tests")
struct TemplateEntryTests {

    @Test("TemplateEntry initializes with all properties")
    func templateEntry_initialization() {
        let now = Date()
        let entry = TemplateEntry(
            id: "test-template",
            name: "Test Template",
            version: "1.0.0",
            source: .bundled,
            installedAt: now,
            previewPath: "TemplateCache/test_preview.png"
        )

        #expect(entry.id == "test-template")
        #expect(entry.name == "Test Template")
        #expect(entry.version == "1.0.0")
        #expect(entry.source == .bundled)
        #expect(entry.installedAt == now)
        #expect(entry.previewPath == "TemplateCache/test_preview.png")
    }

    @Test("TemplateEntry is Codable")
    func templateEntry_isCodable() throws {
        let entry = TemplateEntry(
            id: "professional",
            name: "Professional",
            version: "1.2.0",
            source: .airDrop,
            installedAt: Date(),
            previewPath: "TemplateCache/professional_preview.png"
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TemplateEntry.self, from: encoded)

        #expect(decoded.id == entry.id)
        #expect(decoded.name == entry.name)
        #expect(decoded.version == entry.version)
        #expect(decoded.source == entry.source)
        #expect(decoded.previewPath == entry.previewPath)
    }

    @Test("TemplateEntry is Equatable")
    func templateEntry_isEquatable() {
        let date = Date()
        let entry1 = TemplateEntry(
            id: "modern",
            name: "Modern",
            version: "1.0.0",
            source: .bundled,
            installedAt: date,
            previewPath: "cache/modern.png"
        )

        let entry2 = TemplateEntry(
            id: "modern",
            name: "Modern",
            version: "1.0.0",
            source: .bundled,
            installedAt: date,
            previewPath: "cache/modern.png"
        )

        #expect(entry1 == entry2)
    }
}

// MARK: - TemplateRegistry Tests

@Suite("TemplateRegistry Tests")
struct TemplateRegistryTests {

    @Test("TemplateRegistry initializes with empty entries")
    func templateRegistry_emptyInitialization() {
        let registry = TemplateRegistry(entries: [])

        #expect(registry.entries.isEmpty)
        #expect(registry.version == "1.0")
        #expect(registry.lastUpdated != nil)
    }

    @Test("TemplateRegistry initializes with entries")
    func templateRegistry_withEntries() {
        let entry = TemplateEntry(
            id: "test",
            name: "Test",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/test.png"
        )

        let registry = TemplateRegistry(entries: [entry])

        #expect(registry.entries.count == 1)
        #expect(registry.entries[0].id == "test")
    }

    @Test("TemplateRegistry is Codable")
    func templateRegistry_isCodable() throws {
        let entry = TemplateEntry(
            id: "professional",
            name: "Professional",
            version: "2.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/professional.png"
        )

        let registry = TemplateRegistry(entries: [entry])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encoded = try encoder.encode(registry)

        let decoded = try JSONDecoder().decode(TemplateRegistry.self, from: encoded)

        #expect(decoded.entries.count == 1)
        #expect(decoded.entries[0].id == "professional")
        #expect(decoded.version == "1.0")
    }

    @Test("TemplateRegistry finds entry by id")
    func templateRegistry_findEntryById() {
        let entry1 = TemplateEntry(
            id: "modern",
            name: "Modern",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/modern.png"
        )

        let entry2 = TemplateEntry(
            id: "minimal",
            name: "Minimal",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/minimal.png"
        )

        let registry = TemplateRegistry(entries: [entry1, entry2])

        let found = registry.findEntry(id: "minimal")
        #expect(found?.id == "minimal")

        let notFound = registry.findEntry(id: "nonexistent")
        #expect(notFound == nil)
    }

    @Test("TemplateRegistry checks if template exists")
    func templateRegistry_hasTemplate() {
        let entry = TemplateEntry(
            id: "professional",
            name: "Professional",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/professional.png"
        )

        let registry = TemplateRegistry(entries: [entry])

        #expect(registry.hasTemplate(id: "professional") == true)
        #expect(registry.hasTemplate(id: "nonexistent") == false)
    }

    @Test("TemplateRegistry adds new entry")
    func templateRegistry_addEntry() {
        var registry = TemplateRegistry(entries: [])
        #expect(registry.entries.isEmpty)

        let entry = TemplateEntry(
            id: "modern",
            name: "Modern",
            version: "1.0.0",
            source: .airDrop,
            installedAt: Date(),
            previewPath: "cache/modern.png"
        )

        registry.addEntry(entry)

        #expect(registry.entries.count == 1)
        #expect(registry.entries[0].id == "modern")
    }

    @Test("TemplateRegistry updates existing entry")
    func templateRegistry_updateEntry() {
        let entry = TemplateEntry(
            id: "professional",
            name: "Professional",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/professional.png"
        )

        var registry = TemplateRegistry(entries: [entry])
        #expect(registry.entries[0].version == "1.0.0")

        let updatedEntry = TemplateEntry(
            id: "professional",
            name: "Professional Updated",
            version: "2.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/professional_v2.png"
        )

        let success = registry.updateEntry(updatedEntry)

        #expect(success == true)
        #expect(registry.entries.count == 1)
        #expect(registry.entries[0].version == "2.0.0")
        #expect(registry.entries[0].name == "Professional Updated")
    }

    @Test("TemplateRegistry update returns false for non-existent entry")
    func templateRegistry_updateNonExistent() {
        var registry = TemplateRegistry(entries: [])

        let entry = TemplateEntry(
            id: "nonexistent",
            name: "Nonexistent",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/test.png"
        )

        let success = registry.updateEntry(entry)

        #expect(success == false)
        #expect(registry.entries.isEmpty)
    }

    @Test("TemplateRegistry removes entry by id")
    func templateRegistry_removeEntry() {
        let entry1 = TemplateEntry(
            id: "modern",
            name: "Modern",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/modern.png"
        )

        let entry2 = TemplateEntry(
            id: "minimal",
            name: "Minimal",
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "cache/minimal.png"
        )

        var registry = TemplateRegistry(entries: [entry1, entry2])
        #expect(registry.entries.count == 2)

        let success = registry.removeEntry(id: "modern")

        #expect(success == true)
        #expect(registry.entries.count == 1)
        #expect(registry.entries[0].id == "minimal")
    }

    @Test("TemplateRegistry remove returns false for non-existent id")
    func templateRegistry_removeNonExistent() {
        var registry = TemplateRegistry(entries: [])

        let success = registry.removeEntry(id: "nonexistent")

        #expect(success == false)
    }

    @Test("TemplateRegistry decodes the file the registry manager writes")
    func templateRegistry_decodesManagerFile() throws {
        let json = Data("""
        {
          "entries" : [
            {
              "id" : "modern",
              "installedAt" : "2025-01-25T10:30:00Z",
              "name" : "Modern",
              "previewPath" : "modern_preview.png",
              "source" : "bundled",
              "version" : "1.0.0"
            },
            {
              "id" : "custom",
              "installedAt" : "2025-01-25T14:20:00Z",
              "name" : "Custom",
              "previewPath" : "custom_preview.png",
              "source" : "airDrop",
              "version" : "1.0.0"
            }
          ],
          "lastUpdated" : "2025-01-25T14:20:00Z",
          "version" : "1.0"
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let registry = try decoder.decode(TemplateRegistry.self, from: json)

        #expect(registry.entries.count == 2)
        #expect(registry.entries[0].source == .bundled)
        #expect(registry.entries[1].source == .airDrop)
        #expect(registry.lastUpdated == ISO8601DateFormatter().date(from: "2025-01-25T14:20:00Z"))
    }

    @Test("TemplateRegistry keeps the last update date it is given")
    func templateRegistry_keepsLastUpdated() {
        let date = Date(timeIntervalSince1970: 1_737_814_800)

        let registry = TemplateRegistry(entries: [], lastUpdated: date)

        #expect(registry.lastUpdated == date)
    }
}
