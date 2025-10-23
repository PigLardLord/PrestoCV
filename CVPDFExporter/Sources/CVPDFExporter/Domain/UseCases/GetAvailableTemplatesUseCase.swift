import Foundation

/// Use Case: Get all available templates from multiple repositories
/// Follows Clean Architecture - Use Case Layer (Business Logic)
/// Coordinates fetching templates from bundled, file-based, and remote sources
public final class GetAvailableTemplatesUseCase: @unchecked Sendable {

    private let repositories: [TemplateRepositoryProtocol]

    /// Initialize with array of template repositories
    /// Repositories are queried in order, with earlier repositories taking precedence for duplicates
    /// - Parameter repositories: Array of template repositories (bundled, file, remote, etc.)
    public init(repositories: [TemplateRepositoryProtocol]) {
        self.repositories = repositories
    }

    /// Execute the use case to retrieve all available templates
    /// - Returns: Array of unique templates from all repositories
    /// - Note: Handles repository failures gracefully, returning templates from working repositories
    public func execute() async throws -> [Template] {
        var allTemplates: [Template] = []
        var seenIds: Set<String> = []

        // Query each repository in order
        for repository in repositories {
            do {
                let templates = try await repository.getTemplates()

                // Add only unique templates (by ID)
                for template in templates {
                    if !seenIds.contains(template.id) {
                        allTemplates.append(template)
                        seenIds.insert(template.id)
                    }
                    // If duplicate ID found, first repository wins (precedence)
                }
            } catch {
                // Gracefully handle repository failures
                // Continue to next repository rather than failing entire operation
                continue
            }
        }

        return allTemplates
    }
}
