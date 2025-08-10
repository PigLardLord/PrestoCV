import Testing
import Foundation
@testable import PrestoCVCore

/// A test dependency container that uses mocked services
public final class TestDependencyContainer: DependencyContainerProtocol, @unchecked Sendable {
    private let mockStorageService = MockStorageService()
    
    private lazy var cvRepository: CVRepositoryProtocol = {
        return CVRepository(storageService: mockStorageService)
    }()
    
    private lazy var templateRepository: TemplateRepositoryProtocol = {
        return TemplateRepository(storageService: mockStorageService)
    }()
    
    private lazy var onboardingRepository: OnboardingRepositoryProtocol = {
        return OnboardingRepository(cvRepository: cvRepository)
    }()
    
    public func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol {
        return OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            templateRepository: templateRepository,
            cvRepository: cvRepository
        )
    }
    
    public func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
        return CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
    }
    
    // Test helper method to reset state
    public func reset() {
        mockStorageService.clear()
    }
}