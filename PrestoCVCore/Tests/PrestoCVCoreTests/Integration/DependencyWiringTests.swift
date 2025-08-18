import Testing
import Foundation
@testable import PrestoCVCore

@Suite("Dependency Wiring Tests")
struct DependencyWiringTests {
    
    @Test("Wiring: OnboardingUseCase returns firstTime state when no CVs exist")
    func onboardingUseCaseIsProperlyWired() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        let useCase = try container.makeOnboardingUseCase()
        
        // Test that the use case can perform its basic operations without errors
        let onboardingState = await useCase.checkOnboardingRequired()
        // Should be .firstTime since no CVs exist in clean mock storage
        #expect(onboardingState == .firstTime)
    }
    
    @Test("Wiring: CVManagementUseCase returns empty CV list when storage is clean")
    func cvManagementUseCaseIsProperlyWired() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        let useCase = try container.makeCVManagementUseCase()
        
        // Test that the use case can perform basic operations without crashing
        let cvs = try await useCase.getAllCVs()
        // Should be empty initially with clean mock storage
        #expect(cvs.count == 0)
    }
    
    @Test("Container maintains consistent service instances")
    func containerMaintainsConsistentServiceInstances() async throws {
        let container = TestDependencyContainer()
        defer { container.reset() }
        
        // Create multiple use cases
        let onboardingUseCase1 = try container.makeOnboardingUseCase()
        let onboardingUseCase2 = try container.makeOnboardingUseCase()
        let cvManagementUseCase1 = try container.makeCVManagementUseCase()
        let cvManagementUseCase2 = try container.makeCVManagementUseCase()
        
        // Test that they share the same underlying repositories by checking behavior consistency
        // Both onboarding use cases should return the same state
        let state1 = await onboardingUseCase1.checkOnboardingRequired()
        let state2 = await onboardingUseCase2.checkOnboardingRequired()
        #expect(state1 == state2)
        #expect(state1 == .firstTime) // Should be firstTime with empty mock storage
        
        // Both CV management use cases should return the same CV count
        let cvs1 = try await cvManagementUseCase1.getAllCVs()
        let cvs2 = try await cvManagementUseCase2.getAllCVs()
        #expect(cvs1.count == cvs2.count)
        #expect(cvs1.count == 0) // Should be 0 with empty mock storage
    }
}