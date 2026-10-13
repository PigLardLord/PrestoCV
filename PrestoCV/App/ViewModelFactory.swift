import Foundation
import PrestoCVCore
import CVGeneratorAI

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
    func makeCVEditorViewModel(cvId: String?, initialCV: CVModel?) throws -> CVEditorViewModel {
        return CVEditorViewModel(
            cvId: cvId,
            initialCV: initialCV,
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
        )
    }

    @MainActor
    func makeAIGenerationViewModel() throws -> AIGenerationViewModel {
        guard let cvGenerationUseCase = makeCVGeneratorUseCase() else {
            throw DependencyError.serviceCreationFailed("CVGeneratorUseCase", NSError(domain: "AI generation not available on this device", code: -1))
        }
        return AIGenerationViewModel(
            cvGenerationUseCase: cvGenerationUseCase,
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
        )
    }

    func isAIGenerationAvailable() -> Bool {
        return FeatureFlags.isAIGenerationAvailable
    }

    // MARK: - Private Composition Root

    @MainActor
    private func makeCVGeneratorUseCase() -> CVGeneratorUseCase? {
        guard FeatureFlags.isAIGenerationAvailable else {
            return nil
        }

        guard let service = makeCVGenerationService() else {
            return nil
        }
        return CVGeneratorUseCase(service: service)
    }

    @MainActor
    private func makeCVGenerationService() -> CVGenerationService? {
        guard FeatureFlags.isAIGenerationAvailable else {
            return nil
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            return FoundationModelsService()
        }
        #endif

        return nil
    }
}