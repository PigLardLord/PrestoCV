import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Bootstrap Sync Tests

@Suite("Template Bootstrap Sync")
struct TemplateBootstrapSyncTests {

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    // MARK: - Bundled templates

    @Test("syncing an empty installation registers the bundled templates in display order")
    func syncRegistersBundledTemplatesInOrder() async throws {
        // Given
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }

        // When
        try await storage.makeBootstrapService().syncBundledTemplates()

        // Then
        let entries = try await storage.registryManager.getAllTemplates()
        #expect(entries.map(\.id) == ["professional", "modern", "minimal"])
        #expect(entries.allSatisfy { $0.source == .bundled })
    }

    @Test("every bundled template gets a preview image in the cache")
    func syncCachesAPreviewPerBundledTemplate() async throws {
        // Given
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }

        // When
        try await storage.makeBootstrapService().syncBundledTemplates()

        // Then
        let entries = try await storage.registryManager.getAllTemplates()
        #expect(entries.count == 3)
        for entry in entries {
            let previewURL = storage.registryManager.previewURL(for: entry)
            let header = try Data(contentsOf: previewURL).prefix(8)
            #expect(Array(header) == Self.pngSignature, "\(entry.id) preview should be a PNG image")
        }
    }

    @Test("syncing a second time changes nothing")
    func secondSyncChangesNothing() async throws {
        // Given
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }
        let service = storage.makeBootstrapService()
        try await service.syncBundledTemplates()
        let entriesAfterFirstSync = try await storage.registryManager.getAllTemplates()

        // When
        try await service.syncBundledTemplates()

        // Then
        #expect(try await storage.registryManager.getAllTemplates() == entriesAfterFirstSync)
    }

    @Test("the bundled packages carry their preview at the top level")
    func bundledPackagesCarryTopLevelPreview() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }

        // When
        let packageURL = storage.root.appendingPathComponent("Templates/professional.mcvt")
        let package = try JSONDecoder().decode(TemplatePackage.self, from: Data(contentsOf: packageURL))

        // Then
        #expect(package.previewImageBase64?.isEmpty == false)
    }

    // MARK: - Packages from a directory

    @Test("packages are installed in display order, then by file name")
    func packagesAreInstalledInDisplayOrder() async throws {
        // Given
        let source = try PackageDirectory(packages: ["zeta", "minimal", "alpha", "modern", "professional"].map {
            TemplatePackageFixtures.makePackage(id: $0, name: $0.capitalized)
        })
        defer { source.cleanUp() }
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }

        // When
        try await storage.makeBootstrapService(packagesDirectory: source.url).syncBundledTemplates()

        // Then
        let ids = try await storage.registryManager.getAllTemplates().map(\.id)
        #expect(ids == ["professional", "modern", "minimal", "alpha", "zeta"])
    }

    @Test("a package with a higher version replaces the installed template")
    func higherVersionReplacesInstalledTemplate() async throws {
        // Given
        let oldPreview = TemplatePackageFixtures.makePNG(variant: 1)
        let newPreview = TemplatePackageFixtures.makePNG(variant: 2)
        let source = try PackageDirectory(packages: [TemplatePackageFixtures.makePackage(
            id: "evolving", name: "Evolving", version: "1.0.0", css: "body { color: red; }", preview: oldPreview
        )])
        defer { source.cleanUp() }
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }
        let service = storage.makeBootstrapService(packagesDirectory: source.url)
        try await service.syncBundledTemplates()

        // When
        try source.write(TemplatePackageFixtures.makePackage(
            id: "evolving", name: "Evolving", version: "1.0.1", css: "body { color: blue; }", preview: newPreview
        ))
        try await service.syncBundledTemplates()

        // Then
        let entry = try #require(try await storage.registryManager.getTemplate(id: "evolving"))
        #expect(entry.version == "1.0.1")
        let template = try #require(try await storage.fileRepository.getTemplate(id: "evolving"))
        #expect(template.htmlContent.contains("color: blue;"))
        #expect(try Data(contentsOf: storage.registryManager.previewURL(for: entry)) == newPreview)
    }

    @Test("a package with the same or a lower version is skipped", arguments: ["1.0.0", "0.9.9"])
    func sameOrLowerVersionIsSkipped(version: String) async throws {
        // Given
        let source = try PackageDirectory(packages: [TemplatePackageFixtures.makePackage(
            id: "stable", name: "Stable", version: "1.0.0", css: "body { color: red; }"
        )])
        defer { source.cleanUp() }
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }
        let service = storage.makeBootstrapService(packagesDirectory: source.url)
        try await service.syncBundledTemplates()

        // When
        try source.write(TemplatePackageFixtures.makePackage(
            id: "stable", name: "Stable", version: version, css: "body { color: blue; }"
        ))
        try await service.syncBundledTemplates()

        // Then
        let entry = try #require(try await storage.registryManager.getTemplate(id: "stable"))
        #expect(entry.version == "1.0.0")
        let template = try #require(try await storage.fileRepository.getTemplate(id: "stable"))
        #expect(template.htmlContent.contains("color: red;"))
    }

    @Test("a package that cannot be installed does not stop the others")
    func brokenPackageDoesNotStopTheOthers() async throws {
        // Given
        let source = try PackageDirectory(packages: [
            TemplatePackageFixtures.makePackage(id: "broken", name: "Broken", preview: Data("not a PNG".utf8)),
            TemplatePackageFixtures.makePackage(id: "healthy", name: "Healthy")
        ])
        defer { source.cleanUp() }
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }

        // When
        try await storage.makeBootstrapService(packagesDirectory: source.url).syncBundledTemplates()

        // Then
        #expect(try await storage.registryManager.getAllTemplates().map(\.id) == ["healthy"])
    }
}

// MARK: - Test Storage

/// A temporary directory that holds .mcvt packages, standing in for the app bundle
private struct PackageDirectory {
    let url: URL

    init(packages: [TemplatePackage]) throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestPackages_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for package in packages {
            try write(package)
        }
    }

    func write(_ package: TemplatePackage) throws {
        let data = try JSONEncoder().encode(package)
        try data.write(to: url.appendingPathComponent("\(package.manifest.id).mcvt"))
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: url)
    }
}
