import CVBundledHeadings
import CVRendering
import CVRenderingPDFKitInspector
import CVRenderingWebKitSupport
import DiagnosticLogging
import DiagnosticLoggingOSLog
import DiagnosticTrace
import DiagnosticTraceDistribution
import Foundation
import PrestoCVApplication
import PrestoCVPersistence
import Synchronization
import WebKit
#if os(iOS)
import CVRenderingIOS
#else
import CVRenderingMacOS
#endif

/// How the app was assembled: ready, or failed with the one code the app shows as one error screen. Later steps add the
/// design state to the ready case, so that the app keeps a single switch.
public enum CompositionState {
    case ready(Composition)
    case failed(CompositionFailure)
}

/// The one place that creates infrastructure (R4, ADR 0008): the paths, the repository, the platform renderer over the
/// content rules compiled once, the clock, the ids, the log and the trace. The view model factories follow in later steps.
@MainActor
public final class Composition {
    /// Compiles the content rules of every web view. The composition calls it once, so a test counts the calls.
    typealias CompileRules = @MainActor () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList

    /// What a composition is built from: everything that reaches outside the process comes in here, chosen by `launch`.
    struct Inputs {
        let paths: AppPaths
        let clock: any TimeSource
        let ids: any IDGenerator
        /// The log the entries finally go to
        let log: any DiagnosticLogger
        let gate: TraceLaunchGate
        let device: TraceDevice
        /// The folder of the sample CVs that ship with the app
        let samples: URL
        let compileRules: CompileRules
        /// Returns when a failed launch should stop waiting for the distribution's answer. A failed launch shows its error
        /// screen even while the distribution has not answered (the store may fetch over the network); the purge of a
        /// closed launch then still follows the answer (ADR 0032). The launch chooses it, so a test fires it at once.
        let settleDeadline: @Sendable () async -> Void
        /// What a launch does before the folders are made, such as writing the seed of a UI test. It fails with a code.
        let prepare: @MainActor () throws(CompositionFailure) -> Void
    }

    let paths: AppPaths
    let repository: FileCVRepository
    let inspector: any PDFInspecting
    let headings: HeadingsCatalog
    let samples: any SampleCVSource
    let clock: any TimeSource
    let ids: any IDGenerator
    /// The log of the app: its entries reach the open run of a trace as well
    let logger: any DiagnosticLogger
    let tracer: any DiagnosticTracer
    let traceAccess: TraceAccess
    private let rules: WKContentRuleList

    private init(inputs: Inputs, rules: WKContentRuleList, trace: TraceChain) {
        paths = inputs.paths
        repository = FileCVRepository(directory: inputs.paths.store, clock: inputs.clock)
        inspector = PDFKitInspector()
        headings = HeadingsCatalog(source: BundleHeadingTableSource())
        samples = DirectorySampleCVSource(directory: inputs.samples)
        clock = inputs.clock
        ids = inputs.ids
        logger = trace.logger
        tracer = trace.tracer
        traceAccess = trace.access
        self.rules = rules
    }

    /// The renderer of this platform, over the rules compiled for this composition.
    func makeRenderer() -> any PDFRendering {
        #if os(iOS)
        IOSPDFRenderer(rules: rules)
        #else
        MacPDFRenderer(rules: rules)
        #endif
    }

    /// Assembles the app, or fails with one code. The trace chain starts first, so that its answer and the purge of a
    /// closed launch (ADR 0032) do not depend on the rest. When the assembly fails, `make` waits for the purge only until
    /// `settleDeadline`: the error screen must not wait for a distribution that has not answered. The purge is not brought
    /// forward, it follows the answer on the trace chain's own task, as it does on a launch that succeeds.
    static func make(_ inputs: Inputs) async -> CompositionState {
        let trace = TraceChain(
            directory: inputs.paths.trace, shareDirectory: inputs.paths.traceShare, gate: inputs.gate,
            device: inputs.device, log: inputs.log
        )
        let state = await assemble(inputs, trace: trace)
        if case .failed = state { await first(of: { await trace.settle() }, or: inputs.settleDeadline) }
        return state
    }

    /// Returns when either operation has finished. The one that finishes later is left to end on its own: waiting for a
    /// task's value cannot be cancelled, so a task group would still wait for it.
    private static func first(of work: @escaping @Sendable () async -> Void, or deadline: @escaping @Sendable () async -> Void) async {
        await withCheckedContinuation { (waiting: CheckedContinuation<Void, Never>) in
            let once = Once(waiting)
            Task { await work(); once.resume() }
            Task { await deadline(); once.resume() }
        }
    }

    private static func assemble(_ inputs: Inputs, trace: TraceChain) async -> CompositionState {
        do {
            try inputs.prepare()
        } catch {
            return .failed(error)
        }
        do {
            try inputs.paths.create()
        } catch {
            return .failed(CompositionFailure(error))
        }
        let rules: WKContentRuleList
        do {
            rules = try await inputs.compileRules()
        } catch {
            return .failed(CompositionFailure(error))
        }
        return .ready(Composition(inputs: inputs, rules: rules, trace: trace))
    }

    /// Assembles the app for this launch. A Debug build reads the fixtures its launch arguments ask for; a Release build
    /// has no code that does (`ReleaseHygieneTests`).
    public static func launch(arguments: [String]) async -> CompositionState {
        let device = AppPaths.onDevice()
        let paths: AppPaths
        let gate: TraceLaunchGate
        let prepare: @MainActor () throws(CompositionFailure) -> Void
        #if DEBUG
        // A fixture that cannot be read fails the launch inside `make`, like the other failures, with the device's
        // paths and the Debug gate: nothing was asked for, so nothing is made.
        let fixtures: LaunchFixtures
        let rejected: CompositionFailure?
        do {
            fixtures = try LaunchFixtures.parse(arguments)
            rejected = nil
        } catch {
            fixtures = LaunchFixtures()
            rejected = CompositionFailure(error)
        }
        paths = fixtures.paths(device: device, fresh: UUID())
        gate = fixtures.distribution.map { .asking(GivenDistribution(given: $0)) } ?? .debug
        prepare = { () throws(CompositionFailure) in
            if let rejected { throw rejected }
            do throws(LaunchFixtures.Failure) {
                try fixtures.prepare(paths)
            } catch {
                throw CompositionFailure(error)
            }
        }
        #else
        paths = device
        gate = .asking(AppTransactionDistribution())
        prepare = {}
        #endif
        return await make(Inputs(
            paths: paths,
            clock: SystemTimeSource(),
            ids: UUIDGenerator(),
            log: OSLogDiagnosticLogger(subsystem: "com.PigLardLord.prestocv"),
            gate: gate,
            device: .current,
            samples: (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Samples", isDirectory: true),
            compileRules: { () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList in
                try await SecureWebViewConfiguration.compileRules()
            },
            settleDeadline: {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    // Cancelled: the wait ends at once, as when the time is up
                    return
                }
            },
            prepare: prepare
        ))
    }
}

/// Resumes a continuation the first time it is asked to, and never again.
private final class Once: Sendable {
    private let waiting: Mutex<CheckedContinuation<Void, Never>?>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        waiting = Mutex(continuation)
    }

    func resume() {
        waiting.withLock { continuation in
            continuation?.resume()
            continuation = nil
        }
    }
}
