import Foundation
@testable import CVPDFExporter

/// A registry and a templates directory in a temporary folder, so that no test touches Application Support.
struct TemplateTestStorage {
    let root: URL
    let registryManager: TemplateRegistryManager
    let fileRepository: FileTemplateRepository

    var repository: BundledTemplateRepository {
        BundledTemplateRepository(fileRepository: fileRepository)
    }

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemplateTestStorage_\(UUID().uuidString)")
        let registryDirectory = root.appendingPathComponent("Registry")
        try FileManager.default.createDirectory(at: registryDirectory, withIntermediateDirectories: true)
        registryManager = TemplateRegistryManager(storageDirectory: registryDirectory)
        fileRepository = FileTemplateRepository(
            templatesDirectory: root.appendingPathComponent("Templates"),
            registryManager: registryManager
        )
    }

    /// Storage holding the bundled templates, installed the way the app does at launch
    static func withBundledTemplates() async throws -> TemplateTestStorage {
        let storage = try TemplateTestStorage()
        try await storage.makeBootstrapService().syncBundledTemplates()
        return storage
    }

    /// A bundled template, as the app finds it after launch. A template is a value, so the storage is gone on return.
    static func loadBundledTemplate(_ id: String) async throws -> Template {
        let storage = try await withBundledTemplates()
        defer { storage.cleanUp() }
        return try await storage.repository.loadTemplate(id: id)
    }

    /// - Parameter packagesDirectory: Where the packages to install are; the module's bundled templates when nil
    func makeBootstrapService(packagesDirectory: URL? = nil) -> TemplateBootstrapService {
        TemplateBootstrapService(
            installUseCase: InstallTemplateUseCase(repository: fileRepository),
            registryManager: registryManager,
            bundledPackagesDirectory: packagesDirectory
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
