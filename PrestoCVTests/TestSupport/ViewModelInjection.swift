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
    /// A device in English, on a fixed day in UTC, whose waits end only when cancelled
    static func fixed(newEditingID: @escaping () -> UUID = { UUID() }) -> AppEnvironment {
        AppEnvironment(
            now: { testDay },
            calendar: { gregorianUTC },
            timeZone: .gmt,
            appLanguage: "en",
            preferredLanguages: { ["en"] },
            sleep: waitUntilCancelled,
            newEditingID: newEditingID,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            exportPreferencesFile: FileManager.default.temporaryDirectory.appendingPathComponent("export-preferences-\(UUID().uuidString).json"),
            importInbox: FileManager.default.temporaryDirectory.appendingPathComponent("Inbox-\(UUID().uuidString)"),
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
    /// An editor whose Automatic document language falls back to English. To give it another detector, use the
    /// initialiser that takes every dependency.
    convenience init(
        cvId: String?,
        initialCV: CVModel? = nil,
        notice: EditorNotice? = nil,
        restoring restoredEdits: UnsavedEdits? = nil,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        unsavedEdits: UnsavedEditsKeeper? = nil,
        sleep: @escaping (Duration) async throws -> Void = waitUntilCancelled
    ) {
        self.init(
            cvId: cvId,
            initialCV: initialCV,
            notice: notice,
            restoring: restoredEdits,
            cvManagementUseCase: cvManagementUseCase,
            documentLanguageDetector: englishDocumentLanguageDetector,
            unsavedEdits: unsavedEdits,
            sleep: sleep
        )
    }
}

extension UnsavedEditsKeeper {
    /// A keeper whose waits after a change end only when cancelled
    convenience init(editing: UUID, claim: UnsavedEditsClaim? = nil, useCase: UnsavedEditsUseCaseProtocol) {
        self.init(editing: editing, claim: claim, useCase: useCase, wait: waitUntilCancelled)
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

extension UnsavedEditsOfferViewModel {
    /// An offer that tells its time in English, in UTC
    convenience init(useCase: UnsavedEditsUseCaseProtocol?, cvs: CVManagementUseCaseProtocol) {
        self.init(useCase: useCase, cvs: cvs, locale: Locale(identifier: "en"), timeZone: .gmt)
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
