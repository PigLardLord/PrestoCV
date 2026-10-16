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
        return TemplateSelectionViewModel(aiAvailability: makeAIAvailabilityProvider())
    }

    @MainActor
    func makeAIGenerationViewModel() -> AIGenerationViewModel {
        return AIGenerationViewModel(
            cvGenerationUseCase: makeCVGeneratorUseCase(),
            mapper: AIDraftMapper(
                labels: makeAIDraftLabels(),
                languageOfText: DescriptionLanguageDetector.languageTag(of:)
            ),
            appLanguageCode: Bundle.main.preferredLocalizations.first
        )
    }

    // MARK: - Private Composition Root

    @MainActor
    private func makeAIAvailabilityProvider() -> AIAvailabilityProvider {
        #if DEBUG
        if let forced = AIAvailabilityOverride.current() {
            return { forced }
        }
        #endif

        let useCase = makeCVGeneratorUseCase()
        return { useCase.availability() }
    }

    @MainActor
    private func makeCVGeneratorUseCase() -> CVGeneratorUseCase {
        return CVGeneratorUseCase(
            service: FoundationModelsService(),
            sanitizer: CVDataSanitizer(languageOfText: DescriptionLanguageDetector.languageTag(of:))
        )
    }

    private func makeAIDraftLabels() -> AIDraftLabels {
        return AIDraftLabels(
            present: String(localized: "template.present"),
            untitled: String(localized: "editor.new_cv"),
            cvNameFormat: String(localized: "ai.draft.cv_name")
        )
    }
}
