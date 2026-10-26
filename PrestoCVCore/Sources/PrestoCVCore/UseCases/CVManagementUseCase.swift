import Foundation

// MARK: - Localization Helper

private extension String {
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }
    
    func localizedWithArgs(_ arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

// MARK: - CV Management Use Case Implementation

public final class CVManagementUseCase: CVManagementUseCaseProtocol, Sendable {
    private let cvRepository: CVRepositoryProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(
        cvRepository: CVRepositoryProtocol,
        sampleRepository: SampleCVRepositoryProtocol
    ) {
        self.cvRepository = cvRepository
        self.sampleRepository = sampleRepository
    }
    
    // MARK: - Public Protocol Implementation
    
    public func getAllCVs() async throws -> [CVModel] {
        return try await cvRepository.getAllCVs()
    }
    
    public func getCVListing() async throws -> CVListing {
        return try await cvRepository.getCVListing()
    }
    
    public func acknowledgeUnreadableCVs() async throws {
        try await cvRepository.acknowledgeUnreadableCVs()
    }
    
    public func createCV(from template: CVModel) async throws -> CVModel {
        // Create a new CV with a new ID based on the template
        let newCV = template.copy()
        return try await cvRepository.saveCV(newCV)
    }
    
    public func storeNewCV(_ cv: CVModel) async throws -> CVModel {
        return try await cvRepository.saveCV(cv)
    }
    
    public func updateCV(_ cv: CVModel) async throws -> CVModel {
        return try await cvRepository.saveCV(cv)
    }
    
    public func deleteCV(id: UUID) async throws {
        try await cvRepository.deleteCV(id: id)
    }
    
    public func duplicateCV(id: UUID, named name: String) async throws -> CVModel {
        guard let existingCV = try await cvRepository.getCV(by: id) else {
            throw AppError.notFound("error.subject.cv".localized)
        }
        
        let duplicatedCV = existingCV.copy(nameModifier: { _ in name })
        
        return try await cvRepository.saveCV(duplicatedCV)
    }
    
    public func getCV(by id: UUID) async throws -> CVModel? {
        return try await cvRepository.getCV(by: id)
    }
}
