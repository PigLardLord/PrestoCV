import Testing
import Foundation
@testable import PrestoCVCore

/// A test dependency container that uses mocked services
public final class TestDependencyContainer: DependencyContainerProtocol, @unchecked Sendable {
    private let mockStorageService = MockStorageService()
    private let mockParallelSearchService = MockParallelSearchService()
    private let mockBundleResourceService = MockBundleResourceService()
    private let mockJSONTemplateLoader = MockJSONTemplateLoader()
    private let mockCategoryService = TemplateCategoryService()
    
    private lazy var cvRepository: CVRepositoryProtocol = {
        return CVRepository(storageService: mockStorageService)
    }()
    
    private lazy var sampleRepository: SampleCVRepositoryProtocol = {
        return SampleCVRepository(
            storageService: mockStorageService,
            categoryService: mockCategoryService,
            bundleResourceService: mockBundleResourceService,
            templateLoader: mockJSONTemplateLoader,
            parallelSearchService: mockParallelSearchService
        )
    }()
    
    private lazy var onboardingRepository: OnboardingRepositoryProtocol = {
        return OnboardingRepository(cvRepository: cvRepository)
    }()
    
    public func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol {
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        return OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
    }
    
    public func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
        return CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
    }
    
    public func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol {
        return sampleRepository
    }
    
    public func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol {
        return TemplateCategoryService()
    }
    
    // Test helper method to reset state
    public func reset() {
        mockStorageService.clear()
    }
}