import Foundation

// MARK: - Onboarding Repository Implementation

public final class OnboardingRepository: OnboardingRepositoryProtocol, Sendable {
    private let cvRepository: CVRepositoryProtocol
    
    public init(cvRepository: CVRepositoryProtocol) {
        self.cvRepository = cvRepository
    }
    
    public func hasExistingCVs() async throws -> Bool {
        return try await cvRepository.cvExists()
    }
    
    public func getOnboardingState() async -> OnboardingState {
        do {
            return try await hasExistingCVs() ? .returning : .firstTime
        } catch {
            return .error(AppError.from(error))
        }
    }
}