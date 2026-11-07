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

    private init(inputs: Inputs, rules: WKContentRuleList) {
        let trace = TraceChain(
            directory: inputs.paths.trace, shareDirectory: inputs.paths.traceShare, gate: inputs.gate,
            device: inputs.device, log: inputs.log
        )
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

    static func make(_ inputs: Inputs) async -> CompositionState {
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
        return .ready(Composition(inputs: inputs, rules: rules))
    }

    /// Assembles the app for this launch. A Debug build reads the fixtures its launch arguments ask for; a Release build
    /// has no code that does (`ReleaseHygieneTests`).
    public static func launch(arguments: [String]) async -> CompositionState {
        let device = AppPaths.onDevice()
        let paths: AppPaths
        let gate: TraceLaunchGate
        #if DEBUG
        let fixtures: LaunchFixtures
        do {
            fixtures = try LaunchFixtures.parse(arguments)
        } catch {
            return .failed(CompositionFailure(error))
        }
        paths = fixtures.paths(device: device, fresh: UUID())
        gate = fixtures.distribution.map { .asking(GivenDistribution(given: $0)) } ?? .debug
        do {
            try paths.create()
        } catch {
            return .failed(CompositionFailure(error))
        }
        do {
            try fixtures.writeSeed(into: paths.store)
        } catch {
            return .failed(CompositionFailure(error))
        }
        #else
        paths = device
        gate = .asking(AppTransactionDistribution())
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
            }
        ))
    }
}
