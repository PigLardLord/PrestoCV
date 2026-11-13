import DiagnosticLogging
import DiagnosticTrace
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct PrestoCVApplication.LookChange

// The view models take every dependency through their initialisers, and the app's entry point gives them the device's.
// These tests give fixed ones unless they vary them: English, a fixed day in UTC, and waits that end only when their task
// is cancelled, so that time passes only when a test makes it pass.

/// A day the tests are run on
let testDay = Date(timeIntervalSince1970: 1_700_000_000)

/// A wait that ends only when its task is cancelled, with `CancellationError`, as `Task.sleep` does then
func waitUntilCancelled(_ duration: Duration) async throws {
    try await HeldSleeps().sleep(for: duration)
}

/// Reads the language of a CV with the system's recognizer, and falls back to English
let englishDocumentLanguageDetector = DocumentLanguageDetector(preferredLanguages: ["en"], read: { NaturalLanguageReader.read($0) })

extension AppEnvironment {
    /// A device in English, on a fixed day in UTC, whose waits end only when cancelled (or as `sleep` says), and whose clock
    /// moves only when a test moves it. `arguments` are the launch arguments, none by default; `diagnostics` is where the
    /// import and the AI draft log, nowhere by default.
    static func fixed(
        clock: any Clock<Duration> = ManualClock(),
        container: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Container-\(UUID().uuidString)"),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await waitUntilCancelled($0) },
        arguments: [String] = [],
        diagnostics: any DiagnosticLogger = SilentLogger()
    ) -> AppEnvironment {
        AppEnvironment(
            now: { testDay },
            calendar: { gregorianUTC },
            timeZone: .gmt,
            appLanguage: "en",
            preferredLanguages: { ["en"] },
            sleep: sleep,
            clock: clock,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            exportPreferencesFile: FileManager.default.temporaryDirectory.appendingPathComponent("export-preferences-\(UUID().uuidString).json"),
            importNoticesDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("import-notices-\(UUID().uuidString)", isDirectory: true),
            container: container,
            removeFile: { try FileManager.default.removeItem(at: $0) },
            arguments: arguments,
            bundle: Bundle(for: AppRouter.self),
            platform: .iPhoneOrIPad,
            diagnostics: diagnostics,
            tracer: NoTracer(),
            trace: TraceAccess(isOn: { false }, reader: NoStoredRuns())
        )
    }
}

/// A trace store with no run, for the tests whose trace does not record
private struct NoStoredRuns: TraceReading {
    func runs() async -> [TraceRunListing] { [] }
    func shareCopies(of id: UUID) async throws -> [URL] { [] }
    func discardCopies() async {}
}

/// The Gregorian calendar in UTC
let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

extension CVEditorViewModel {
    /// An editor as the tests open it: `cvId` opens a stored CV; otherwise `initialCV`, or a blank CV, opens as a new
    /// CV with `notice`: stored as it is with the AI or the import notice, and once it is changed without one. Its
    /// Automatic document language falls back to English. Its pause before a save ends only when the test moves `clock`,
    /// so a test that does not move it sees what `saveNow()` and leaving store. The import notice is kept in memory, in
    /// `noticeStore`.
    convenience init(
        cvId: String?,
        initialCV: CVModel? = nil,
        notice: EditorNotice? = nil,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        noticeStore: any EditorNoticeStore = InMemoryEditorNoticeStore(),
        documentLanguageDetector: DocumentLanguageDetector = englishDocumentLanguageDetector,
        clock: any Clock<Duration> = ManualClock(),
        awaitLeftEditors: @escaping @MainActor () async -> Void = {},
        awaitStoredChanges: @escaping @MainActor (UUID) async -> Void = { _ in },
        reportSaveFailure: @escaping @MainActor @Sendable (any Error) -> Void = { _ in }
    ) {
        let request: EditorRequest
        if let cvId {
            request = .stored(cvId: cvId)
        } else {
            request = .new(template: initialCV ?? CVModel(), notice: notice)
        }
        self.init(
            request: request,
            cvManagementUseCase: cvManagementUseCase,
            noticeStore: noticeStore,
            documentLanguageDetector: documentLanguageDetector,
            clock: clock,
            awaitLeftEditors: awaitLeftEditors,
            awaitStoredChanges: awaitStoredChanges,
            reportSaveFailure: reportSaveFailure
        )
    }
}

extension CVListViewModel {
    /// A list whose stored CVs change through `cvManagementUseCase`, as the app's do, told in English. The notices of the
    /// imported CVs are kept in `noticeStore`, in memory by default.
    convenience init(
        cvManagementUseCase: CVManagementUseCaseProtocol,
        noticeStore: any EditorNoticeStore = InMemoryEditorNoticeStore(),
        now: @escaping () -> Date = { testDay },
        calendar: @escaping () -> Calendar = { gregorianUTC },
        sleep: @escaping (Duration) async throws -> Void = waitUntilCancelled,
        clock: any Clock<Duration> = ManualClock(),
        changeQueue: StoredCVChangeQueue = StoredCVChangeQueue(),
        awaitLeftEditors: @escaping @MainActor () async -> Void = {}
    ) {
        self.init(
            cvManagementUseCase: cvManagementUseCase,
            storedCVChanges: .init(cvs: ManagedStoredCVs(cvs: cvManagementUseCase)),
            changeQueue: changeQueue,
            noticeStore: noticeStore,
            locale: Locale(identifier: "en"),
            now: now,
            calendar: calendar,
            sleep: sleep,
            clock: clock,
            awaitLeftEditors: awaitLeftEditors
        )
    }

    /// Chooses a language the way a sheet does, and returns once it is stored: the pause before it is stored is not waited for
    func setDocumentLanguage(_ language: DocumentLanguage?, ofCVWithId id: UUID) async {
        let save = chooseDocumentLanguage(language, ofCVWithId: id)
        storeChoicesNow()
        await save?.value
    }

    /// Chooses a look the way a sheet does, and returns once it is stored, or once the save under way that will store it
    /// has begun: the pause before it is stored is not waited for
    func setLook(_ change: LookChange, ofCVWithId id: UUID) async {
        let save = chooseLook(change, ofCVWithId: id)
        storeChoicesNow()
        await save?.value
    }
}

extension NewCVChoicesViewModel {
    /// Choices whose pause between two reads of the AI's availability ends only when cancelled
    convenience init(
        aiAvailability: @escaping AIAvailabilityProvider,
        sampleRepository: SampleCVRepositoryProtocol,
        isAIShipped: Bool = AIFeature.isShipped,
        platform: AIPlatform = .iPhoneOrIPad
    ) {
        self.init(aiAvailability: aiAvailability, sampleRepository: sampleRepository, pause: { try await waitUntilCancelled(.zero) },
                  isAIShipped: isAIShipped, platform: platform)
    }
}
