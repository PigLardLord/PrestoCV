import Foundation

public final class CVManagementUseCase: CVManagementUseCaseProtocol {
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
        let newCV = CVModel(
            id: UUID(),
            name: template.name,
            title: template.title,
            location: template.location,
            email: template.email,
            phone: template.phone,
            portfolio: template.portfolio,
            profile: template.profile,
            relevant_experience: template.relevant_experience,
            education: template.education,
            skills: template.skills,
            languages: template.languages,
            certifications: template.certifications,
            interests: template.interests,
            social: template.social
        )
        
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
        
        let duplicatedCV = CVModel(
            id: UUID(),
            name: "\(originalCV.name) (Copy)",
            title: originalCV.title,
            location: originalCV.location,
            email: originalCV.email,
            phone: originalCV.phone,
            portfolio: originalCV.portfolio,
            profile: originalCV.profile,
            relevant_experience: originalCV.relevant_experience,
            education: originalCV.education,
            skills: originalCV.skills,
            languages: originalCV.languages,
            certifications: originalCV.certifications,
            interests: originalCV.interests,
            social: originalCV.social
        )
        
        return try await cvRepository.saveCV(duplicatedCV)
    }
}