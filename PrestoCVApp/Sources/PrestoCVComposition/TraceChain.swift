import DiagnosticLogging
import DiagnosticTrace
import DiagnosticTraceFiles
import Foundation

/// The trace of a test build (ADR 0032), as the composition builds it: the log entries go to the open run of their kind as
/// well, and every run goes through the gate to a recorder that keeps it in the store. A launch whose gate stays closed
/// purges what an earlier install stored. Only the composition builds it, so no other code can turn the trace on or reach
/// its files (`compositionOnly` in the checker's rules).
struct TraceChain {
    /// The trace the import and the AI draft record into
    let tracer: any DiagnosticTracer
    /// The log the import and the AI draft write to
    let logger: any DiagnosticLogger
    /// Whether the trace records on this launch, and the runs it stored
    let access: TraceAccess
    private let startup: Task<Void, Never>

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
        startup = Task {
            await launch.answered()
            if !launch.gate.isOpen { await store.purge() }
        }
        let startup = startup
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

    /// Returns once the gate has answered and a closed launch has purged. The composition awaits it when it fails, so that
    /// the error screen never leaves the traces of an earlier install behind.
    func settle() async {
        await startup.value
    }
}

/// Whether the trace records on this launch, and the runs it stored: what the diagnostics screen reads.
struct TraceAccess: Sendable {
    /// Whether the trace records on this launch, once the build has its answer
    let isOn: @Sendable () async -> Bool
    /// The stored runs, and the copies of their files to share
    let reader: any TraceReading
}

/// Whether the trace records on this launch. A Debug build always records, unless a UI test gives the store's answer;
/// a Release build records only once the store says the app is a verified TestFlight install, and fails closed.
struct TraceLaunchGate: Sendable {
    let gate: any TraceGate
    /// Returns once the gate has the answer it keeps for this launch
    let answered: @Sendable () async -> Void
    /// How the app was installed, as a run names it: `debug`, or the store's answer
    let distribution: @Sendable () -> String

    #if DEBUG
    /// The gate of a Debug build: always open, and it asks nothing.
    static let debug = TraceLaunchGate(gate: ConstantGate(isOpen: true), answered: {}, distribution: { "debug" })
    #endif

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
