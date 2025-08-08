import Foundation

// MARK: - Dependency Container Implementation

public final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Singleton Services
    private lazy var storageService: StorageServiceProtocol = {
        // Get iOS Documents directory for CV storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cvDirectory = documentsPath.appendingPathComponent("CVs")
        return FileStorageService(baseDirectory: cvDirectory)
    }()
    
    private lazy var cvRepository: CVRepositoryProtocol = {
        return CVRepository(storageService: storageService)
    }()
    
    private lazy var templateRepository: TemplateRepositoryProtocol = {
        return TemplateRepository(storageService: storageService)
    }()
    
    private lazy var onboardingRepository: OnboardingRepositoryProtocol = {
        return OnboardingRepository(cvRepository: cvRepository)
    }()
    
    // MARK: - Public Initializer
    public init() {}
    
    // MARK: - Use Case Factory Methods
    public func makeOnboardingUseCase() -> OnboardingUseCaseProtocol {
        return OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            templateRepository: templateRepository,
            cvRepository: cvRepository
        )
    }
    
    public func makeCVManagementUseCase() -> CVManagementUseCaseProtocol {
        return CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
    }
}