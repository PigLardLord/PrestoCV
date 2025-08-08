import Foundation

// MARK: - Cross-Platform Storage Service

public final class FileStorageService: StorageServiceProtocol {
    private let fileManager: FileManager
    private let baseDirectory: URL
    
    public init(fileManager: FileManager = .default, baseDirectory: URL) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        
        // Ensure the base directory exists
        try? fileManager.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }
    
    public func save<T: Codable>(_ object: T, to identifier: String) async throws {
        let url = baseDirectory.appendingPathComponent("\(identifier).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(object)
        try data.write(to: url)
    }
    
    public func load<T: Codable>(_ type: T.Type, from identifier: String) async throws -> T? {
        let url = baseDirectory.appendingPathComponent("\(identifier).json")
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: data)
    }
    
    public func loadAll<T: Codable>(_ type: T.Type) async throws -> [T] {
        let urls = try getAllFileURLs()
        var objects: [T] = []
        
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let object = try decoder.decode(type, from: data)
                objects.append(object)
            } catch {
                // Skip invalid files but continue loading others
                print("Warning: Could not load file at \(url): \(error)")
                continue
            }
        }
        
        return objects
    }
    
    public func delete(identifier: String) async throws {
        let url = baseDirectory.appendingPathComponent("\(identifier).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    public func exists(identifier: String) async -> Bool {
        let url = baseDirectory.appendingPathComponent("\(identifier).json")
        return fileManager.fileExists(atPath: url.path)
    }
    
    public func getAllIdentifiers() async throws -> [String] {
        let urls = try getAllFileURLs()
        return urls.compactMap { url in
            let filename = url.lastPathComponent
            return filename.hasSuffix(".json") ? String(filename.dropLast(5)) : nil
        }
    }
    
    // MARK: - Private Methods
    
    private func getAllFileURLs() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension == "json" }
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
    
    public func getCV(by id: UUID) async throws -> CVModel? {
        let identifiers = try await storageService.getAllIdentifiers()
        
        // Try to find CV by loading each one and checking ID
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