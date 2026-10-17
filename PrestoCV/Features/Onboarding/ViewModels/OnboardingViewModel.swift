import SwiftUI
import PrestoCVCore

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var onboardingState: OnboardingState = .loading
    
    // MARK: - Private Properties
    private let onboardingUseCase: OnboardingUseCaseProtocol
    
    // MARK: - Initialization
    init(onboardingUseCase: OnboardingUseCaseProtocol) {
        self.onboardingUseCase = onboardingUseCase
    }
    
    // MARK: - Public Methods
    func checkOnboardingStatus() async {
        onboardingState = .loading
        
        let state = await onboardingUseCase.checkOnboardingRequired()
        onboardingState = state
    }
    
    // MARK: - View Action Methods (Synchronous wrappers)
    
    func performCheckOnboardingStatus() {
        Task {
            await checkOnboardingStatus()
        }
    }
}
