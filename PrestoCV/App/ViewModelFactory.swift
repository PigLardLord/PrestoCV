import Foundation
import PrestoCVCore
import CVGeneratorAI
import CVPDFExporter
import PrestoCVImporting
import PrestoCVImportingPDFKit
import struct PrestoCVApplication.ChangeStoredCV
import os

private let editorLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "editor")

/// The composition root of the screens: it makes every view model, with the real services and the part of the device's
/// environment each one needs. No view model makes a dependency of its own.
final class ViewModelFactory {
    private let dependencyContainer: PrestoCVCore.DependencyContainerProtocol
    private let sampleRepository: SampleCVRepositoryProtocol
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let environment: AppEnvironment
    /// The description typed on the AI screen, kept until a draft is made from it.
    private let aiDescriptionSession = AIDescriptionSession()
    /// The saves of the editors that were left, which the router starts and the list and the editors wait for.
    private let leftEditorSaves = LeftEditorSaves()
    /// The copies the system makes of the PDFs opened in the app, which the import and the router let go.
    private var openedFileCopies: OpenedFileCopies {
        OpenedFileCopies(container: environment.container, removeFile: environment.removeFile)
    }
    
    /// - Parameter environment: What the view models read from the device.
    init(
        dependencyContainer: PrestoCVCore.DependencyContainerProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        environment: AppEnvironment
    ) throws {
        self.dependencyContainer = dependencyContainer
        self.sampleRepository = try dependencyContainer.makeSampleCVRepository()
        self.cvManagementUseCase = cvManagementUseCase
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
            sleep: environment.sleep,
            awaitLeftEditors: leftEditorSaves.allEnded
        )
    }

    /// The editor of `request`, which saves what it shows by itself. A failed write is logged with its cause.
    @MainActor
    func makeCVEditorViewModel(for request: EditorRequest) -> CVEditorViewModel {
        CVEditorViewModel(
            request: request,
            cvManagementUseCase: cvManagementUseCase,
            documentLanguageDetector: makeDocumentLanguageDetector(),
            clock: environment.clock,
            awaitLeftEditors: leftEditorSaves.allEnded,
            reportSaveFailure: { error in
                editorLogger.error("A change to a CV could not be saved: \(error.localizedDescription, privacy: .private)")
            }
        )
    }
    
    /// The export sheet of a CV of the list: the language and the design, palette and font chosen in it are stored with
    /// the CV.
    @MainActor
    func makeExportSheetViewModel(exporting cv: CVModel, from list: CVListViewModel) -> CVExportSheetViewModel {
        makeExportSheetViewModel(
            cv: cv,
            documentLanguageSink: { language in
                Task { await list.setDocumentLanguage(language, ofCVWithId: cv.id) }
            },
            lookSink: { look in
                Task { await list.setLook(look, ofCVWithId: cv.id) }
            }
        )
    }
    
    /// The export sheet of the CV an editor shows: the language and the design, palette and font chosen in it go into
    /// the form, which saves them by itself.
    @MainActor
    func makeExportSheetViewModel(editing editor: CVEditorViewModel) -> CVExportSheetViewModel {
        makeExportSheetViewModel(
            cv: editor.cv,
            documentLanguageSink: { language in
                editor.documentLanguageSelection = language
            },
            lookSink: { look in
                editor.chooseLook(look)
            }
        )
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
            fileReader: ChosenFileReader(maximumBytes: limits.maximumPDFBytes, copies: openedFileCopies)
        )
    }

    /// The router of the screens. It lets go of a PDF opened in the app that no import will read.
    @MainActor
    func makeAppRouter() -> AppRouter {
        AppRouter(releaseFile: openedFileCopies.release, leftEditorSaves: leftEditorSaves)
    }

    // MARK: - Private Composition Root

    /// An export sheet with a service of its own, and the file of the old global choice to read for a CV without a look.
    @MainActor
    private func makeExportSheetViewModel(
        cv: CVModel,
        documentLanguageSink: @escaping DocumentLanguageSink,
        lookSink: @escaping LookSink
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
            lookSink: lookSink,
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
