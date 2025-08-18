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
    
    // MARK: - Private Methods
    
    private func getCVRepository() throws -> CVRepositoryProtocol {
        let storageService = try getStorageService()
        let parallelSearchService = getParallelSearchService()
        return CVRepository(
            storageService: storageService,
            parallelSearchService: parallelSearchService
        )
    }
    
    private func getOnboardingRepository() throws -> OnboardingRepositoryProtocol {
        let cvRepository = try getCVRepository()
        return OnboardingRepository(cvRepository: cvRepository)
    }
    
    private func getSampleRepository() throws -> SampleCVRepositoryProtocol {
        let storageService = try getStorageService()
        let categoryService = getTemplateCategoryService()
        let bundleResourceService = getBundleResourceService()
        let templateLoader = getJSONTemplateLoader()
        let parallelSearchService = getParallelSearchService()
        return SampleCVRepository(
            storageService: storageService,
            categoryService: categoryService,
            bundleResourceService: bundleResourceService,
            templateLoader: templateLoader,
            parallelSearchService: parallelSearchService
        )
    }
    
    private func getTemplateCategoryService() -> TemplateCategoryServiceProtocol {
        return TemplateCategoryService()
    }
    
    private func getParallelSearchService() -> ParallelSearchServiceProtocol {
        return ParallelSearchService()
    }
    
    private func getBundleResourceService() -> BundleResourceServiceProtocol {
        return BundleResourceService()
    }
    
    private func getJSONTemplateLoader() -> JSONTemplateLoaderProtocol {
        return JSONTemplateLoader()
    }
    
    // MARK: - Public Methods
    
    public init() {}
    
    public func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol {
        let onboardingRepo = try getOnboardingRepository()
        let sampleRepo = try getSampleRepository()
        let cvManagementUseCase = try makeCVManagementUseCase()
        return OnboardingUseCase(
            onboardingRepository: onboardingRepo,
            sampleRepository: sampleRepo,
            cvManagementUseCase: cvManagementUseCase
        )
    }
    
    public func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
        let cvRepo = try getCVRepository()
        let sampleRepo = try getSampleRepository()
        return CVManagementUseCase(
            cvRepository: cvRepo,
            sampleRepository: sampleRepo
        )
    }
    
    public func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol {
        return try getSampleRepository()
    }
    
    public func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol {
        return TemplateCategoryService()
    }
}