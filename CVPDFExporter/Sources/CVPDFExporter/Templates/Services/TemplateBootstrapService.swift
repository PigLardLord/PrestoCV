import Foundation

/// Service responsible for bootstrapping bundled templates on app launch
/// Loads .mcvt packages from Bundle.module and installs them using InstallTemplateUseCase
/// Follows Clean Architecture - Application Service Layer
public final class TemplateBootstrapService: @unchecked Sendable {

    private let installUseCase: InstallTemplateUseCase
    private let registryManager: TemplateRegistryManager
    private let bundledPackagesDirectory: URL?

    // MARK: - Initialization

    /// - Parameter bundledPackagesDirectory: Directory that holds the .mcvt packages to install;
    ///   the module bundle's Templates/Bundled directory when nil
    public init(
        installUseCase: InstallTemplateUseCase,
        registryManager: TemplateRegistryManager,
        bundledPackagesDirectory: URL? = nil
    ) {
        self.installUseCase = installUseCase
        self.registryManager = registryManager
        self.bundledPackagesDirectory = bundledPackagesDirectory
    }

    /// Convenience initializer with default dependencies
    /// - Throws: if the registry or the templates directory cannot be located
    public convenience init() throws {
        let registryManager = try TemplateRegistryManager()
        let repository = FileTemplateRepository(
            templatesDirectory: try TemplateStorageLocation.templatesDirectory(),
            registryManager: registryManager
        )
        let installUseCase = InstallTemplateUseCase(repository: repository)

        self.init(installUseCase: installUseCase, registryManager: registryManager)
    }

    // MARK: - Public Methods

    /// Synchronizes bundled templates with the registry
    /// - Loads .mcvt files from Bundle.module Resources/Templates/Bundled/
    /// - Checks if each template exists in registry
    /// - Installs new templates or updates existing ones if version changed
    public func syncBundledTemplates() async throws {
        // Get bundled template URLs from module bundle
        let bundledTemplateURLs = try getBundledTemplateURLs()

        for templateURL in bundledTemplateURLs {
            do {
                // Load package from bundle
                let package = try loadPackageFromBundle(url: templateURL)

                // Check if template exists in registry
                if let existingEntry = try await registryManager.getTemplate(id: package.manifest.id) {
                    // Compare versions
                    if shouldUpdate(existing: existingEntry.version, new: package.manifest.version) {
                        try await installUseCase.execute(package: package, replacingExisting: true)
                    }
                    // Otherwise skip - already installed with same or newer version
                } else {
                    // New template - install
                    try await installUseCase.execute(package: package)
                }
            } catch {
                // Log error but continue with other templates
                print("⚠️ Failed to sync bundled template at \(templateURL.lastPathComponent): \(error)")
                continue
            }
        }
    }

    // MARK: - Private Methods

    /// Gets all bundled .mcvt template files from module bundle
    private func getBundledTemplateURLs() throws -> [URL] {
        // Look for .mcvt files in Resources/Templates/Bundled/
        guard let bundledDir = bundledPackagesDirectory
            ?? Bundle.module.url(forResource: "Bundled", withExtension: nil, subdirectory: "Templates") else {
            // No bundled templates directory - return empty array
            return []
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: bundledDir.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(
            at: bundledDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return contents
            .filter { $0.pathExtension == "mcvt" }
            .sorted(by: listsBefore)
    }

    /// Bundled templates in the order the export sheet shows them
    private static let displayOrder = ["professional", "modern", "minimal"]

    /// The bundled templates come first in `displayOrder`; any other package follows, by file name.
    /// The file system gives no order, and the first template is the one the export sheet preselects.
    private func listsBefore(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsRank = displayRank(of: lhs)
        let rhsRank = displayRank(of: rhs)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.lastPathComponent < rhs.lastPathComponent
    }

    private func displayRank(of url: URL) -> Int {
        let templateId = url.deletingPathExtension().lastPathComponent
        return Self.displayOrder.firstIndex(of: templateId) ?? Self.displayOrder.count
    }

    /// Loads a template package from a bundle URL
    private func loadPackageFromBundle(url: URL) throws -> TemplatePackage {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let package = try decoder.decode(TemplatePackage.self, from: data)

        guard package.isValid else {
            throw TemplateBootstrapError.invalidPackage("Package \(url.lastPathComponent) failed validation")
        }

        return package
    }

    /// Determines if a template should be updated based on semantic versioning
    /// Returns true if new version is greater than existing version
    private func shouldUpdate(existing: String, new: String) -> Bool {
        let existingComponents = existing.split(separator: ".").compactMap { Int($0) }
        let newComponents = new.split(separator: ".").compactMap { Int($0) }

        // Ensure we have valid version numbers
        guard existingComponents.count == 3, newComponents.count == 3 else {
            // If versions are invalid, default to updating
            return true
        }

        // Compare major.minor.patch
        for i in 0..<3 {
            if newComponents[i] > existingComponents[i] {
                return true
            } else if newComponents[i] < existingComponents[i] {
                return false
            }
        }

        // Versions are equal
        return false
    }
}

// MARK: - Errors

public enum TemplateBootstrapError: Error, LocalizedError {
    case invalidPackage(String)
    case bundleResourceNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidPackage(let message):
            return "Invalid template package: \(message)"
        case .bundleResourceNotFound:
            return "Bundled templates directory not found in module bundle"
        }
    }
}
