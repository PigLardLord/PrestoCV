import SwiftUI
import PrestoCVCore
import os

private let onboardingLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "onboarding")

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var onboardingState: OnboardingState = .loading
    @Published private(set) var samples: [CVModel] = []
    
    // MARK: - Private Properties
    private let onboardingUseCase: OnboardingUseCaseProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    
    // MARK: - Initialization
    init(
        onboardingUseCase: OnboardingUseCaseProtocol,
        sampleRepository: SampleCVRepositoryProtocol
    ) {
        self.onboardingUseCase = onboardingUseCase
        self.sampleRepository = sampleRepository
    }
    
    // MARK: - Public Methods
    func checkOnboardingStatus() async {
        onboardingState = .loading
        
        let state = await onboardingUseCase.checkOnboardingRequired()
        onboardingState = state
    }
    
    /// Loads the sample CVs the user can start from. Without samples the user can still start from a blank CV.
    func loadSamples() async {
        guard samples.isEmpty else { return }
        
        do {
            samples = try await sampleRepository.getAllSamples()
        } catch {
            onboardingLogger.error("The sample CVs were not loaded: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// The CV the editor opens for a sample: its content under a new identity, with the details of the person
    /// the sample describes left blank. Nothing is stored until the user saves it.
    func makeDraft(from sample: CVModel) -> CVModel {
        var draft = sample.copy()
        draft.name = ""
        draft.personalInfo.name = ""
        draft.personalInfo.email = ""
        draft.personalInfo.phone = ""
        draft.personalInfo.location = ""
        draft.personalInfo.portfolio = ""
        draft.social = draft.social.map { Social(id: $0.id, platform: $0.platform, url: "") }
        return draft
    }
    
    // MARK: - View Action Methods (Synchronous wrappers)
    
    func performCheckOnboardingStatus() {
        Task {
            await checkOnboardingStatus()
        }
    }
}
