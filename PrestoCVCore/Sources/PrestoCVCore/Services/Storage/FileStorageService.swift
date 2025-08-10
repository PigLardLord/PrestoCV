import Foundation

// MARK: - Cross-Platform Storage Service

public actor FileStorageService: StorageServiceProtocol{
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let fileExtension = "json"
    
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
        var objects: [T] = []
        let decoder = configuredJSONDecoder()
        
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let object = try decoder.decode(type, from: data)
                objects.append(object)
            } catch {
                // Skip invalid files but continue loading others
                // In a production app, this could log to a proper logging system
                continue
            }
        }
        
        return objects
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
        return urls.compactMap { url in
            let filename = url.lastPathComponent
            return filename.hasSuffix(".\(fileExtension)") 
                ? String(filename.dropLast(fileExtension.count + 1)) 
                : nil
        }
    }
    
    // MARK: - Private Methods
    
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
