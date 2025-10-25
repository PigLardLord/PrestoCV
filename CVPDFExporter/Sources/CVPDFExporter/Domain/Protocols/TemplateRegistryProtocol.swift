import Foundation

/// Protocol for managing the template registry (cache system)
/// Follows SOLID principles - Dependency Inversion and Interface Segregation
public protocol TemplateRegistryProtocol: Sendable {
    /// Loads the registry from persistent storage
    /// - Returns: The current template registry
    /// - Throws: TemplateRegistryError if loading fails
    func loadRegistry() async throws -> TemplateRegistry

    /// Saves the registry to persistent storage
    /// - Parameter registry: The registry to save
    /// - Throws: TemplateRegistryError if saving fails
    func saveRegistry(_ registry: TemplateRegistry) async throws

    /// Adds a new template entry to the registry
    /// - Parameter entry: The template entry to add
    /// - Throws: TemplateRegistryError if adding fails
    func addTemplate(_ entry: TemplateEntry) async throws

    /// Removes a template entry from the registry
    /// - Parameter id: The template ID to remove
    /// - Throws: TemplateRegistryError if removal fails
    func removeTemplate(id: String) async throws

    /// Retrieves a specific template entry by ID
    /// - Parameter id: The template ID to find
    /// - Returns: The template entry if found, nil otherwise
    /// - Throws: TemplateRegistryError if an error occurs during retrieval
    func getTemplate(id: String) async throws -> TemplateEntry?

    /// Retrieves all template entries
    /// - Returns: Array of all template entries
    /// - Throws: TemplateRegistryError if an error occurs during retrieval
    func getAllTemplates() async throws -> [TemplateEntry]

    /// Rebuilds the registry by scanning directories and template packages
    /// Used to sync the cache with the actual file system state
    /// - Returns: The refreshed template registry
    /// - Throws: TemplateRegistryError if refresh fails
    func refreshRegistry() async throws -> TemplateRegistry

    /// Extracts and caches a preview image from base64 data
    /// - Parameters:
    ///   - base64: The base64-encoded PNG data
    ///   - templateId: The template ID (used for naming the cached file)
    /// - Returns: URL to the cached preview image file
    /// - Throws: TemplateRegistryError if extraction or caching fails
    func extractPreview(from base64: String, templateId: String) async throws -> URL
}

// MARK: - Template Registry Error

/// Errors that can occur during registry operations
public enum TemplateRegistryError: Error, LocalizedError, Sendable {
    /// Registry file not found (first launch)
    case registryNotFound

    /// Failed to decode registry JSON
    case decodingFailed(Error)

    /// Failed to encode registry JSON
    case encodingFailed(Error)

    /// I/O error during file operations
    case ioError(String)

    /// Template entry already exists in registry
    case templateAlreadyExists(String)

    /// Template entry not found in registry
    case templateNotFound(String)

    /// Invalid base64 preview data
    case invalidPreviewData

    /// Failed to extract or cache preview image
    case previewExtractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .registryNotFound:
            return "Template registry not found. This is normal on first launch."
        case .decodingFailed(let error):
            return "Failed to decode template registry: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode template registry: \(error.localizedDescription)"
        case .ioError(let message):
            return "I/O error: \(message)"
        case .templateAlreadyExists(let id):
            return "Template '\(id)' already exists in registry"
        case .templateNotFound(let id):
            return "Template '\(id)' not found in registry"
        case .invalidPreviewData:
            return "Invalid preview image data (not valid base64 or PNG)"
        case .previewExtractionFailed(let message):
            return "Failed to extract preview: \(message)"
        }
    }
}
