import Foundation
import PrestoCVCore
import CVGeneratorAI
import CVPDFExporter

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
    func makeTemplateSelectionViewModel() throws -> NewTemplateSelectionViewModel {
        return NewTemplateSelectionViewModel(
            getTemplatesUseCase: makeGetAvailableTemplatesUseCase(),
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
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

    // MARK: - Template System Factories

    /// Creates a GetAvailableTemplatesUseCase with BundledTemplateRepository
    func makeGetAvailableTemplatesUseCase() -> GetAvailableTemplatesUseCase {
        let repository = makeBundledTemplateRepository()
        return GetAvailableTemplatesUseCase(repositories: [repository])
    }

    /// Creates a BundledTemplateRepository for built-in templates
    private func makeBundledTemplateRepository() -> BundledTemplateRepository {
        return BundledTemplateRepository()
    }
}