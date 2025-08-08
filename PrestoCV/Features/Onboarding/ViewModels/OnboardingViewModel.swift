import SwiftUI
import PrestoCVCore

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var onboardingState: OnboardingState = .loading
    @Published var isCreatingCV: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    private let onboardingUseCase: OnboardingUseCaseProtocol
    private let templateRepository: TemplateRepositoryProtocol
    
    // MARK: - Initialization
    init(
        onboardingUseCase: OnboardingUseCaseProtocol,
        templateRepository: TemplateRepositoryProtocol
    ) {
        self.onboardingUseCase = onboardingUseCase
        self.templateRepository = templateRepository
    }
    
    // MARK: - Public Methods
    func checkOnboardingStatus() async {
        onboardingState = .loading
        errorMessage = ""
        
        let state = await onboardingUseCase.checkOnboardingRequired()
        onboardingState = state
    }
    
    func createFirstCV() async {
        guard case .firstTime = onboardingState else { return }
        
        isCreatingCV = true
        errorMessage = ""
        
        do {
            let template = try await templateRepository.getDefaultTemplate()
            let _ = try await onboardingUseCase.createFirstCV(from: template)
            
            // Update state to reflect successful CV creation
            onboardingState = .returning
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreatingCV = false
    }
}