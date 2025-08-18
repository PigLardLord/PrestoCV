import Foundation

// MARK: - Cross-Platform Storage Service

public actor FileStorageService: StorageServiceProtocol{
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let fileExtension = "json"
    private let parallelSearchService = ParallelSearchService()
    
    /// Creates a new FileStorageService instance
    /// - Parameters:
    ///   - fileManager: The file manager to use for file operations
    ///   - baseDirectory: The directory where files will be stored
    /// - Throws: An error if the base directory cannot be created
    public init(fileManager: FileManager = .default, baseDirectory: URL) throws {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        
        // Create directory synchronously since init must be synchronous
        // and this is a one-time setup operation
        guard !fileManager.fileExists(atPath: baseDirectory.path) else { return }
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    public func save<T: Codable & Sendable>(_ object: T, to identifier: String) async throws {
        let url = fileURL(for: identifier)
        let encoder = configuredJSONEncoder()
        
        let data = try encoder.encode(object)
        try data.write(to: url)
    }
    
    public func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T? {
        let url = fileURL(for: identifier)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = configuredJSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    /// Loads all objects of the specified type from storage
    /// - Parameter type: The type of objects to load
    /// - Returns: An array of successfully loaded objects
    /// - Throws: Storage error if directory cannot be read
    /// - Note: Invalid files are silently skipped to ensure partial success
    public func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T] {
        let urls = try getStoredFileURLs()
        return await loadObjectsFromURLs(urls, type: type)
    }
    
    public func delete(identifier: String) async throws {
        let url = fileURL(for: identifier)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return // File doesn't exist, nothing to delete
        }
        
        try fileManager.removeItem(at: url)
    }
    
    public func exists(identifier: String) async -> Bool {
        let url = fileURL(for: identifier)
        return fileManager.fileExists(atPath: url.path)
    }
    
    public func getAllIdentifiers() async throws -> [String] {
        let urls = try getStoredFileURLs()
        return extractIdentifiersFromURLs(urls)
    }
    
    // MARK: - Private Methods
    
    /// Loads objects from URLs in parallel, silently skipping invalid files
    /// - Parameters:
    ///   - urls: Array of file URLs to load from
    ///   - type: The type of objects to decode
    /// - Returns: Array of successfully loaded objects
    private func loadObjectsFromURLs<T: Codable & Sendable>(_ urls: [URL], type: T.Type) async -> [T] {
        do {
            return try await parallelSearchService.findAll(
                in: urls,
                loader: createObjectLoader(for: type)
            )
        } catch {
            // If parallel loading fails, fallback to empty array
            // In production, this should be logged
            return []
        }
    }
    
    /// Creates a loader function for the specified object type
    /// - Parameter type: The type of objects to load
    /// - Returns: A loader function that safely loads objects from URLs
    private func createObjectLoader<T: Codable & Sendable>(for type: T.Type) -> @Sendable (URL) async throws -> T? {
        return { [self] url in
            await self.loadObjectSafely(from: url, type: type)
        }
    }
    
    /// Safely loads a single object from a URL, returning nil on failure
    /// - Parameters:
    ///   - url: File URL to load from
    ///   - type: The type of object to decode
    /// - Returns: Decoded object or nil if loading/decoding fails
    private func loadObjectSafely<T: Codable & Sendable>(
        from url: URL,
        type: T.Type
    ) async -> T? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = configuredJSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            // Skip invalid files but continue loading others
            // In a production app, this could log to a proper logging system
            return nil
        }
    }
    
    /// Extracts identifiers from file URLs by removing the file extension
    /// - Parameter urls: Array of file URLs to process
    /// - Returns: Array of identifiers (filenames without extension)
    private func extractIdentifiersFromURLs(_ urls: [URL]) -> [String] {
        return urls.compactMap(extractIdentifierFromURL)
    }
    
    /// Extracts identifier from a single URL if it matches the expected file extension
    /// - Parameter url: File URL to process
    /// - Returns: Identifier (filename without extension) or nil if invalid
    private func extractIdentifierFromURL(_ url: URL) -> String? {
        let filename = url.lastPathComponent
        let expectedSuffix = ".\(fileExtension)"
        
        guard filename.hasSuffix(expectedSuffix) else {
            return nil
        }
        
        return String(filename.dropLast(expectedSuffix.count))
    }
    
    private func configuredJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private func configuredJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    private func fileURL(for identifier: String) -> URL {
        return baseDirectory.appendingPathComponent("\(identifier).\(fileExtension)")
    }
    
    private func getStoredFileURLs() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension == fileExtension }
    }
}
