import Foundation
import PrestoCVCore
import CVGeneratorAI
import CVPDFExporter
import PrestoCVImporting
import PrestoCVImportingPDFKit
import struct PrestoCVApplication.ChangeStoredCV

/// The composition root of the screens: it makes every view model, with the real services and the part of the device's
/// environment each one needs. No view model makes a dependency of its own.
final class ViewModelFactory {
    private let dependencyContainer: PrestoCVCore.DependencyContainerProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let unsavedEditsUseCase: UnsavedEditsUseCaseProtocol?
    private let environment: AppEnvironment
    /// The description typed on the AI screen, kept until a draft is made from it.
    private let aiDescriptionSession = AIDescriptionSession()
    
    /// - Parameters:
    ///   - unsavedEditsUseCase: Nil when the unsaved edits cannot be kept on this device: the editor works without them.
    ///   - environment: What the view models read from the device.
    init(
        dependencyContainer: PrestoCVCore.DependencyContainerProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        unsavedEditsUseCase: UnsavedEditsUseCaseProtocol?,
        environment: AppEnvironment
    ) throws {
        self.dependencyContainer = dependencyContainer
        self.sampleRepository = try dependencyContainer.makeSampleCVRepository()
        self.cvManagementUseCase = cvManagementUseCase
        self.unsavedEditsUseCase = unsavedEditsUseCase
        self.environment = environment
    }
    
    @MainActor
    func makeOnboardingViewModel() throws -> OnboardingViewModel {
        return OnboardingViewModel(onboardingUseCase: try dependencyContainer.makeOnboardingUseCase())
    }

    /// The list of CVs, whose stored CVs are renamed and given a document language through PrestoCVApplication.
    @MainActor
    func makeCVListViewModel() -> CVListViewModel {
        CVListViewModel(
            cvManagementUseCase: cvManagementUseCase,
            storedCVChanges: ChangeStoredCV(cvs: ManagedStoredCVs(cvs: cvManagementUseCase)),
            locale: environment.appLocale,
            now: environment.now,
            calendar: environment.calendar,
            sleep: environment.sleep
        )
    }

    /// The offer to restore the edits an earlier run of the app left unsaved.
    @MainActor
    func makeUnsavedEditsOfferViewModel() -> UnsavedEditsOfferViewModel {
        UnsavedEditsOfferViewModel(
            useCase: unsavedEditsUseCase,
            cvs: cvManagementUseCase,
            locale: environment.appLocale,
            timeZone: environment.timeZone
        )
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
        let sleep = environment.sleep
        return NewCVChoicesViewModel(
            aiAvailability: makeAIAvailabilityProvider(),
            sampleRepository: sampleRepository,
            pause: { try await sleep(NewCVChoicesViewModel.downloadCheckInterval) },
            platform: environment.platform
        )
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
            appLanguageCode: environment.appLanguage,
            session: aiDescriptionSession,
            platform: environment.platform
        )
    }

    /// The import of a CV the person already has: pasted text, or a PDF read with PDFKit, both on the device.
    @MainActor
    func makeImportViewModel() -> ImportViewModel {
        let limits = ImportLimits.standard
        return ImportViewModel(
            importer: ImportCV(pdfReader: PDFKitTextExtractor(), limits: limits),
            mapper: ImportedCVMapper(),
            readFile: { [inbox = environment.importInbox] url in
                try await ChosenFileReader(maximumBytes: limits.maximumPDFBytes, inbox: inbox).read(url)
            }
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
            exportService: CVExportService(
                container: PDFExportDependencyContainer(),
                fileNames: ExportFileName(titlePattern: DocumentTitlePatterns(bundle: environment.bundle).pattern(in:)),
                temporaryDirectory: environment.temporaryDirectory
            ),
            preferencesStore: FileExportPreferencesStore(fileURL: environment.exportPreferencesFile),
            documentLanguageSink: documentLanguageSink,
            exportPolicy: .standard,
            documentLanguageDetector: makeDocumentLanguageDetector(),
            appLocale: environment.appLocale
        )
    }

    /// Reads the language a CV is written in with the system's recognizer, for the Automatic document language, and
    /// falls back to the person's languages.
    private func makeDocumentLanguageDetector() -> DocumentLanguageDetector {
        DocumentLanguageDetector(preferredLanguages: environment.preferredLanguages(), read: NaturalLanguageReader.read)
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
            documentLanguageDetector: makeDocumentLanguageDetector(),
            unsavedEdits: unsavedEditsUseCase.map {
                UnsavedEditsKeeper(
                    editing: restored?.edits.id ?? environment.newEditingID(),
                    claim: restored?.takeClaim(),
                    useCase: $0,
                    wait: environment.sleep
                )
            },
            sleep: LaunchEnvironment.savedConfirmationWait(arguments: environment.arguments, sleep: environment.sleep)
        )
    }

    @MainActor
    private func makeAIAvailabilityProvider() -> AIAvailabilityProvider {
        #if DEBUG
        if let forced = AIAvailabilityOverride.current(arguments: environment.arguments) {
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
        return AIDraftLabels(present: String(localized: "template.present"))
    }
}
