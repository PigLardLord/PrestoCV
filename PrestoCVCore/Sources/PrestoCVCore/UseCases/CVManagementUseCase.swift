import Foundation

public final class CVManagementUseCase: CVManagementUseCaseProtocol, Sendable {
    private let cvRepository: CVRepositoryProtocol
    private let templateRepository: TemplateRepositoryProtocol
    
    public init(
        cvRepository: CVRepositoryProtocol,
        templateRepository: TemplateRepositoryProtocol
    ) {
        self.cvRepository = cvRepository
        self.templateRepository = templateRepository
    }
    
    public func getAllCVs() async throws -> [CVModel] {
        return try await cvRepository.getAllCVs()
    }
    
    public func createCV(from template: CVModel) async throws -> CVModel {
        let newCV = CVModel(from: template)
        return try await cvRepository.saveCV(newCV)
    }
    
    public func updateCV(_ cv: CVModel) async throws -> CVModel {
        return try await cvRepository.saveCV(cv)
    }
    
    public func deleteCV(id: UUID) async throws {
        try await cvRepository.deleteCV(id: id)
    }
    
    public func duplicateCV(id: UUID) async throws -> CVModel {
        guard let originalCV = try await cvRepository.getCV(by: id) else {
            throw AppError.invalidCVData
        }
        
        let duplicatedCV = originalCV.copy { "\($0) (Copy)" }
        
        return try await cvRepository.saveCV(duplicatedCV)
    }
}