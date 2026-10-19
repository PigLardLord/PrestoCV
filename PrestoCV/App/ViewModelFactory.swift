import Foundation
import PrestoCVCore
import CVGeneratorAI

final class ViewModelFactory {
    private let dependencyContainer: PrestoCVCore.DependencyContainerProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let unsavedEditsUseCase: UnsavedEditsUseCaseProtocol?
    private let newEditingID: () -> UUID
    /// The description typed on the AI screen, kept until a draft is made from it.
    private let aiDescriptionSession = AIDescriptionSession()
    
    /// - Parameters:
    ///   - unsavedEditsUseCase: Nil when the unsaved edits cannot be kept on this device: the editor works without them.
    ///   - newEditingID: Names the editing of a CV that does not restore earlier edits.
    init(
        dependencyContainer: PrestoCVCore.DependencyContainerProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        unsavedEditsUseCase: UnsavedEditsUseCaseProtocol?,
        newEditingID: @escaping () -> UUID = { UUID() }
    ) throws {
        self.dependencyContainer = dependencyContainer
        self.sampleRepository = try dependencyContainer.makeSampleCVRepository()
        self.cvManagementUseCase = cvManagementUseCase
        self.unsavedEditsUseCase = unsavedEditsUseCase
        self.newEditingID = newEditingID
    }
    
    @MainActor
    func makeOnboardingViewModel() throws -> OnboardingViewModel {
        return OnboardingViewModel(onboardingUseCase: try dependencyContainer.makeOnboardingUseCase())
    }
    
    /// The editor of `request`. Restored edits go on being kept as the editing they belong to, with the claim the
    /// window took on them; any other editing gets a new one.
    @MainActor
    func makeCVEditorViewModel(for request: EditorRequest) -> CVEditorViewModel {
        switch request {
        case .stored(let cvId):
            return makeCVEditorViewModel(cvId: cvId)
        case .new(let template, let notice):
            return makeCVEditorViewModel(initialCV: template, notice: notice)
        case .restoring(let restored):
            return makeCVEditorViewModel(restoring: restored)
        }
    }
    
    /// The export sheet of a CV of the list: the language chosen in it is stored with the CV.
    @MainActor
    func makeExportSheetViewModel(exporting cv: CVModel, from list: CVListViewModel) -> CVExportSheetViewModel {
        makeExportSheetViewModel(cv: cv) { language in
            Task { await list.setDocumentLanguage(language, ofCVWithId: cv.id) }
        }
    }
    
    /// The export sheet of the CV an editor shows: the language chosen in it goes into the form, which saves it with
    /// the rest of the edits.
    @MainActor
    func makeExportSheetViewModel(editing editor: CVEditorViewModel) -> CVExportSheetViewModel {
        makeExportSheetViewModel(cv: editor.cv) { language in
            editor.documentLanguageSelection = language
        }
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
            languageData: NaturalLanguageDataRequester(),
            appLanguageCode: Bundle.main.preferredLocalizations.first,
            session: aiDescriptionSession
        )
    }

    // MARK: - Private Composition Root

    /// An export sheet with a service and a preferences store of its own.
    @MainActor
    private func makeExportSheetViewModel(
        cv: CVModel,
        documentLanguageSink: @escaping DocumentLanguageSink
    ) -> CVExportSheetViewModel {
        CVExportSheetViewModel(
            cv: cv,
            exportService: CVExportService(),
            preferencesStore: FileExportPreferencesStore(),
            documentLanguageSink: documentLanguageSink,
            exportPolicy: .standard
        )
    }

    @MainActor
    private func makeCVEditorViewModel(
        cvId: String? = nil,
        initialCV: CVModel? = nil,
        notice: EditorNotice? = nil,
        restoring restored: RestoredUnsavedEdits? = nil
    ) -> CVEditorViewModel {
        CVEditorViewModel(
            cvId: cvId,
            initialCV: initialCV,
            notice: notice,
            restoring: restored?.edits,
            cvManagementUseCase: cvManagementUseCase,
            unsavedEdits: unsavedEditsUseCase.map {
                UnsavedEditsKeeper(editing: restored?.edits.id ?? newEditingID(), claim: restored?.takeClaim(), useCase: $0)
            }
        )
    }

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
            sanitizer: CVDataSanitizer(languageOfText: DescriptionLanguageDetector.languageTag(of:), lexicalClasses: DeviceLexicalTagger())
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
