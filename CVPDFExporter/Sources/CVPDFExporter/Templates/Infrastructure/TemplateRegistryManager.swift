import Foundation

/// Manages the template registry (cache) with persistent storage
/// Implemented as an actor for thread-safe concurrent access
/// Follows SOLID principles - Single Responsibility (registry management only)
public actor TemplateRegistryManager: TemplateRegistryProtocol {

    // MARK: - Properties

    /// Directory where the registry file and preview cache are stored
    private let storageDirectory: URL

    /// Name of the registry JSON file
    private let registryFileName = "templates.json"

    /// JSON encoder/decoder with ISO8601 date strategy
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Initialization

    /// Initialize with a custom storage directory
    /// - Parameter storageDirectory: Directory for registry file and preview cache
    public init(storageDirectory: URL) {
        self.storageDirectory = storageDirectory
    }

    /// Initialize with default storage directory (Application Support)
    /// - Throws: TemplateRegistryError.ioError if Application Support directory is unavailable
    public init() throws {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw TemplateRegistryError.ioError("Application Support directory not found")
        }

        let templateCacheDir = appSupport.appendingPathComponent("TemplateCache", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: templateCacheDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: templateCacheDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw TemplateRegistryError.ioError("Failed to create template cache directory: \(error.localizedDescription)")
            }
        }

        self.storageDirectory = templateCacheDir
    }

    // MARK: - Registry File Path

    /// Full path to the registry JSON file
    private var registryFilePath: URL {
        storageDirectory.appendingPathComponent(registryFileName)
    }

    // MARK: - Load Registry

    public func loadRegistry() async throws -> TemplateRegistry {
        let filePath = registryFilePath

        // Check if registry file exists
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            // Return empty registry on first launch
            return TemplateRegistry(entries: [])
        }

        do {
            let data = try Data(contentsOf: filePath)
            let registry = try decoder.decode(TemplateRegistry.self, from: data)
            return registry
        } catch let error as DecodingError {
            throw TemplateRegistryError.decodingFailed(error)
        } catch {
            throw TemplateRegistryError.ioError("Failed to read registry file: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Registry

    public func saveRegistry(_ registry: TemplateRegistry) async throws {
        let filePath = registryFilePath

        do {
            let data = try encoder.encode(registry)
            try data.write(to: filePath, options: .atomic)
        } catch let error as EncodingError {
            throw TemplateRegistryError.encodingFailed(error)
        } catch {
            throw TemplateRegistryError.ioError("Failed to write registry file: \(error.localizedDescription)")
        }
    }

    // MARK: - Add Template

    public func addTemplate(_ entry: TemplateEntry) async throws {
        var registry = try await loadRegistry()

        // Check for duplicates
        if registry.entries.contains(where: { $0.id == entry.id }) {
            throw TemplateRegistryError.templateAlreadyExists(entry.id)
        }

        // Add entry
        registry.addEntry(entry)

        try await saveRegistry(registry)
    }

    // MARK: - Upsert Template

    public func upsertTemplate(_ entry: TemplateEntry) async throws {
        var registry = try await loadRegistry()

        // A new entry goes last, so templates keep the order in which they were installed
        if !registry.updateEntry(entry) {
            registry.addEntry(entry)
        }

        try await saveRegistry(registry)
    }

    // MARK: - Remove Template

    public func removeTemplate(id: String) async throws {
        var registry = try await loadRegistry()

        // Check if template exists and remove
        guard registry.removeEntry(id: id) else {
            throw TemplateRegistryError.templateNotFound(id)
        }

        try await saveRegistry(registry)
    }

    // MARK: - Get Template

    public func getTemplate(id: String) async throws -> TemplateEntry? {
        let registry = try await loadRegistry()
        return registry.findEntry(id: id)
    }

    // MARK: - Get All Templates

    public func getAllTemplates() async throws -> [TemplateEntry] {
        let registry = try await loadRegistry()
        return registry.entries
    }

    // MARK: - Refresh Registry

    /// Refreshes the registry by rescanning directories
    /// In this basic implementation, it just returns the current registry
    /// Future implementations can scan bundled resources and user directories
    public func refreshRegistry() async throws -> TemplateRegistry {
        // For now, just return the current registry
        // Future enhancement: Scan directories and rebuild registry
        return try await loadRegistry()
    }

    // MARK: - Preview Files

    /// Name of the cached preview file of a template, inside the storage directory
    public nonisolated func previewFileName(forTemplateId templateId: String) -> String {
        "\(templateId)_preview.png"
    }

    /// Location of the cached preview image an entry points to
    public nonisolated func previewURL(for entry: TemplateEntry) -> URL {
        storageDirectory.appendingPathComponent(entry.previewPath)
    }

    // MARK: - Extract Preview

    public func extractPreview(from base64: String, templateId: String) async throws -> URL {
        // Decode base64 string
        guard let imageData = Data(base64Encoded: base64) else {
            throw TemplateRegistryError.invalidPreviewData
        }

        // Validate PNG signature (first 8 bytes: 89 50 4E 47 0D 0A 1A 0A)
        guard imageData.count > 8 else {
            throw TemplateRegistryError.invalidPreviewData
        }

        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let headerBytes = Array(imageData.prefix(8))
        guard headerBytes == pngSignature else {
            throw TemplateRegistryError.previewExtractionFailed("Not a valid PNG image")
        }

        // Create preview file path
        let previewPath = storageDirectory.appendingPathComponent(previewFileName(forTemplateId: templateId))

        // Write PNG data to file
        do {
            try imageData.write(to: previewPath, options: .atomic)
            return previewPath
        } catch {
            throw TemplateRegistryError.previewExtractionFailed("Failed to write preview file: \(error.localizedDescription)")
        }
    }
}
