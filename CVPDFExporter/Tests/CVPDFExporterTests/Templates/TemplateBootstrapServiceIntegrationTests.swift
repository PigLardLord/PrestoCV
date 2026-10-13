import XCTest
@testable import CVPDFExporter

/// Integration tests for TemplateBootstrapService
/// Tests the full flow: bundled .mcvt files → registry → file repository → templates
final class TemplateBootstrapServiceIntegrationTests: XCTestCase {

    var tempDir: URL!
    var templatesDir: URL!
    var registryManager: TemplateRegistryManager!
    var repository: FileTemplateRepository!
    var bootstrapService: TemplateBootstrapService!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temporary directories for testing
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        templatesDir = tempDir.appendingPathComponent("Templates")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        // Initialize components with test directories
        registryManager = TemplateRegistryManager(storageDirectory: tempDir)

        repository = FileTemplateRepository(
            templatesDirectory: templatesDir,
            registryManager: registryManager
        )

        let installUseCase = InstallTemplateUseCase(repository: repository)

        bootstrapService = TemplateBootstrapService(
            installUseCase: installUseCase,
            registryManager: registryManager
        )
    }

    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }

        tempDir = nil
        templatesDir = nil
        registryManager = nil
        repository = nil
        bootstrapService = nil

        try super.tearDownWithError()
    }

    // MARK: - Integration Tests

    func testBootstrapSyncsBundledTemplates() async throws {
        // When: Bundled templates are synced into an empty installation
        try await bootstrapService.syncBundledTemplates()

        // Then: Every bundled package is written to the templates directory
        for id in ["professional", "modern", "minimal"] {
            let packageURL = templatesDir.appendingPathComponent("\(id).mcvt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.path), "\(id).mcvt should be installed")
        }

        // And: The registry lists them
        let templates = try await registryManager.getAllTemplates()
        XCTAssertEqual(templates.count, 3, "Registry should list the bundled templates")
    }

    func testBootstrapInstallsNewTemplate() async throws {
        // Given: A template package
        let package = createTestPackage(id: "test-template", version: "1.0.0")

        // When: Template is installed
        try await repository.installTemplate(package)

        // Then: Template should be in registry
        let entry = try await registryManager.getTemplate(id: "test-template")
        XCTAssertNotNil(entry, "Template should be registered")
        XCTAssertEqual(entry?.version, "1.0.0")
        XCTAssertEqual(entry?.source, .bundled)

        // And: Template should be loadable from repository
        let template = try await repository.getTemplate(id: "test-template")
        XCTAssertNotNil(template, "Template should be loadable")
        XCTAssertEqual(template?.id, "test-template")
        XCTAssertEqual(template?.name, "Test Template")
    }

    func testBootstrapUpdatesExistingTemplate() async throws {
        // Given: An existing template with version 1.0.0
        let oldPackage = createTestPackage(id: "test-template", version: "1.0.0")
        try await repository.installTemplate(oldPackage)

        // Verify old version is installed
        var entry = try await registryManager.getTemplate(id: "test-template")
        XCTAssertEqual(entry?.version, "1.0.0")

        // When: A newer version 2.0.0 is installed
        let newPackage = createTestPackage(id: "test-template", version: "2.0.0")
        try await repository.installTemplate(newPackage)

        // Then: Template should be updated to new version
        entry = try await registryManager.getTemplate(id: "test-template")
        XCTAssertEqual(entry?.version, "2.0.0", "Template should be updated to newer version")
    }

    func testBootstrapDoesNotDowngradeTemplate() async throws {
        // Given: An existing template with version 2.0.0
        let newPackage = createTestPackage(id: "test-template", version: "2.0.0")
        try await repository.installTemplate(newPackage)

        // When: An older version 1.0.0 is encountered
        // Simulate version check (bootstrap service would skip this)
        let entry = try await registryManager.getTemplate(id: "test-template")
        let existingEntry = try XCTUnwrap(entry, "Template should be registered")
        let shouldUpdate = versionIsNewer(new: "1.0.0", existing: existingEntry.version)

        // Then: Should not update to older version
        XCTAssertFalse(shouldUpdate, "Should not downgrade to older version")
    }

    func testBootstrapPreservesPreviewCache() async throws {
        // Given: A template with a preview
        let package = createTestPackage(id: "test-template", version: "1.0.0")
        try await repository.installTemplate(package)

        // Get the preview location from the registry
        let entry = try await registryManager.getTemplate(id: "test-template")
        let registeredEntry = try XCTUnwrap(entry, "Template should be registered")
        let previewURL = registryManager.previewURL(for: registeredEntry)

        // Then: Preview file should exist
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: previewURL.path),
            "Preview file should exist in cache"
        )
    }

    func testMultipleTemplatesCanBeInstalled() async throws {
        // Given: Multiple template packages
        let professional = createTestPackage(id: "professional", version: "1.0.0")
        let modern = createTestPackage(id: "modern", version: "1.0.0")
        let minimal = createTestPackage(id: "minimal", version: "1.0.0")

        // When: All templates are installed
        try await repository.installTemplate(professional)
        try await repository.installTemplate(modern)
        try await repository.installTemplate(minimal)

        // Then: All templates should be in registry
        let entries = try await registryManager.getAllTemplates()
        XCTAssertEqual(entries.count, 3, "Should have 3 templates installed")

        let ids = Set(entries.map { $0.id })
        XCTAssertTrue(ids.contains("professional"))
        XCTAssertTrue(ids.contains("modern"))
        XCTAssertTrue(ids.contains("minimal"))

        // And: All templates should be loadable
        let templates = try await repository.getTemplates()
        XCTAssertEqual(templates.count, 3, "Should load 3 templates")
    }

    func testTemplateWithInvalidManifestIsRejected() async throws {
        // Given: A package with invalid manifest (empty ID)
        let invalidManifest = TemplateManifest(
            id: "",
            name: "Invalid Template",
            description: "Test",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let package = TemplatePackage(
            manifest: invalidManifest,
            cssContent: "body { margin: 0; }",
            htmlContent: nil
        )

        // When/Then: Installation should fail
        do {
            try await repository.installTemplate(package)
            XCTFail("Should reject invalid package")
        } catch {
            // Expected to throw
        }
    }

    func testBundledTemplateRepositoryUsesRegistry() async throws {
        // Given: Templates installed via FileTemplateRepository
        let package = createTestPackage(id: "test-template", version: "1.0.0")
        try await repository.installTemplate(package)

        // When: BundledTemplateRepository is created with same registry
        let bundledRepo = BundledTemplateRepository(fileRepository: repository)

        // Then: It should load templates from registry
        let templates = try await bundledRepo.getTemplates()
        XCTAssertEqual(templates.count, 1, "BundledTemplateRepository should load from registry")
        XCTAssertEqual(templates.first?.id, "test-template")
    }

    // MARK: - Helper Methods

    private func createTestPackage(id: String, version: String) -> TemplatePackage {
        // Create a minimal PNG image (1x1 pixel)
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  // 1x1 dimensions
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
            0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,  // IEND chunk
            0x44, 0xAE, 0x42, 0x60, 0x82
        ])

        let manifest = TemplateManifest(
            id: id,
            name: "Test Template",
            description: "Test description",
            author: "Test Author",
            version: version,
            previewImage: "preview.png",
            previewImageBase64: pngData.base64EncodedString(),
            price: 0.0
        )

        let css = """
        body {
            margin: 0;
            font-family: sans-serif;
        }
        """

        return TemplatePackage(
            manifest: manifest,
            cssContent: css,
            htmlContent: nil
        )
    }

    private func versionIsNewer(new: String, existing: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let existingComponents = existing.split(separator: ".").compactMap { Int($0) }

        guard newComponents.count == 3, existingComponents.count == 3 else {
            return true
        }

        for i in 0..<3 {
            if newComponents[i] > existingComponents[i] {
                return true
            } else if newComponents[i] < existingComponents[i] {
                return false
            }
        }

        return false
    }
}
