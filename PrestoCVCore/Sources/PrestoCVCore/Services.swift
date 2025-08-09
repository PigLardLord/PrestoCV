import Foundation

// MARK: - Cross-Platform Storage Service

public final class FileStorageService: StorageServiceProtocol {
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
        
        try createBaseDirectoryIfNeeded()
    }
    
    // MARK: - Private Configuration
    
    private func createBaseDirectoryIfNeeded() throws {
        guard !fileManager.fileExists(atPath: baseDirectory.path) else { return }
        
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
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
    
    public func save<T: Codable>(_ object: T, to identifier: String) async throws {
        let url = fileURL(for: identifier)
        let encoder = configuredJSONEncoder()
        
        let data = try encoder.encode(object)
        try data.write(to: url)
    }
    
    public func load<T: Codable>(_ type: T.Type, from identifier: String) async throws -> T? {
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
    public func loadAll<T: Codable>(_ type: T.Type) async throws -> [T] {
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
    
    private func getStoredFileURLs() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension == fileExtension }
    }
    
}

// MARK: - CV Repository Implementation

public final class CVRepository: CVRepositoryProtocol {
    private let storageService: StorageServiceProtocol
    
    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    public func getAllCVs() async throws -> [CVModel] {
        return try await storageService.loadAll(CVModel.self)
    }
    
    /// Retrieves a CV by its unique identifier
    /// - Parameter id: The UUID of the CV to retrieve
    /// - Returns: The CV if found, nil otherwise
    /// - Throws: Storage errors during the search process
    /// - Note: First attempts to load using a standard identifier pattern before falling back to full search
    public func getCV(by id: UUID) async throws -> CVModel? {
        // First try the standard identifier pattern for efficiency
        let standardIdentifier = "cv_\(id.uuidString)"
        if let cv = try await storageService.load(CVModel.self, from: standardIdentifier) {
            return cv
        }
        
        // Fall back to searching all identifiers if standard pattern doesn't work
        // This handles legacy data or non-standard naming
        let identifiers = try await storageService.getAllIdentifiers()
        
        for identifier in identifiers {
            if let cv = try await storageService.load(CVModel.self, from: identifier) {
                if cv.id == id {
                    return cv
                }
            }
        }
        return nil
    }
    
    public func saveCV(_ cv: CVModel) async throws -> CVModel {
        let identifier = "cv_\(cv.id.uuidString)"
        try await storageService.save(cv, to: identifier)
        return cv
    }
    
    public func deleteCV(id: UUID) async throws {
        let identifier = "cv_\(id.uuidString)"
        try await storageService.delete(identifier: identifier)
    }
    
    public func cvExists() async -> Bool {
        do {
            let cvs = try await getAllCVs()
            return !cvs.isEmpty
        } catch {
            return false
        }
    }
    
    public func getCVsCount() async -> Int {
        do {
            let cvs = try await getAllCVs()
            return cvs.count
        } catch {
            return 0
        }
    }
}

// MARK: - Onboarding Repository Implementation

public final class OnboardingRepository: OnboardingRepositoryProtocol {
    private let cvRepository: CVRepositoryProtocol
    
    public init(cvRepository: CVRepositoryProtocol) {
        self.cvRepository = cvRepository
    }
    
    public func hasExistingCVs() async -> Bool {
        return await cvRepository.cvExists()
    }
    
    public func getOnboardingState() async -> OnboardingState {
        let hasExistingCVs = await self.hasExistingCVs()
        return hasExistingCVs ? .returning : .firstTime
    }
}

// MARK: - Template Repository Implementation

public final class TemplateRepository: TemplateRepositoryProtocol {
    private let storageService: StorageServiceProtocol
    
    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    public func getDefaultTemplate() async throws -> CVModel {
        // Return a default empty CV template
        return CVModel()
    }
    
    public func getAllTemplates() async throws -> [CVModel] {
        // For now, just return the default template
        // Later this could load templates from bundle or remote
        return [try await getDefaultTemplate()]
    }
    
    public func getTemplate(by name: String) async throws -> CVModel? {
        if name == "default" {
            return try await getDefaultTemplate()
        }
        return nil
    }
}