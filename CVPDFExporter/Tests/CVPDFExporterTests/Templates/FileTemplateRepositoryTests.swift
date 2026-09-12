import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - File Template Repository Tests (TDD)

@Suite("File Template Repository")
struct FileTemplateRepositoryTests {

    // MARK: - Initialization Tests

    @Test("FileTemplateRepository initializes with templates directory")
    func fileRepositoryInitializesWithDirectory() throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }

        // When
        let repository = storage.makeRepository()

        // Then
        #expect(repository.templatesDirectory == storage.templatesDirectory)
    }

    @Test("FileTemplateRepository creates templates directory if it doesn't exist")
    func fileRepositoryCreatesDirectoryIfNeeded() throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        #expect(!FileManager.default.fileExists(atPath: storage.templatesDirectory.path))

        // When
        _ = storage.makeRepository()

        // Then
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: storage.templatesDirectory.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }

    // MARK: - getTemplates Tests

    @Test("getTemplates returns empty array when nothing is registered")
    func getTemplatesReturnsEmptyArrayWhenNothingIsRegistered() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.isEmpty)
    }

    @Test("getTemplates loads the registered .mcvt packages")
    func getTemplatesLoadsRegisteredPackages() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()
        try storage.writePackage(id: "test-modern", name: "Test Modern")
        try await storage.register(id: "test-modern", name: "Test Modern")

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.count == 1)
        #expect(templates.first?.id == "test-modern")
        #expect(templates.first?.name == "Test Modern")
    }

    @Test("getTemplates skips registered packages that cannot be read")
    func getTemplatesSkipsInvalidPackages() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()
        try storage.writePackage(id: "valid", name: "Valid")
        try storage.writeInvalidPackage(id: "invalid")
        try await storage.register(id: "valid", name: "Valid")
        try await storage.register(id: "invalid", name: "Invalid")

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.count == 1) // Only valid template loaded
        #expect(templates.first?.id == "valid")
    }

    // MARK: - getTemplate(id:) Tests

    @Test("getTemplate returns nil for non-existent template")
    func getTemplateReturnsNilForNonExistentTemplate() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()

        // When
        let template = try await repository.getTemplate(id: "non-existent")

        // Then
        #expect(template == nil)
    }

    @Test("getTemplate returns correct template by ID")
    func getTemplateReturnsCorrectTemplateByID() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()
        for (id, name) in [("template1", "Template 1"), ("template2", "Template 2")] {
            try storage.writePackage(id: id, name: name)
            try await storage.register(id: id, name: name)
        }

        // When
        let template = try await repository.getTemplate(id: "template2")

        // Then
        #expect(template != nil)
        #expect(template?.id == "template2")
        #expect(template?.name == "Template 2")
    }

    // MARK: - installTemplate Tests

    @Test("installTemplate saves package to templates directory")
    func installTemplateSavesPackageToDirectory() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()
        let package = FileRepositoryTestStorage.makePackage(id: "new-template", name: "New Template")

        // When
        try await repository.installTemplate(package)

        // Then - Package file should exist
        let packageURL = storage.templatesDirectory.appendingPathComponent("new-template.mcvt")
        #expect(FileManager.default.fileExists(atPath: packageURL.path))
    }

    @Test("installTemplate throws error for invalid package")
    func installTemplateThrowsErrorForInvalidPackage() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()
        let invalidPackage = FileRepositoryTestStorage.makePackage(id: "", name: "Test") // Invalid empty ID

        // When/Then
        await #expect(throws: TemplateRepositoryError.self) {
            try await repository.installTemplate(invalidPackage)
        }
    }

    @Test("installTemplate makes the installed template available")
    func installTemplateMakesTemplateAvailable() async throws {
        // Given
        let storage = try FileRepositoryTestStorage()
        defer { storage.cleanUp() }
        let repository = storage.makeRepository()

        // When
        try await repository.installTemplate(FileRepositoryTestStorage.makePackage(id: "installed", name: "Installed"))

        // Then
        await withKnownIssue("Installed templates are never registered: https://github.com/PigLardLord/PrestoCV-archive/issues/1") {
            let template = try await repository.getTemplate(id: "installed")
            #expect(template?.id == "installed")
        }
    }
}

// MARK: - Test Storage

/// A temporary templates directory and registry, so that no test writes to Application Support
private struct FileRepositoryTestStorage {
    let root: URL
    let templatesDirectory: URL
    let registryManager: TemplateRegistryManager

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestTemplates_\(UUID().uuidString)")
        templatesDirectory = root.appendingPathComponent("Templates")
        let registryDirectory = root.appendingPathComponent("Registry")
        try FileManager.default.createDirectory(at: registryDirectory, withIntermediateDirectories: true)
        registryManager = TemplateRegistryManager(storageDirectory: registryDirectory)
    }

    func makeRepository() -> FileTemplateRepository {
        FileTemplateRepository(templatesDirectory: templatesDirectory, registryManager: registryManager)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    static func makePackage(id: String, name: String) -> TemplatePackage {
        let manifest = TemplateManifest(
            id: id,
            name: name,
            description: "Test template",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        return TemplatePackage(manifest: manifest, cssContent: "body { margin: 0; }", htmlContent: nil)
    }

    func writePackage(id: String, name: String) throws {
        try FileManager.default.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Self.makePackage(id: id, name: name))
        try data.write(to: templatesDirectory.appendingPathComponent("\(id).mcvt"))
    }

    func writeInvalidPackage(id: String) throws {
        try FileManager.default.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
        try Data("{ invalid json }".utf8).write(to: templatesDirectory.appendingPathComponent("\(id).mcvt"))
    }

    func register(id: String, name: String) async throws {
        try await registryManager.addTemplate(TemplateEntry(
            id: id,
            name: name,
            version: "1.0.0",
            source: .bundled,
            installedAt: Date(),
            previewPath: "\(id)_preview.png"
        ))
    }
}
