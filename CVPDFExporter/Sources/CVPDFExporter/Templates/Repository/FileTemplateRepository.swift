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
                let template = try convertToTemplate(package, previewPath: entry.previewPath)
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
            return try convertToTemplate(package, previewPath: entry.previewPath)
        } catch {
            return nil
        }
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        // Validate package
        guard package.isValid else {
            throw TemplateRepositoryError.invalidPackage("Package validation failed: invalid manifest or empty CSS")
        }

        // Create package URL based on manifest ID
        let packageURL = templatesDirectory.appendingPathComponent("\(package.manifest.id).mcvt")

        // Encode and write package
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(package)
            try data.write(to: packageURL)
        } catch {
            throw TemplateRepositoryError.ioError("Failed to write package to disk: \(error.localizedDescription)")
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

    private func convertToTemplate(_ package: TemplatePackage, previewPath: String) throws -> Template {
        let manifest = package.manifest

        // Convert preview path to URL
        // Preview path is relative to Application Support (e.g., "TemplateCache/professional_preview.png")
        let previewURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(previewPath)

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
