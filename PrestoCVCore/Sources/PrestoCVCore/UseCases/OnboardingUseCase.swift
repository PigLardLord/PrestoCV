import Foundation

// MARK: - Onboarding Use Case Implementation

public final class OnboardingUseCase: OnboardingUseCaseProtocol, Sendable {
    private let onboardingRepository: OnboardingRepositoryProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    
    public init(
        onboardingRepository: OnboardingRepositoryProtocol,
        sampleRepository: SampleCVRepositoryProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol
    ) {
        self.onboardingRepository = onboardingRepository
        self.sampleRepository = sampleRepository
        self.cvManagementUseCase = cvManagementUseCase
    }
    
    public func checkOnboardingRequired() async -> OnboardingState {
        let hasExistingCVs = await onboardingRepository.hasExistingCVs()
        let onboardingState = await onboardingRepository.getOnboardingState()
        
        // If user has existing CVs, they're returning
        if hasExistingCVs {
            return .returning
        }
        
        // Otherwise, return the actual onboarding state
        return onboardingState
    }
    
    public func createFirstCV(from template: CVModel) async throws -> CVModel {
        return try await cvManagementUseCase.createCV(from: template)
    }
}