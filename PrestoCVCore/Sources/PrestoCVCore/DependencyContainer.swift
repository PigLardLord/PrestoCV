import Foundation

// MARK: - Dependency Errors

public enum DependencyError: Error, LocalizedError {
    case serviceCreationFailed(String, Error)
    
    public var errorDescription: String? {
        switch self {
        case .serviceCreationFailed(let serviceName, let underlyingError):
            return "Failed to create \(serviceName): \(underlyingError.localizedDescription)"
        }
    }
}

// MARK: - Dependency Container Implementation

public final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Service Creation Results
    private lazy var storageServiceResult: Result<StorageServiceProtocol, Error> = {
        do {
            // Get iOS Documents directory for CV storage
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cvDirectory = documentsPath.appendingPathComponent("CVs")
            let service = try FileStorageService(baseDirectory: cvDirectory)
            return .success(service)
        } catch {
            return .failure(error)
        }
    }()
    
    // MARK: - Service Factory Methods
    private func getStorageService() throws -> StorageServiceProtocol {
        switch storageServiceResult {
        case .success(let service):
            return service
        case .failure(let error):
            throw DependencyError.serviceCreationFailed("StorageService", error)
        }
    }
    
    private func getCVRepository() throws -> CVRepositoryProtocol {
        let storage = try getStorageService()
        return CVRepository(storageService: storage)
    }
    
    private func getTemplateRepository() throws -> TemplateRepositoryProtocol {
        let storage = try getStorageService()
        return TemplateRepository(storageService: storage)
    }
    
    private func getOnboardingRepository() throws -> OnboardingRepositoryProtocol {
        let cvRepo = try getCVRepository()
        return OnboardingRepository(cvRepository: cvRepo)
    }
    
    // MARK: - Public Initializer
    public init() {}
    
    // MARK: - Use Case Factory Methods
    public func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol {
        return OnboardingUseCase(
            onboardingRepository: try getOnboardingRepository(),
            templateRepository: try getTemplateRepository(),
            cvManagementUseCase: try makeCVManagementUseCase()
        )
    }
    
    public func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
        return CVManagementUseCase(
            cvRepository: try getCVRepository(),
            templateRepository: try getTemplateRepository()
        )
    }
    
    public func makeTemplateRepository() throws -> TemplateRepositoryProtocol {
        return try getTemplateRepository()
    }
}