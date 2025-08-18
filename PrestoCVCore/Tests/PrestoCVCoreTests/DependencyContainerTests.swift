import Testing
import Foundation
@testable import PrestoCVCore

@Suite("DependencyContainer Tests")
struct DependencyContainerTests {
    
    // MARK: - Container Initialization Tests
    
    @Test("DependencyContainer initializes without errors")
    func containerInitialization() {
        let container = DependencyContainer()
        #expect(type(of: container) == DependencyContainer.self)
    }
    
    @Test("TestDependencyContainer initializes without errors")
    func testContainerInitialization() {
        let container = TestDependencyContainer()
        #expect(type(of: container) == TestDependencyContainer.self)
    }
    
    // MARK: - Factory Method Tests
    
    @Test("makeOnboardingUseCase returns OnboardingUseCase instance")
    func makeOnboardingUseCaseReturnsCorrectType() throws {
        let container = TestDependencyContainer()
        let useCase = try container.makeOnboardingUseCase()
        
        #expect(useCase is OnboardingUseCase)
        #expect(type(of: useCase) == OnboardingUseCase.self)
    }
    
    @Test("makeCVManagementUseCase returns CVManagementUseCase instance")
    func makeCVManagementUseCaseReturnsCorrectType() throws {
        let container = TestDependencyContainer()
        let useCase = try container.makeCVManagementUseCase()
        
        #expect(useCase is CVManagementUseCase)
        #expect(type(of: useCase) == CVManagementUseCase.self)
    }
    
    // MARK: - Protocol Conformance Tests
    
    @Test("DependencyContainer conforms to DependencyContainerProtocol")
    func containerConformsToProtocol() throws {
        let container: DependencyContainerProtocol = TestDependencyContainer()
        
        // Test that protocol methods are accessible and return valid instances
        let onboardingUseCase = try container.makeOnboardingUseCase()
        let cvManagementUseCase = try container.makeCVManagementUseCase()
        
        // Verify the factory methods return concrete instances by checking they're not nil
        let onboardingUseCaseName = String(describing: type(of: onboardingUseCase))
        let cvManagementUseCaseName = String(describing: type(of: cvManagementUseCase))
        
        #expect(onboardingUseCaseName.contains("OnboardingUseCase"))
        #expect(cvManagementUseCaseName.contains("CVManagementUseCase"))
    }
    
    // MARK: - Real DependencyContainer Tests
    
    @Test("Real DependencyContainer creates OnboardingUseCase successfully")
    func realContainerCreatesOnboardingUseCase() throws {
        let container = DependencyContainer()
        let useCase = try container.makeOnboardingUseCase()
        
        #expect(useCase is OnboardingUseCase)
    }
    
    @Test("Real DependencyContainer creates CVManagementUseCase successfully")  
    func realContainerCreatesCVManagementUseCase() throws {
        let container = DependencyContainer()
        let useCase = try container.makeCVManagementUseCase()
        
        #expect(useCase is CVManagementUseCase)
    }
    
    @Test("Real DependencyContainer creates SampleCVRepository successfully")
    func realContainerCreatesSampleCVRepository() throws {
        let container = DependencyContainer()
        let repository = try container.makeSampleCVRepository()
        
        #expect(repository is SampleCVRepository)
    }
    
    @Test("Real DependencyContainer creates TemplateCategoryService successfully")
    func realContainerCreatesTemplateCategoryService() throws {
        let container = DependencyContainer()
        let service = try container.makeTemplateCategoryService()
        
        #expect(service is TemplateCategoryService)
    }
    
    @Test("Real DependencyContainer maintains service consistency")
    func realContainerMaintainsServiceConsistency() throws {
        let container = DependencyContainer()
        
        // Create multiple instances to verify they work consistently
        let useCase1 = try container.makeOnboardingUseCase()
        let useCase2 = try container.makeCVManagementUseCase()
        let repository = try container.makeSampleCVRepository()
        let service = try container.makeTemplateCategoryService()
        
        // Verify all instances are created successfully
        #expect(useCase1 is OnboardingUseCase)
        #expect(useCase2 is CVManagementUseCase)
        #expect(repository is SampleCVRepository)
        #expect(service is TemplateCategoryService)
    }
}