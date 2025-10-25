import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Registry Tests (Step 3)

@Suite("Template Registry Domain Models")
struct TemplateRegistryTests {

    // MARK: - TemplateSource Tests

    @Test("TemplateSource has bundled case")
    func templateSourceHasBundledCase() {
        // Given/When
        let source = TemplateSource.bundled

        // Then
        #expect(source == .bundled)
    }

    @Test("TemplateSource has user case")
    func templateSourceHasUserCase() {
        // Given/When
        let source = TemplateSource.user

        // Then
        #expect(source == .user)
    }

    @Test("TemplateSource is Codable")
    func templateSourceIsCodable() throws {
        // Given
        let bundledSource = TemplateSource.bundled
        let userSource = TemplateSource.user

        // When
        let encoder = JSONEncoder()
        let bundledData = try encoder.encode(bundledSource)
        let userData = try encoder.encode(userSource)

        let decoder = JSONDecoder()
        let decodedBundled = try decoder.decode(TemplateSource.self, from: bundledData)
        let decodedUser = try decoder.decode(TemplateSource.self, from: userData)

        // Then
        #expect(decodedBundled == .bundled)
        #expect(decodedUser == .user)
    }

    // MARK: - TemplateEntry Tests

    @Test("TemplateEntry has all required properties")
    func templateEntryHasRequiredProperties() {
        // Given
        let entry = TemplateEntry(
            id: "modern",
            name: "Modern",
            description: "Modern template",
            version: "1.0.0",
            source: .bundled,
            packagePath: "/path/to/modern.mcvt",
            previewPath: "/path/to/modern_preview.png",
            lastModified: Date()
        )

        // Then
        #expect(entry.id == "modern")
        #expect(entry.name == "Modern")
        #expect(entry.description == "Modern template")
        #expect(entry.version == "1.0.0")
        #expect(entry.source == .bundled)
        #expect(entry.packagePath == "/path/to/modern.mcvt")
        #expect(entry.previewPath == "/path/to/modern_preview.png")
        #expect(entry.lastModified != nil)
    }

    @Test("TemplateEntry supports optional preview path")
    func templateEntrySupportsOptionalPreviewPath() {
        // Given
        let entry = TemplateEntry(
            id: "test",
            name: "Test",
            description: "Test template",
            version: "1.0.0",
            source: .user,
            packagePath: "/path/to/test.mcvt",
            previewPath: nil,
            lastModified: Date()
        )

        // Then
        #expect(entry.previewPath == nil)
    }

    @Test("TemplateEntry is Codable")
    func templateEntryIsCodable() throws {
        // Given
        let date = Date()
        let entry = TemplateEntry(
            id: "professional",
            name: "Professional",
            description: "Professional template",
            version: "2.0.0",
            source: .bundled,
            packagePath: "/path/to/professional.mcvt",
            previewPath: "/path/to/professional_preview.png",
            lastModified: date
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TemplateEntry.self, from: data)

        // Then
        #expect(decoded.id == entry.id)
        #expect(decoded.name == entry.name)
        #expect(decoded.source == entry.source)
        #expect(decoded.packagePath == entry.packagePath)
    }

    @Test("TemplateEntry conforms to Identifiable")
    func templateEntryConformsToIdentifiable() {
        // Given
        let entry = TemplateEntry(
            id: "minimal",
            name: "Minimal",
            description: "Minimal template",
            version: "1.0.0",
            source: .bundled,
            packagePath: "/path/to/minimal.mcvt",
            previewPath: nil,
            lastModified: Date()
        )

        // Then - Identifiable provides id property
        #expect(entry.id == "minimal")
    }

    // MARK: - TemplateRegistry Tests

    @Test("TemplateRegistry can be initialized empty")
    func templateRegistryCanBeInitializedEmpty() {
        // Given/When
        let registry = TemplateRegistry()

        // Then
        #expect(registry.templates.isEmpty)
        #expect(registry.lastUpdate != nil)
    }

    @Test("TemplateRegistry can be initialized with templates")
    func templateRegistryCanBeInitializedWithTemplates() {
        // Given
        let entry1 = TemplateEntry(
            id: "modern",
            name: "Modern",
            description: "Modern template",
            version: "1.0.0",
            source: .bundled,
            packagePath: "/path/to/modern.mcvt",
            previewPath: nil,
            lastModified: Date()
        )

        let entry2 = TemplateEntry(
            id: "professional",
            name: "Professional",
            description: "Professional template",
            version: "1.0.0",
            source: .bundled,
            packagePath: "/path/to/professional.mcvt",
            previewPath: nil,
            lastModified: Date()
        )

        // When
        let registry = TemplateRegistry(templates: [entry1, entry2])

        // Then
        #expect(registry.templates.count == 2)
        #expect(registry.templates[0].id == "modern")
        #expect(registry.templates[1].id == "professional")
    }

    @Test("TemplateRegistry is Codable")
    func templateRegistryIsCodable() throws {
        // Given
        let entry = TemplateEntry(
            id: "test",
            name: "Test",
            description: "Test template",
            version: "1.0.0",
            source: .user,
            packagePath: "/path/to/test.mcvt",
            previewPath: nil,
            lastModified: Date()
        )

        let registry = TemplateRegistry(templates: [entry])

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(registry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TemplateRegistry.self, from: data)

        // Then
        #expect(decoded.templates.count == 1)
        #expect(decoded.templates[0].id == "test")
    }

    @Test("TemplateRegistry can be decoded from JSON")
    func templateRegistryCanBeDecodedFromJSON() throws {
        // Given
        let json = """
        {
            "templates": [
                {
                    "id": "modern",
                    "name": "Modern",
                    "description": "Modern template",
                    "version": "1.0.0",
                    "source": "bundled",
                    "packagePath": "/path/to/modern.mcvt",
                    "previewPath": "/path/to/modern_preview.png",
                    "lastModified": "2025-01-25T10:30:00Z"
                },
                {
                    "id": "custom",
                    "name": "Custom",
                    "description": "User template",
                    "version": "1.0.0",
                    "source": "user",
                    "packagePath": "/path/to/custom.mcvt",
                    "previewPath": null,
                    "lastModified": "2025-01-25T14:20:00Z"
                }
            ],
            "lastUpdate": "2025-01-25T14:20:00Z"
        }
        """.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let registry = try decoder.decode(TemplateRegistry.self, from: json)

        // Then
        #expect(registry.templates.count == 2)
        #expect(registry.templates[0].id == "modern")
        #expect(registry.templates[0].source == .bundled)
        #expect(registry.templates[1].id == "custom")
        #expect(registry.templates[1].source == .user)
        #expect(registry.templates[1].previewPath == nil)
    }

    @Test("TemplateRegistry tracks last update date")
    func templateRegistryTracksLastUpdate() {
        // Given
        let specificDate = Date(timeIntervalSince1970: 1706184600) // 2025-01-25 10:30:00 UTC

        // When
        let registry = TemplateRegistry(templates: [], lastUpdate: specificDate)

        // Then
        #expect(registry.lastUpdate == specificDate)
    }

    @Test("TemplateRegistry conforms to Equatable")
    func templateRegistryConformsToEquatable() {
        // Given
        let entry = TemplateEntry(
            id: "test",
            name: "Test",
            description: "Test",
            version: "1.0.0",
            source: .bundled,
            packagePath: "/path",
            previewPath: nil,
            lastModified: Date()
        )

        let date = Date()
        let registry1 = TemplateRegistry(templates: [entry], lastUpdate: date)
        let registry2 = TemplateRegistry(templates: [entry], lastUpdate: date)

        // Then
        #expect(registry1 == registry2)
    }
}
