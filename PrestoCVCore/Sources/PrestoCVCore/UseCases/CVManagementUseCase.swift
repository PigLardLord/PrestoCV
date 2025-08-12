import Foundation

// MARK: - CV Management Use Case Implementation

public final class CVManagementUseCase: CVManagementUseCaseProtocol, Sendable {
    private let cvRepository: CVRepositoryProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    
    public init(
        cvRepository: CVRepositoryProtocol,
        sampleRepository: SampleCVRepositoryProtocol
    ) {
        self.cvRepository = cvRepository
        self.sampleRepository = sampleRepository
    }
    
    public func getAllCVs() async throws -> [CVModel] {
        return try await cvRepository.getAllCVs()
    }
    
    public func createCV(from template: CVModel) async throws -> CVModel {
        // Create a new CV with a new ID based on the template
        let newCV = template.copy()
        return try await cvRepository.saveCV(newCV)
    }
    
    public func updateCV(_ cv: CVModel) async throws -> CVModel {
        return try await cvRepository.saveCV(cv)
    }
    
    public func deleteCV(id: UUID) async throws {
        try await cvRepository.deleteCV(id: id)
    }
    
    public func duplicateCV(id: UUID) async throws -> CVModel {
        guard let existingCV = try await cvRepository.getCV(by: id) else {
            throw AppError.notFound("CV with id \(id)")
        }
        
        // Create a copy with a new ID and modified name
        let duplicatedCV = existingCV.copy(nameModifier: { name in
            if name.isEmpty {
                return "Copy"
            } else {
                return "\(name) (Copy)"
            }
        })
        
        return try await cvRepository.saveCV(duplicatedCV)
    }
    
    public func getCV(by id: UUID) async throws -> CVModel? {
        return try await cvRepository.getCV(by: id)
    }
}