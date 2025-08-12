import Foundation
import PrestoCVCore

final class ViewModelFactory {
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
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
    func makeTemplateSelectionViewModel() throws -> TemplateSelectionViewModel {
        return TemplateSelectionViewModel(
            sampleRepository: try dependencyContainer.makeSampleCVRepository(),
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
        )
    }
    
    @MainActor
    func makeCVEditorViewModel(cvId: String?) throws -> CVEditorViewModel {
        return CVEditorViewModel(
            cvId: cvId,
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
        )
    }
}