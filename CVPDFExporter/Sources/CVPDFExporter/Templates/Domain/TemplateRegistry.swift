import Foundation

// MARK: - Template Source

/// Represents the source from which a template was installed
public enum TemplateSource: String, Codable, Sendable, CaseIterable {
    case bundled    // Default templates shipped with the app
    case airDrop    // Imported via AirDrop
    case email      // Imported from email attachment
    case chat       // Imported from messaging apps
    case other      // Any other source
}

// MARK: - Template Entry

/// Represents a single template entry in the registry
/// Contains metadata and file paths for quick access without loading the full package
public struct TemplateEntry: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the template
    public let id: String

    /// Display name of the template
    public let name: String

    /// Semantic version string (e.g., "1.0.0")
    public let version: String

    /// Source from which the template was installed
    public let source: TemplateSource

    /// Installation timestamp
    public let installedAt: Date

    /// Path of the preview image, relative to the registry's storage directory (e.g., "professional_preview.png")
    public let previewPath: String

    public init(
        id: String,
        name: String,
        version: String,
        source: TemplateSource,
        installedAt: Date,
        previewPath: String
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.source = source
        self.installedAt = installedAt
        self.previewPath = previewPath
    }
}

// MARK: - Template Registry

/// Registry of all installed templates
public struct TemplateRegistry: Codable, Sendable {
    /// Registry format version
    public let version: String

    /// Last update timestamp
    public let lastUpdated: Date

    /// List of registered templates
    public private(set) var entries: [TemplateEntry]

    public init(entries: [TemplateEntry], version: String = "1.0", lastUpdated: Date = Date()) {
        self.version = version
        self.lastUpdated = lastUpdated
        self.entries = entries
    }

    // MARK: - Query Methods

    /// Find an entry by template ID
    public func findEntry(id: String) -> TemplateEntry? {
        return entries.first { $0.id == id }
    }

    /// Check if a template exists in the registry
    public func hasTemplate(id: String) -> Bool {
        return findEntry(id: id) != nil
    }

    // MARK: - Mutation Methods

    /// Add a new entry to the registry
    public mutating func addEntry(_ entry: TemplateEntry) {
        entries.append(entry)
    }

    /// Update an existing entry
    /// - Returns: true if the entry was found and updated, false otherwise
    @discardableResult
    public mutating func updateEntry(_ entry: TemplateEntry) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return false
        }
        entries[index] = entry
        return true
    }

    /// Remove an entry by ID
    /// - Returns: true if the entry was found and removed, false otherwise
    @discardableResult
    public mutating func removeEntry(id: String) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return false
        }
        entries.remove(at: index)
        return true
    }
}
