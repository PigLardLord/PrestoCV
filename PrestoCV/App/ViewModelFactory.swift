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
    private let makeExportService: () -> any CVExportServiceProtocol
    /// The description typed on the AI screen, kept until a draft is made from it.
    private let aiDescriptionSession = AIDescriptionSession()
    /// The saves of the editors that were left, which the router starts and the list and the editors wait for.
    private let leftEditorSaves = LeftEditorSaves()
    /// The changes to stored CVs that the list makes, one CV at a time, which the editor of the CV waits for.
    private let storedCVChanges = StoredCVChangeQueue()
    /// The copies the system makes of the PDFs opened in the app, which the import and the router let go.
    private var openedFileCopies: OpenedFileCopies {
        OpenedFileCopies(container: environment.container, removeFile: environment.removeFile)
    }
    
    /// - Parameter environment: What the view models read from the device.
    convenience init(
        dependencyContainer: PrestoCVCore.DependencyContainerProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        environment: AppEnvironment
    ) throws {
        try self.init(
            dependencyContainer: dependencyContainer,
            cvManagementUseCase: cvManagementUseCase,
            environment: environment,
            makeExportService: {
                CVExportService(
                    container: PDFExportDependencyContainer(),
                    fileNames: ExportFileName(titlePattern: DocumentTitlePatterns(bundle: environment.bundle).pattern(in:)),
                    temporaryDirectory: environment.temporaryDirectory
                )
            }
        )
    }

    /// - Parameters:
    ///   - environment: What the view models read from the device.
    ///   - makeExportService: Makes the service an export sheet exports and previews with, one for each sheet.
    init(
        dependencyContainer: PrestoCVCore.DependencyContainerProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        environment: AppEnvironment,
        makeExportService: @escaping () -> any CVExportServiceProtocol
    ) throws {
        self.dependencyContainer = dependencyContainer
        self.sampleRepository = try dependencyContainer.makeSampleCVRepository()
        self.cvManagementUseCase = cvManagementUseCase
        self.environment = environment
        self.makeExportService = makeExportService
    }
    
    @MainActor
    func makeOnboardingViewModel() throws -> OnboardingViewModel {
        return OnboardingViewModel(onboardingUseCase: try dependencyContainer.makeOnboardingUseCase())
    }

    /// The list of CVs, whose stored CVs are renamed and given a document language or a look through PrestoCVApplication.
    @MainActor
    func makeCVListViewModel() -> CVListViewModel {
        CVListViewModel(
            cvManagementUseCase: cvManagementUseCase,
            storedCVChanges: ChangeStoredCV(cvs: ManagedStoredCVs(cvs: cvManagementUseCase)),
            changeQueue: storedCVChanges,
            locale: environment.appLocale,
            now: environment.now,
            calendar: environment.calendar,
            sleep: environment.sleep,
            clock: environment.clock,
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
            awaitStoredChanges: storedCVChanges.settled,
            reportSaveFailure: { error in
                editorLogger.error("A change to a CV could not be saved: \(error.localizedDescription, privacy: .private)")
            }
        )
    }
    
    /// The export sheet of a CV of the list: the language and the design, palette and font chosen in it are stored with
    /// the CV. It starts from the CV as the store holds it now, with what was chosen in an earlier sheet and is not stored
    /// yet (`CVListViewModel.currentCV(withId:)`), and never from the row of the list, which can be a read behind: the
    /// sheet would show, and make the PDF from, a look or a language that an editor has changed since.
    /// - Returns: Nil when the CV cannot be read, which the list reports to the person.
    @MainActor
    func makeExportSheetViewModel(exportingCVWithId id: UUID, from list: CVListViewModel) async -> CVExportSheetViewModel? {
        guard let cv = await list.currentCV(withId: id) else { return nil }
        return makeExportSheetViewModel(
            cv: cv,
            documentLanguageSink: { language in
                list.chooseDocumentLanguage(language, ofCVWithId: id)
            },
            lookSink: { change in
                list.chooseLook(change, ofCVWithId: id)
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

    /// The AI screen. When the device has not got the language data a description needs, it asks the system for it and waits at
    /// most `LanguageDataPreparation.bound` (a debug launch can shorten it); the grounding then reads the data the system gave.
    @MainActor
    func makeAIGenerationViewModel() -> AIGenerationViewModel {
        let languageData = makeLanguageData()
        return AIGenerationViewModel(
            cvGenerationUseCase: makeCVGeneratorUseCase(lexicalClasses: languageData.tagger),
            mapper: AIDraftMapper(
                labels: makeAIDraftLabels(),
                languageOfText: DescriptionLanguageDetector.languageTag(of:)
            ),
            languageData: LanguageDataPreparation(requester: languageData.requester, bound: languageData.bound, sleep: environment.sleep),
            appLanguageCode: environment.appLanguage,
            session: aiDescriptionSession,
            platform: environment.platform
        )
    }

    /// The import of a CV the person already has: pasted text, or a PDF read with PDFKit, both on the device. It logs what it
    /// read and how it failed to the app's log (ADR 0030).
    @MainActor
    func makeImportViewModel() -> ImportViewModel {
        let limits = ImportLimits.standard
        return ImportViewModel(
            importer: ImportCV(
                pdfReader: PDFKitTextExtractor(logger: environment.diagnostics),
                limits: limits,
                logger: environment.diagnostics,
                clock: environment.clock
            ),
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
            exportService: makeExportService(),
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
        DocumentLanguageDetector(preferredLanguages: environment.preferredLanguages(), read: { NaturalLanguageReader.read($0) })
    }

    @MainActor
    private func makeAIAvailabilityProvider() -> AIAvailabilityProvider {
        #if DEBUG
        if let forced = AIAvailabilityOverride.current(arguments: environment.arguments) {
            return { forced }
        }
        #endif

        let useCase = makeCVGeneratorUseCase(lexicalClasses: DeviceLexicalTagger())
        return { useCase.availability() }
    }

    /// What tells the verbs of English and German, what asks the system for their data, and how long the wait for it lasts: the
    /// device's framework and the app's bound, or, in a debug build, the data a UI test scripted.
    @MainActor
    private func makeLanguageData() -> (tagger: any LexicalTagger, requester: any LanguageDataRequesting, bound: Duration) {
        #if DEBUG
        if let scripted = LanguageDataOverride.current(arguments: environment.arguments) {
            return (scripted.tagger, scripted.requester, scripted.bound)
        }
        #endif
        return (DeviceLexicalTagger(), NaturalLanguageDataRequester(), LanguageDataPreparation.bound)
    }

    /// The generation on the device's model, whose draft the rules (ADR 0023) and the claim check (ADR 0028) limit to what the
    /// description states, telling verbs with `lexicalClasses`. A debug build can script the model and the check for a UI test.
    @MainActor
    private func makeCVGeneratorUseCase(lexicalClasses: any LexicalTagger) -> CVGeneratorUseCase {
        #if DEBUG
        let service = AIDraftScript.service(arguments: environment.arguments) ?? FoundationModelsService()
        let claimChecker = AIDraftScript.claimChecker(arguments: environment.arguments) ?? FoundationModelsClaimChecker()
        #else
        let service: any CVGenerationService = FoundationModelsService()
        let claimChecker: any ClaimChecking = FoundationModelsClaimChecker()
        #endif
        return CVGeneratorUseCase(
            service: service,
            claimChecker: claimChecker,
            logger: environment.diagnostics,
            clock: environment.clock,
            sanitizer: CVDataSanitizer(
                languageOfText: { DescriptionLanguageDetector.languageTag(of: $0) }, lexicalClasses: lexicalClasses, wordList: DeviceWordList()
            )
        )
    }

    private func makeAIDraftLabels() -> AIDraftLabels {
        return AIDraftLabels(present: String(localized: "template.present"))
    }
}
