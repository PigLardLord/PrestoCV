import Foundation

/// Error types for template installation
public enum TemplateInstallationError: Error, Equatable {
    case invalidPackage(String)
    case duplicateTemplateID(String)
    case repositoryError(String)
}

/// Use Case: Install a template package into the repository
/// Follows Clean Architecture - Use Case Layer (Business Logic)
/// Validates package, checks for duplicates, and delegates to repository
public final class InstallTemplateUseCase: @unchecked Sendable {

    private let repository: TemplateRepositoryProtocol

    /// Initialize with a template repository (typically file-based)
    /// - Parameter repository: Repository where templates will be installed
    public init(repository: TemplateRepositoryProtocol) {
        self.repository = repository
    }

    /// Execute the use case to install a template package
    /// - Parameters:
    ///   - package: The template package to install
    ///   - replacingExisting: Whether an installed template with the same ID is replaced (an update) or rejected
    /// - Throws: TemplateInstallationError if validation fails or a duplicate exists and is not to be replaced
    public func execute(package: TemplatePackage, replacingExisting: Bool = false) async throws {
        // Step 1: Validate the package
        try validatePackage(package)

        // Step 2: Check for duplicate template ID
        if !replacingExisting {
            try await checkForDuplicates(package: package)
        }

        // Step 3: Delegate to repository for actual installation
        do {
            try await repository.installTemplate(package)
        } catch let error as TemplateRepositoryError {
            throw TemplateInstallationError.repositoryError(error.localizedDescription)
        } catch {
            throw TemplateInstallationError.repositoryError("Unknown repository error: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func validatePackage(_ package: TemplatePackage) throws {
        // Use built-in package validation
        guard package.isValid else {
            throw TemplateInstallationError.invalidPackage("Package validation failed")
        }

        // Additional validation: Ensure manifest fields are not just whitespace
        let manifest = package.manifest
        guard !manifest.id.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TemplateInstallationError.invalidPackage("Template ID cannot be empty or whitespace")
        }

        guard !manifest.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TemplateInstallationError.invalidPackage("Template name cannot be empty")
        }

        guard !manifest.version.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TemplateInstallationError.invalidPackage("Template version cannot be empty")
        }

        guard manifest.price >= 0.0 else {
            throw TemplateInstallationError.invalidPackage("Template price cannot be negative")
        }

        // Ensure CSS content is not just whitespace
        guard !package.cssContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TemplateInstallationError.invalidPackage("CSS content cannot be empty")
        }
    }

    private func checkForDuplicates(package: TemplatePackage) async throws {
        // Check if a template with the same ID already exists
        do {
            if let existingTemplate = try await repository.getTemplate(id: package.manifest.id) {
                throw TemplateInstallationError.duplicateTemplateID(
                    "Template with ID '\(existingTemplate.id)' already exists"
                )
            }
        } catch is TemplateInstallationError {
            // Re-throw installation errors
            throw TemplateInstallationError.duplicateTemplateID(
                "Template with ID '\(package.manifest.id)' already exists"
            )
        } catch {
            // Repository errors during lookup are acceptable (e.g., file not found)
            // Continue with installation
        }
    }
}
