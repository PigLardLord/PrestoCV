import Foundation

/// Protocol for accessing and managing CV templates
public protocol TemplateRepositoryProtocol: Sendable {
    /// Retrieves all available templates
    func getAllTemplates() async throws -> [Template]

    /// Retrieves a specific template by its ID
    func getTemplate(byId id: String) async throws -> Template?
}