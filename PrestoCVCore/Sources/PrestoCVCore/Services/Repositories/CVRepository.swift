import Foundation

// MARK: - CV Repository Implementation

public final class CVRepository: CVRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let parallelSearchService: ParallelSearchServiceProtocol
    
    public init(
        storageService: StorageServiceProtocol,
        parallelSearchService: ParallelSearchServiceProtocol
    ) {
        self.storageService = storageService
        self.parallelSearchService = parallelSearchService
    }
    
    public func getAllCVs() async throws -> [CVModel] {
        return try await storageService.loadAll(CVModel.self)
    }
    
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
    
    private func loadCVFromIdentifier(_ identifier: String) async throws -> CVModel? {
        return try await storageService.load(CVModel.self, from: identifier)
    }
    
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