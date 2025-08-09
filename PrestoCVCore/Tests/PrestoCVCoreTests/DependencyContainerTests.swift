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
}