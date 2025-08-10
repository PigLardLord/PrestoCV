import Foundation

public final class OnboardingUseCase: OnboardingUseCaseProtocol, Sendable {
    private let onboardingRepository: OnboardingRepositoryProtocol
    private let templateRepository: TemplateRepositoryProtocol
    private let cvRepository: CVRepositoryProtocol
    
    public init(
        onboardingRepository: OnboardingRepositoryProtocol,
        templateRepository: TemplateRepositoryProtocol,
        cvRepository: CVRepositoryProtocol
    ) {
        self.onboardingRepository = onboardingRepository
        self.templateRepository = templateRepository
        self.cvRepository = cvRepository
    }
    
    public func checkOnboardingRequired() async -> OnboardingState {
        return await onboardingRepository.getOnboardingState()
    }
    
    public func createFirstCV(from template: CVModel) async throws -> CVModel {
        let newCV = CVModel(from: template)
        return try await cvRepository.saveCV(newCV)
    }
}