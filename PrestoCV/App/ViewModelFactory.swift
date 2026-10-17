import Foundation
import PrestoCVCore
import CVGeneratorAI

final class ViewModelFactory {
    private let dependencyContainer: PrestoCVCore.DependencyContainerProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    /// The description typed on the AI screen, kept until a draft is made from it.
    private let aiDescriptionSession = AIDescriptionSession()
    
    init(dependencyContainer: PrestoCVCore.DependencyContainerProtocol) throws {
        self.dependencyContainer = dependencyContainer
        self.sampleRepository = try dependencyContainer.makeSampleCVRepository()
    }
    
    @MainActor
    func makeOnboardingViewModel() throws -> OnboardingViewModel {
        return OnboardingViewModel(onboardingUseCase: try dependencyContainer.makeOnboardingUseCase())
    }
    
    @MainActor
    func makeNewCVChoicesViewModel() -> NewCVChoicesViewModel {
        return NewCVChoicesViewModel(aiAvailability: makeAIAvailabilityProvider(), sampleRepository: sampleRepository)
    }

    @MainActor
    func makeAIGenerationViewModel() -> AIGenerationViewModel {
        return AIGenerationViewModel(
            cvGenerationUseCase: makeCVGeneratorUseCase(),
            mapper: AIDraftMapper(
                labels: makeAIDraftLabels(),
                languageOfText: DescriptionLanguageDetector.languageTag(of:)
            ),
            appLanguageCode: Bundle.main.preferredLocalizations.first,
            session: aiDescriptionSession
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
