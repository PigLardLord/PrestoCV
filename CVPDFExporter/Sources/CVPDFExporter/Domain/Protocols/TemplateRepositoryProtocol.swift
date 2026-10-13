import Foundation

/// Protocol for accessing and managing CV templates
/// Follows SOLID principles - Dependency Inversion (depend on abstractions, not concretions)
public protocol TemplateRepositoryProtocol: Sendable {
    /// Retrieves all available templates from this repository
    /// - Returns: Array of templates
    /// - Throws: TemplateRepositoryError if templates cannot be loaded
    func getTemplates() async throws -> [Template]

    /// Retrieves a specific template by ID
    /// - Parameter id: The unique identifier of the template
    /// - Returns: The template if found, nil otherwise
    /// - Throws: TemplateRepositoryError if an error occurs during retrieval
    func getTemplate(id: String) async throws -> Template?

    /// Installs a template package into this repository
    /// - Parameter package: The template package to install
    /// - Throws: TemplateRepositoryError if installation fails (invalid package, I/O error, etc.)
    func installTemplate(_ package: TemplatePackage) async throws
}

// MARK: - Convenience Methods (Default Implementations)
public extension TemplateRepositoryProtocol {
    /// The template with the given ID
    /// - Throws: TemplateError.templateNotFound if the repository has no such template
    func loadTemplate(id: String) async throws -> Template {
        guard let template = try await getTemplate(id: id) else {
            throw TemplateError.templateNotFound(id)
        }
        return template
    }

    /// Legacy method for backward compatibility
    func getAllTemplates() async throws -> [Template] {
        try await getTemplates()
    }

    /// Legacy method for backward compatibility
    func getTemplate(byId id: String) async throws -> Template? {
        try await getTemplate(id: id)
    }
}