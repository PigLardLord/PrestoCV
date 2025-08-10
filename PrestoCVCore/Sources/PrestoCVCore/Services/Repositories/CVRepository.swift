import Foundation

// MARK: - CV Repository Implementation

public final class CVRepository: CVRepositoryProtocol, Sendable {
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