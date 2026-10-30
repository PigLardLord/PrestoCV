import DiagnosticLogging
import DiagnosticTrace
import DiagnosticTraceDistribution
import DiagnosticTraceFiles
import Foundation

/// What the app reads from the device: the clock, the calendar and the time zone, the languages, its folders, its
/// launch arguments and the platform it runs on, and where it writes its diagnostic log. The app reads them once, at its
/// entry point (`AppEnvironment.device(diagnostics:)`), and the view model factory hands each view model and service the
/// part it needs, so that nothing else reads the device and tests give fixed ones.
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
    /// The clock the editors measure the pause before they save on, the list the pause before it stores what was chosen in
    /// an export sheet, and the import and the AI draft time their steps on
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
    /// Where the import and the AI draft write what they did (ADR 0030): the unified log on the device, whose entries go
    /// to the trace of a test build as well
    let diagnostics: any DiagnosticLogger
    /// Where the import and the AI draft record each step, with its text, in a TestFlight or Debug build (ADR 0032). It
    /// records nothing in an App Store build
    let tracer: any DiagnosticTracer
    /// Whether the trace records on this launch, and the runs it stored, for the diagnostics screen
    let trace: TraceAccess

    /// The locale of the texts that format dates and the names of languages: the language of the app, which is what the
    /// rest of the texts are in, and not the region of the device, which can differ from it
    var appLocale: Locale {
        Locale(identifier: appLanguage ?? "en")
    }
}

extension AppEnvironment {
    /// The device the app runs on, with the log the app writes to
    static func device(diagnostics: any DiagnosticLogger) -> AppEnvironment {
        let arguments = ProcessInfo.processInfo.arguments
        let trace = TraceChain(
            directory: URL.applicationSupportDirectory.appendingPathComponent("Diagnostics", isDirectory: true),
            shareDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("DiagnosticsShare", isDirectory: true),
            gate: .current(arguments: arguments),
            device: .current,
            log: diagnostics
        )
        return AppEnvironment(
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
            arguments: arguments,
            bundle: .main,
            platform: .current,
            diagnostics: trace.logger,
            tracer: trace.tracer,
            trace: trace.access
        )
    }
}

// MARK: - The trace of a test build (ADR 0032)

/// The trace of the import and the AI draft, as the app builds it: the log entries go to the open run of their kind as
/// well, and every run goes through the gate to a recorder that keeps it in the store. A launch whose gate stays closed
/// purges what an earlier install stored. Only this file and the app's entry point build it, so no other code can turn the
/// trace on or reach its files.
struct TraceChain {
    /// The trace the import and the AI draft record into
    let tracer: any DiagnosticTracer
    /// The log the import and the AI draft write to
    let logger: any DiagnosticLogger
    /// Whether the trace records on this launch, and the runs it stored
    let access: TraceAccess

    /// - Parameters:
    ///   - directory: The folder of the stored runs, made on the first run the gate lets through.
    ///   - shareDirectory: The folder of the copies made to share.
    ///   - log: The log the entries go on to. The store reports its own failures to it, and not to the trace.
    init(directory: URL, shareDirectory: URL, gate launch: TraceLaunchGate, device: TraceDevice, log: any DiagnosticLogger) {
        let store = TraceFileStore(directory: directory, shareDirectory: shareDirectory, logger: log)
        let recorder = TraceRecorder(
            store: store,
            build: {
                TraceBuild(
                    appVersion: device.appVersion, build: device.build, distribution: launch.distribution(),
                    osVersion: device.osVersion, deviceModel: device.model
                )
            },
            clock: ContinuousClock(),
            now: { Date() },
            newID: { UUID() }
        )
        // A build that may not record keeps nothing: a TestFlight install replaced by the App Store build keeps its data
        // container, and with it the runs the earlier install stored. The store does it on its own task, after the answer.
        let startup = Task {
            await launch.answered()
            if !launch.gate.isOpen { await store.purge() }
        }
        let tracer = GatedTracer(gate: launch.gate, next: recorder)
        self.tracer = tracer
        logger = TracingLogger(tracer: tracer, next: log, kinds: ["draft": .aiDraft, "import": .textImport])
        access = TraceAccess(
            isOn: {
                await launch.answered()
                await startup.value
                return launch.gate.isOpen
            },
            reader: store
        )
    }
}

/// Whether the trace records on this launch. A Debug build always records, unless a UI test gives the store's answer;
/// a Release build records only once the store says the app is a verified TestFlight install, and fails closed.
struct TraceLaunchGate: Sendable {
    let gate: any TraceGate
    /// Returns once the gate has the answer it keeps for this launch
    let answered: @Sendable () async -> Void
    /// How the app was installed, as a run names it: `debug`, or the store's answer
    let distribution: @Sendable () -> String

    /// The gate of this launch
    static func current(arguments: [String]) -> TraceLaunchGate {
        #if DEBUG
        if let given = DiagnosticsDistributionOverride.current(arguments: arguments) {
            return asking(given)
        }
        return TraceLaunchGate(gate: ConstantGate(isOpen: true), answered: {}, distribution: { "debug" })
        #else
        return asking(AppTransactionDistribution())
        #endif
    }

    /// A gate that opens once `distribution` says the app is a verified TestFlight install. It asks once, at launch.
    static func asking(_ distribution: any DistributionReading) -> TraceLaunchGate {
        let gate = DistributionGate()
        let answer = Task { await gate.ask(distribution) }
        return TraceLaunchGate(
            gate: gate, answered: { await answer.value }, distribution: { gate.answer?.rawValue ?? "unanswered" }
        )
    }
}

/// The build and the device a run names, so that a report says which app and which device it comes from
struct TraceDevice: Sendable {
    let appVersion: String
    let build: String
    /// The system and its version, such as `iOS 26.5`
    let osVersion: String
    /// The model identifier, such as `iPhone17,1`
    let model: String

    /// This build, on this device
    static var current: TraceDevice {
        let info = Bundle.main.infoDictionary ?? [:]
        let process = ProcessInfo.processInfo
        let version = process.operatingSystemVersion
        let patch = version.patchVersion > 0 ? ".\(version.patchVersion)" : ""
        return TraceDevice(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            build: info["CFBundleVersion"] as? String ?? "unknown",
            osVersion: "\(process.isiOSAppOnMac ? "macOS" : "iOS") \(version.majorVersion).\(version.minorVersion)\(patch)",
            model: process.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine()
        )
    }

    /// The model identifier of the hardware
    private static func machine() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
