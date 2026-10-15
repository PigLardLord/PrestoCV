import Foundation
import PrestoCVCore
import CVGeneratorAI

final class ViewModelFactory {
    private let dependencyContainer: PrestoCVCore.DependencyContainerProtocol
    
    init(dependencyContainer: PrestoCVCore.DependencyContainerProtocol) {
        self.dependencyContainer = dependencyContainer
    }
    
    @MainActor
    func makeOnboardingViewModel() throws -> OnboardingViewModel {
        return OnboardingViewModel(
            onboardingUseCase: try dependencyContainer.makeOnboardingUseCase(),
            sampleRepository: try dependencyContainer.makeSampleCVRepository()
        )
    }
    
    @MainActor
    func makeTemplateSelectionViewModel() -> TemplateSelectionViewModel {
        let service = FoundationModelsService()
        return TemplateSelectionViewModel(aiAvailability: { service.availability() })
    }

    @MainActor
    func makeAIGenerationViewModel() throws -> AIGenerationViewModel {
        return AIGenerationViewModel(
            cvGenerationUseCase: CVGeneratorUseCase(service: FoundationModelsService()),
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
        )
    }
}
