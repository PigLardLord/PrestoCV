import Foundation

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
        return await onboardingRepository.getOnboardingState()
    }
    
    public func createFirstCV(from template: CVModel) async throws -> CVModel {
        return try await cvManagementUseCase.createCV(from: template)
    }
}