import Foundation

// MARK: - CV Repository Implementation

public final class CVRepository: CVRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let parallelSearchService = ParallelSearchService()
    
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
        
        // Delegate parallel search to dedicated service
        return try await parallelSearchService.findFirst(
            in: identifiers,
            loader: loadCVFromIdentifier,
            matcher: createCVIdMatcher(for: id)
        )
    }
    
    /// Loads a CV model from a storage identifier
    /// - Parameter identifier: The storage identifier to load from
    /// - Returns: The CV model if found and valid, nil otherwise
    private func loadCVFromIdentifier(_ identifier: String) async throws -> CVModel? {
        return try await storageService.load(CVModel.self, from: identifier)
    }
    
    /// Creates a matcher function that checks if a CV has the specified ID
    /// - Parameter targetId: The UUID to match against
    /// - Returns: A function that returns true if the CV's ID matches the target
    private func createCVIdMatcher(for targetId: UUID) -> @Sendable (CVModel) -> Bool {
        return { cv in
            cv.id == targetId
        }
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
        return !(await isEmpty())
    }
    
    private func isEmpty() async -> Bool {
        let cvs = try? await getAllCVs()
        return cvs?.isEmpty ?? true
    }
    
    public func getCVsCount() async -> Int {
        let cvs = try? await getAllCVs()
        return cvs?.count ?? 0
    }
}