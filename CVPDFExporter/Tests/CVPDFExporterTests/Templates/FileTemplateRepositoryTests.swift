import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - File Template Repository Tests (TDD)

@Suite("File Template Repository")
struct FileTemplateRepositoryTests {

    // MARK: - Initialization Tests

    @Test("FileTemplateRepository initializes with templates directory")
    func fileRepositoryInitializesWithDirectory() {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")

        // When
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        // Then
        #expect(repository.templatesDirectory == tempDir)
    }

    @Test("FileTemplateRepository creates templates directory if it doesn't exist")
    func fileRepositoryCreatesDirectoryIfNeeded() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")

        // Ensure directory doesn't exist
        try? FileManager.default.removeItem(at: tempDir)

        // When
        _ = FileTemplateRepository(templatesDirectory: tempDir)

        // Then
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - getTemplates Tests

    @Test("getTemplates returns empty array when directory is empty")
    func getTemplatesReturnsEmptyArrayWhenDirectoryEmpty() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.isEmpty)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("getTemplates loads valid .mcvt packages from directory")
    func getTemplatesLoadsValidPackagesFromDirectory() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        // Create a test .mcvt package
        let packageURL = tempDir.appendingPathComponent("test-template.mcvt")
        try createTestPackage(at: packageURL, id: "test-modern", name: "Test Modern")

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.count == 1)
        #expect(templates.first?.id == "test-modern")
        #expect(templates.first?.name == "Test Modern")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("getTemplates skips invalid packages")
    func getTemplatesSkipsInvalidPackages() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        // Create valid package
        let validURL = tempDir.appendingPathComponent("valid.mcvt")
        try createTestPackage(at: validURL, id: "valid", name: "Valid")

        // Create invalid package (corrupted manifest)
        let invalidURL = tempDir.appendingPathComponent("invalid.mcvt")
        try createInvalidPackage(at: invalidURL)

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.count == 1) // Only valid template loaded
        #expect(templates.first?.id == "valid")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - getTemplate(id:) Tests

    @Test("getTemplate returns nil for non-existent template")
    func getTemplateReturnsNilForNonExistentTemplate() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        // When
        let template = try await repository.getTemplate(id: "non-existent")

        // Then
        #expect(template == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("getTemplate returns correct template by ID")
    func getTemplateReturnsCorrectTemplateByID() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        // Create multiple packages
        try createTestPackage(at: tempDir.appendingPathComponent("template1.mcvt"), id: "template1", name: "Template 1")
        try createTestPackage(at: tempDir.appendingPathComponent("template2.mcvt"), id: "template2", name: "Template 2")

        // When
        let template = try await repository.getTemplate(id: "template2")

        // Then
        #expect(template != nil)
        #expect(template?.id == "template2")
        #expect(template?.name == "Template 2")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - installTemplate Tests

    @Test("installTemplate saves package to templates directory")
    func installTemplateSavesPackageToDirectory() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        let manifest = TemplateManifest(
            id: "new-template",
            name: "New Template",
            description: "A new template",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body { color: blue; }",
            htmlContent: nil
        )

        // When
        try await repository.installTemplate(package)

        // Then - Package file should exist
        let packageURL = tempDir.appendingPathComponent("\(manifest.id).mcvt")
        #expect(FileManager.default.fileExists(atPath: packageURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("installTemplate throws error for invalid package")
    func installTemplateThrowsErrorForInvalidPackage() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        let repository = FileTemplateRepository(templatesDirectory: tempDir)

        let invalidManifest = TemplateManifest(
            id: "", // Invalid empty ID
            name: "Test",
            description: "Test",
            author: "Test",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let invalidPackage = TemplatePackage(
            manifest: invalidManifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then
        await #expect(throws: TemplateRepositoryError.self) {
            try await repository.installTemplate(invalidPackage)
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helper Methods

    private func createTestPackage(at url: URL, id: String, name: String) throws {
        let manifest = TemplateManifest(
            id: id,
            name: name,
            description: "Test template",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body { margin: 0; }",
            htmlContent: nil
        )

        // Create parent directory if needed
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Write package as JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(package)
        try data.write(to: url)
    }

    private func createInvalidPackage(at url: URL) throws {
        // Create parent directory if needed
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Write invalid JSON
        let invalidData = "{ invalid json }".data(using: .utf8)!
        try invalidData.write(to: url)
    }
}
