import Foundation

public final class OnboardingUseCase: OnboardingUseCaseProtocol, @unchecked Sendable {
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
        let newCV = CVModel(
            id: UUID(),
            name: template.name,
            title: template.title,
            location: template.location,
            email: template.email,
            phone: template.phone,
            portfolio: template.portfolio,
            profile: template.profile,
            relevant_experience: template.relevant_experience,
            education: template.education,
            skills: template.skills,
            languages: template.languages,
            certifications: template.certifications,
            interests: template.interests,
            social: template.social
        )
        
        return try await cvRepository.saveCV(newCV)
    }
}