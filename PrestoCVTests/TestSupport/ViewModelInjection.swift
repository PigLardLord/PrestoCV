import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

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
let englishDocumentLanguageDetector = DocumentLanguageDetector(preferredLanguages: ["en"], read: NaturalLanguageReader.read)

extension AppEnvironment {
    /// A device in English, on a fixed day in UTC, whose waits end only when cancelled, and whose clock moves only when
    /// a test moves it
    static func fixed(
        clock: any Clock<Duration> = ManualClock(),
        container: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Container-\(UUID().uuidString)")
    ) -> AppEnvironment {
        AppEnvironment(
            now: { testDay },
            calendar: { gregorianUTC },
            timeZone: .gmt,
            appLanguage: "en",
            preferredLanguages: { ["en"] },
            sleep: waitUntilCancelled,
            clock: clock,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            exportPreferencesFile: FileManager.default.temporaryDirectory.appendingPathComponent("export-preferences-\(UUID().uuidString).json"),
            container: container,
            removeFile: { try FileManager.default.removeItem(at: $0) },
            arguments: [],
            bundle: Bundle(for: AppRouter.self),
            platform: .iPhoneOrIPad
        )
    }
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
    /// so a test that does not move it sees what `saveNow()` and leaving store.
    convenience init(
        cvId: String?,
        initialCV: CVModel? = nil,
        notice: EditorNotice? = nil,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        documentLanguageDetector: DocumentLanguageDetector = englishDocumentLanguageDetector,
        clock: any Clock<Duration> = ManualClock()
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
            documentLanguageDetector: documentLanguageDetector,
            clock: clock
        )
    }
}

extension CVListViewModel {
    /// A list whose stored CVs change through `cvManagementUseCase`, as the app's do, told in English
    convenience init(
        cvManagementUseCase: CVManagementUseCaseProtocol,
        now: @escaping () -> Date = { testDay },
        calendar: @escaping () -> Calendar = { gregorianUTC },
        sleep: @escaping (Duration) async throws -> Void = waitUntilCancelled
    ) {
        self.init(
            cvManagementUseCase: cvManagementUseCase,
            storedCVChanges: .init(cvs: ManagedStoredCVs(cvs: cvManagementUseCase)),
            locale: Locale(identifier: "en"),
            now: now,
            calendar: calendar,
            sleep: sleep
        )
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
