import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Registry Manager Tests (Step 5)

@Suite("Template Registry Manager")
struct TemplateRegistryManagerTests {

    // MARK: - Test Fixtures

    static let testDate = Date(timeIntervalSince1970: 1706184600) // 2025-01-25 10:30:00 UTC

    static func createTestEntry(
        id: String = "test-template",
        name: String = "Test Template",
        source: TemplateSource = .bundled
    ) -> TemplateEntry {
        TemplateEntry(
            id: id,
            name: name,
            version: "1.0.0",
            source: source,
            installedAt: testDate,
            previewPath: "\(id)_preview.png"
        )
    }

    static func createTestRegistry(entries: [TemplateEntry] = []) -> TemplateRegistry {
        TemplateRegistry(entries: entries, lastUpdated: testDate)
    }

    // MARK: - Load Registry Tests

    @Test("Load registry from empty storage returns empty registry")
    func loadRegistryFromEmptyStorage() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // When
        let registry = try await manager.loadRegistry()

        // Then
        #expect(registry.entries.isEmpty)
    }

    @Test("Load registry from existing file returns saved registry")
    func loadRegistryFromExistingFile() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry()
        let originalRegistry = Self.createTestRegistry(entries: [entry])

        try await manager.saveRegistry(originalRegistry)

        // When
        let loadedRegistry = try await manager.loadRegistry()

        // Then
        #expect(loadedRegistry.entries.count == 1)
        #expect(loadedRegistry.entries[0].id == "test-template")
    }

    // MARK: - Save Registry Tests

    @Test("Save registry creates file in storage directory")
    func saveRegistryCreatesFile() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry()
        let registry = Self.createTestRegistry(entries: [entry])

        // When
        try await manager.saveRegistry(registry)

        // Then
        let registryPath = tempDir.appendingPathComponent("templates.json")
        #expect(FileManager.default.fileExists(atPath: registryPath.path))
    }

    @Test("Save and load registry preserves data")
    func saveAndLoadPreservesData() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry1 = Self.createTestEntry(id: "modern", name: "Modern", source: .bundled)
        let entry2 = Self.createTestEntry(id: "custom", name: "Custom", source: .airDrop)
        let registry = Self.createTestRegistry(entries: [entry1, entry2])

        // When
        try await manager.saveRegistry(registry)
        let loaded = try await manager.loadRegistry()

        // Then
        #expect(loaded.entries.count == 2)
        #expect(loaded.entries[0].id == "modern")
        #expect(loaded.entries[0].source == .bundled)
        #expect(loaded.entries[1].id == "custom")
        #expect(loaded.entries[1].source == .airDrop)
    }

    // MARK: - Add Template Tests

    @Test("Add template to empty registry")
    func addTemplateToEmptyRegistry() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry()

        // When
        try await manager.addTemplate(entry)

        // Then
        let registry = try await manager.loadRegistry()
        #expect(registry.entries.count == 1)
        #expect(registry.entries[0].id == "test-template")
    }

    @Test("Add template to existing registry")
    func addTemplateToExistingRegistry() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry1 = Self.createTestEntry(id: "first", name: "First")
        try await manager.addTemplate(entry1)

        let entry2 = Self.createTestEntry(id: "second", name: "Second")

        // When
        try await manager.addTemplate(entry2)

        // Then
        let registry = try await manager.loadRegistry()
        #expect(registry.entries.count == 2)
    }

    @Test("Add duplicate template throws error")
    func addDuplicateTemplateThrowsError() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry(id: "duplicate")
        try await manager.addTemplate(entry)

        // When/Then
        await #expect(throws: TemplateRegistryError.self) {
            try await manager.addTemplate(entry)
        }
    }

    // MARK: - Remove Template Tests

    @Test("Remove template from registry")
    func removeTemplateFromRegistry() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry(id: "to-remove")
        try await manager.addTemplate(entry)

        // When
        try await manager.removeTemplate(id: "to-remove")

        // Then
        let registry = try await manager.loadRegistry()
        #expect(registry.entries.isEmpty)
    }

    @Test("Remove non-existent template throws error")
    func removeNonExistentTemplateThrowsError() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // When/Then
        await #expect(throws: TemplateRegistryError.self) {
            try await manager.removeTemplate(id: "non-existent")
        }
    }

    // MARK: - Get Template Tests

    @Test("Get template by ID returns correct template")
    func getTemplateByIdReturnsCorrectTemplate() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry1 = Self.createTestEntry(id: "modern", name: "Modern")
        let entry2 = Self.createTestEntry(id: "professional", name: "Professional")
        try await manager.addTemplate(entry1)
        try await manager.addTemplate(entry2)

        // When
        let found = try await manager.getTemplate(id: "professional")

        // Then
        #expect(found != nil)
        #expect(found?.id == "professional")
        #expect(found?.name == "Professional")
    }

    @Test("Get template by non-existent ID returns nil")
    func getTemplateByNonExistentIdReturnsNil() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // When
        let found = try await manager.getTemplate(id: "non-existent")

        // Then
        #expect(found == nil)
    }

    // MARK: - Get All Templates Tests

    @Test("Get all templates returns all entries")
    func getAllTemplatesReturnsAllEntries() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry1 = Self.createTestEntry(id: "first", name: "First")
        let entry2 = Self.createTestEntry(id: "second", name: "Second")
        let entry3 = Self.createTestEntry(id: "third", name: "Third")
        try await manager.addTemplate(entry1)
        try await manager.addTemplate(entry2)
        try await manager.addTemplate(entry3)

        // When
        let templates = try await manager.getAllTemplates()

        // Then
        #expect(templates.count == 3)
        #expect(templates.contains(where: { $0.id == "first" }))
        #expect(templates.contains(where: { $0.id == "second" }))
        #expect(templates.contains(where: { $0.id == "third" }))
    }

    @Test("Get all templates from empty registry returns empty array")
    func getAllTemplatesFromEmptyRegistryReturnsEmptyArray() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // When
        let templates = try await manager.getAllTemplates()

        // Then
        #expect(templates.isEmpty)
    }

    // MARK: - Extract Preview Tests

    @Test("Extract preview from valid base64 creates PNG file")
    func extractPreviewFromValidBase64CreatesPNGFile() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // 1x1 red pixel PNG in base64
        let validBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

        // When
        let previewURL = try await manager.extractPreview(from: validBase64, templateId: "test-template")

        // Then
        #expect(FileManager.default.fileExists(atPath: previewURL.path))
        #expect(previewURL.lastPathComponent == "test-template_preview.png")
    }

    @Test("Extract preview from invalid base64 throws error")
    func extractPreviewFromInvalidBase64ThrowsError() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let invalidBase64 = "not-valid-base64!!!"

        // When/Then
        await #expect(throws: TemplateRegistryError.self) {
            try await manager.extractPreview(from: invalidBase64, templateId: "test")
        }
    }

    @Test("Extract preview overwrites existing preview")
    func extractPreviewOverwritesExistingPreview() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="

        // Create initial preview
        let firstURL = try await manager.extractPreview(from: base64, templateId: "template")
        let firstCreationDate = try FileManager.default.attributesOfItem(atPath: firstURL.path)[.creationDate] as? Date

        // Wait a bit to ensure different timestamps
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // When - extract again
        let secondURL = try await manager.extractPreview(from: base64, templateId: "template")
        let secondCreationDate = try FileManager.default.attributesOfItem(atPath: secondURL.path)[.creationDate] as? Date

        // Then
        #expect(firstURL == secondURL)
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
    }

    // MARK: - Refresh Registry Tests

    @Test("Refresh registry returns current registry when no changes")
    func refreshRegistryReturnsCurrentRegistryWhenNoChanges() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry()
        try await manager.addTemplate(entry)

        // When
        let refreshed = try await manager.refreshRegistry()

        // Then
        #expect(refreshed.entries.count == 1)
        #expect(refreshed.entries[0].id == "test-template")
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent adds are thread-safe")
    func concurrentAddsAreThreadSafe() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // When - Add 10 templates concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let entry = Self.createTestEntry(id: "template-\(i)", name: "Template \(i)")
                    try? await manager.addTemplate(entry)
                }
            }
        }

        // Then
        let templates = try await manager.getAllTemplates()
        #expect(templates.count == 10)
    }

    // MARK: - Upsert Tests

    @Test("Upsert adds a template that is not registered yet")
    func upsertAddsNewTemplate() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let manager = TemplateRegistryManager(storageDirectory: tempDir)

        // When
        try await manager.upsertTemplate(Self.createTestEntry(id: "first"))

        // Then
        #expect(try await manager.getAllTemplates().map(\.id) == ["first"])
    }

    @Test("Upsert replaces the entry with the same ID and keeps its position")
    func upsertReplacesEntryInPlace() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        for id in ["one", "two", "three"] {
            try await manager.addTemplate(Self.createTestEntry(id: id))
        }
        let updated = TemplateEntry(
            id: "two",
            name: "Two, updated",
            version: "1.1.0",
            source: .bundled,
            installedAt: Self.testDate,
            previewPath: "two_preview.png"
        )

        // When
        try await manager.upsertTemplate(updated)

        // Then
        let entries = try await manager.getAllTemplates()
        #expect(entries.map(\.id) == ["one", "two", "three"])
        #expect(entries[1] == updated)
    }

    @Test("Preview URL is the cached preview file inside the storage directory")
    func previewURLPointsIntoStorageDirectory() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = TemplateRegistryManager(storageDirectory: tempDir)
        let entry = Self.createTestEntry(id: "pictured")

        // When
        let url = manager.previewURL(for: entry)

        // Then
        #expect(url == tempDir.appendingPathComponent("pictured_preview.png"))
        #expect(url.lastPathComponent == manager.previewFileName(forTemplateId: "pictured"))
    }
}
