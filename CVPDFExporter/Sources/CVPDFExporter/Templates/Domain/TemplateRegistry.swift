import Foundation

// MARK: - Template Source

/// Indicates whether a template is bundled with the app or user-installed
public enum TemplateSource: String, Codable, Sendable {
    /// Template bundled with the application (read-only)
    case bundled

    /// Template installed by the user (via AirDrop, cloud, or sharing)
    case user
}

// MARK: - Template Entry

/// Represents a single template entry in the registry
/// Contains metadata and file paths for quick access without loading the full package
public struct TemplateEntry: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the template
    public let id: String

    /// Display name of the template
    public let name: String

    /// Description of the template
    public let description: String

    /// Semantic version string
    public let version: String

    /// Source of the template (bundled or user-installed)
    public let source: TemplateSource

    /// File system path to the .mcvt package file
    public let packagePath: String

    /// File system path to the cached preview image (PNG)
    /// Nil if preview hasn't been extracted yet
    public let previewPath: String?

    /// Date when the template was last modified
    public let lastModified: Date

    public init(
        id: String,
        name: String,
        description: String,
        version: String,
        source: TemplateSource,
        packagePath: String,
        previewPath: String?,
        lastModified: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.source = source
        self.packagePath = packagePath
        self.previewPath = previewPath
        self.lastModified = lastModified
    }
}

// MARK: - Template Registry

/// Registry of all available templates (bundled + user-installed)
/// Provides fast lookup without scanning directories or loading packages
/// Cached in templates.json for performance
public struct TemplateRegistry: Codable, Equatable, Sendable {
    /// All registered templates
    public var templates: [TemplateEntry]

    /// Date when the registry was last updated
    public var lastUpdate: Date

    public init(templates: [TemplateEntry] = [], lastUpdate: Date = Date()) {
        self.templates = templates
        self.lastUpdate = lastUpdate
    }
}
