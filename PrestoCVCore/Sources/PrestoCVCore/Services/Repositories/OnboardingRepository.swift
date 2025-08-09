import Foundation

// MARK: - Onboarding Repository Implementation

public final class OnboardingRepository: OnboardingRepositoryProtocol {
    private let cvRepository: CVRepositoryProtocol
    
    public init(cvRepository: CVRepositoryProtocol) {
        self.cvRepository = cvRepository
    }
    
    public func hasExistingCVs() async -> Bool {
        return await cvRepository.cvExists()
    }
    
    public func getOnboardingState() async -> OnboardingState {
        let hasExistingCVs = await self.hasExistingCVs()
        return hasExistingCVs ? .returning : .firstTime
    }
}