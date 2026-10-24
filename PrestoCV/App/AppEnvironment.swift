import Foundation

/// What the app reads from the device: the clock, the calendar and the time zone, the languages, its folders, its
/// launch arguments and the platform it runs on. The app reads them once, at its entry point (`AppEnvironment.device()`),
/// and the view model factory hands each view model and service the part it needs, so that nothing else reads the device
/// and tests give fixed ones.
struct AppEnvironment {
    /// The clock of the app
    let now: @Sendable () -> Date
    /// What counts as a day. It is asked for each time, so that a change of the device's time zone moves the days with it.
    let calendar: () -> Calendar
    /// The time zone times are told in
    let timeZone: TimeZone
    /// The language the app is shown in, as a BCP 47 tag; nil when the app has none
    let appLanguage: String?
    /// The person's languages, most wanted first
    let preferredLanguages: () -> [String]
    /// How the app waits
    let sleep: @Sendable (Duration) async throws -> Void
    /// The clock the editors measure the pause before they save on, and the list the pause before it stores what was chosen
    /// in an export sheet
    let clock: any Clock<Duration>
    /// Where each export gets a folder of its own
    let temporaryDirectory: URL
    /// Where earlier versions kept the design chosen last for the whole app. Nothing writes the file any more: it is read
    /// for a CV that has no look of its own. A file and not `UserDefaults`, which would need a privacy manifest entry
    let exportPreferencesFile: URL
    /// The app's own folder on the device. The system copies a PDF opened in the app ("Open in PrestoCV") into it, and the
    /// import deletes each copy once read
    let container: URL
    /// How the app deletes a file
    let removeFile: @Sendable (URL) throws -> Void
    /// The arguments the app was launched with
    let arguments: [String]
    /// The app's bundle, which holds its texts in each language
    let bundle: Bundle
    /// Where the app runs, as the AI entry tells it apart: an iPhone or an iPad, or a Mac that runs the iPad app
    let platform: AIPlatform

    /// The locale of the texts that format dates and the names of languages: the language of the app, which is what the
    /// rest of the texts are in, and not the region of the device, which can differ from it
    var appLocale: Locale {
        Locale(identifier: appLanguage ?? "en")
    }
}

extension AppEnvironment {
    /// The device the app runs on
    static func device() -> AppEnvironment {
        AppEnvironment(
            now: { Date() },
            calendar: { .autoupdatingCurrent },
            timeZone: .autoupdatingCurrent,
            appLanguage: Bundle.main.preferredLocalizations.first,
            preferredLanguages: { Locale.preferredLanguages },
            sleep: { try await Task.sleep(for: $0) },
            clock: ContinuousClock(),
            temporaryDirectory: FileManager.default.temporaryDirectory,
            exportPreferencesFile: URL.applicationSupportDirectory.appendingPathComponent("PrestoCV/export-preferences.json"),
            container: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
            removeFile: { try FileManager.default.removeItem(at: $0) },
            arguments: ProcessInfo.processInfo.arguments,
            bundle: .main,
            platform: .current
        )
    }
}
