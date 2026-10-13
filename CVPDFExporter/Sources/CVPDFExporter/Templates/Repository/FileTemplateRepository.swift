import Foundation

/// Repository for loading and installing templates from the file system
/// Manages .mcvt template packages in a designated directory
/// Uses TemplateRegistryManager for metadata and preview management
public final class FileTemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {

    public let templatesDirectory: URL
    private let fileManager = FileManager.default
    private let registryManager: TemplateRegistryManager

    // MARK: - Initialization

    public init(templatesDirectory: URL, registryManager: TemplateRegistryManager) {
        self.templatesDirectory = templatesDirectory
        self.registryManager = registryManager
        createTemplatesDirectoryIfNeeded()
    }

    /// Convenience initializer that creates a default registry manager
    public convenience init(templatesDirectory: URL) throws {
        let registryManager = try TemplateRegistryManager()
        self.init(templatesDirectory: templatesDirectory, registryManager: registryManager)
    }

    // MARK: - TemplateRepositoryProtocol

    public func getTemplates() async throws -> [Template] {
        // Load registry entries
        let registryEntries = try await registryManager.getAllTemplates()
        var templates: [Template] = []

        for entry in registryEntries {
            do {
                // Load package from templates directory
                let packageURL = templatesDirectory.appendingPathComponent("\(entry.id).mcvt")
                let package = try loadPackage(from: packageURL)

                // Convert to Template with preview URL from registry
                let template = try convertToTemplate(package, previewURL: registryManager.previewURL(for: entry))
                templates.append(template)
            } catch {
                // Skip invalid packages and continue loading others
                continue
            }
        }

        return templates
    }

    public func getTemplate(id: String) async throws -> Template? {
        // Try to get entry from registry first
        guard let entry = try await registryManager.getTemplate(id: id) else {
            return nil
        }

        // Load package
        let packageURL = templatesDirectory.appendingPathComponent("\(entry.id).mcvt")
        do {
            let package = try loadPackage(from: packageURL)
            return try convertToTemplate(package, previewURL: registryManager.previewURL(for: entry))
        } catch {
            return nil
        }
    }

    /// Writes the package file, caches its preview and lists it in the registry, replacing an older installation.
    /// Only registered templates are listed, so the registry entry is written last.
    public func installTemplate(_ package: TemplatePackage) async throws {
        // Validate package
        guard package.isValid else {
            throw TemplateRepositoryError.invalidPackage("Package validation failed: invalid manifest or empty CSS")
        }

        try writePackage(package)
        let previewPath = try await cachePreview(of: package)

        do {
            try await registryManager.upsertTemplate(TemplateEntry(
                id: package.manifest.id,
                name: package.manifest.name,
                version: package.manifest.version,
                source: .bundled,
                installedAt: Date(),
                previewPath: previewPath
            ))
        } catch {
            throw TemplateRepositoryError.ioError("Failed to register template: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func createTemplatesDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: templatesDirectory.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: templatesDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            // Directory creation failure will be caught when attempting to read
        }
    }

    private func writePackage(_ package: TemplatePackage) throws {
        let packageURL = templatesDirectory.appendingPathComponent("\(package.manifest.id).mcvt")

        do {
            try fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(package)
            try data.write(to: packageURL, options: .atomic)
        } catch {
            throw TemplateRepositoryError.ioError("Failed to write package to disk: \(error.localizedDescription)")
        }
    }

    /// Caches the embedded preview image and returns its path for the registry entry.
    /// A package without a preview gets the usual path, so that the UI falls back to its placeholder.
    private func cachePreview(of package: TemplatePackage) async throws -> String {
        let templateId = package.manifest.id

        guard let previewBase64 = package.embeddedPreviewBase64 else {
            return registryManager.previewFileName(forTemplateId: templateId)
        }

        do {
            let previewURL = try await registryManager.extractPreview(from: previewBase64, templateId: templateId)
            return previewURL.lastPathComponent
        } catch {
            throw TemplateRepositoryError.ioError("Failed to cache the preview of \(templateId): \(error.localizedDescription)")
        }
    }

    private func loadPackage(from url: URL) throws -> TemplatePackage {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let package = try decoder.decode(TemplatePackage.self, from: data)

            guard package.isValid else {
                throw TemplateRepositoryError.invalidPackage("Package at \(url.lastPathComponent) failed validation")
            }

            return package
        } catch let error as DecodingError {
            throw TemplateRepositoryError.invalidPackage("Failed to decode package: \(error.localizedDescription)")
        } catch {
            throw TemplateRepositoryError.ioError("Failed to read package file: \(error.localizedDescription)")
        }
    }

    private func convertToTemplate(_ package: TemplatePackage, previewURL: URL) throws -> Template {
        let manifest = package.manifest

        return Template(
            id: manifest.id,
            name: manifest.name,
            description: manifest.description,
            htmlContent: package.composedHTML,
            thumbnailURL: previewURL,
            isPremium: !manifest.isFree
        )
    }
}
