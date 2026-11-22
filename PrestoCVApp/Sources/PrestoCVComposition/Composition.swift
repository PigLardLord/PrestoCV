import CVBundledDesigns
import CVBundledHeadings
import CVDesignCatalog
import CVDesignCatalogFileStore
import CVRendering
import CVRenderingPDFKitInspector
import CVRenderingWebKitSupport
import DiagnosticLogging
import DiagnosticLoggingOSLog
import DiagnosticTrace
import DiagnosticTraceDistribution
import Foundation
import PrestoCVApplication
import PrestoCVApplicationNaturalLanguage
import PrestoCVDomain
import PrestoCVExportFiles
import PrestoCVImportFiles
import PrestoCVImporting
import PrestoCVImportingPDFKit
import PrestoCVIntegration
import PrestoCVPersistence
import PrestoCVPresentation
import PrestoCVWorkflowPorts
import Synchronization
import WebKit
#if os(iOS)
import CVRenderingIOS
#else
import CVRenderingMacOS
#endif

/// How the app was assembled: ready, or failed with the one code the app shows as one error screen. The designs are part
/// of the assembly, so the app keeps a single switch.
public enum CompositionState: Sendable {
    case ready(Composition)
    case failed(CompositionFailure)
}

/// The one place that creates infrastructure (R4, ADR 0008): the paths, the repository, the platform renderer over the
/// content rules compiled once, the design store with the bundled designs synced into it, the import's PDF reader and
/// file port, the reader of a text's language, the clock, the ids, the log and the trace.
@MainActor
public final class Composition {
    /// Compiles the content rules of every web view. The composition calls it once, so a test counts the calls.
    typealias CompileRules = @MainActor () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList
    /// Makes the gate that renders a bundled design before the sync saves it, over the composition's one renderer,
    /// inspector and headings. The composition calls it once, so a test counts the calls.
    typealias MakeGate = @MainActor (any PDFRendering, any PDFLayoutInspecting, Headings) -> any DesignRenderingGate
    /// Gives the editing the list uses from the one the screens share. A launch gives it back as it is; in a Debug build a UI
    /// test's fixture wraps it.
    typealias WrapListEditing = @MainActor (any CVEditing) -> any CVEditing
    /// Gives the store the screens write through from the composition's own. A launch gives it back as it is; in a Debug
    /// build a UI test's fixture wraps it.
    typealias WrapStore = @MainActor (any CVRepository) -> any CVRepository
    /// Gives the import the screens read through from the workflow. A launch gives it back as it is; in a Debug build a UI
    /// test's fixture replaces it.
    typealias WrapImport = @MainActor (any CVImporting) -> any CVImporting

    /// What a composition is built from: everything that reaches outside the process comes in here, chosen by `launch`.
    struct Inputs {
        let paths: AppPaths
        let clock: any TimeSource
        let ids: any IDGenerator
        /// The log the entries finally go to
        let log: any DiagnosticLogger
        let gate: TraceLaunchGate
        let device: TraceDevice
        /// Where the trace of the launches before this one stands: this launch's trace waits for them
        let settlement: TraceSettlement
        /// The folder of the sample CVs that ship with the app
        let samples: URL
        /// The import's file adapter, one for the process (`importFiles(copyFolders:record:logger:)`): the windows'
        /// inboxes and the screens hold the files opened in the app through it, so a copy goes only when none of them
        /// holds it. It deletes a copy only when it lies directly in one of the folders where the system puts the copy of a
        /// file opened in the app, and never a file the person chose where it is. The composition gives it its own log.
        let importFiles: ImportFileAdapter
        let compileRules: CompileRules
        /// The designs that ship with the app, synced into the design store at every launch
        let designs: any BundledDesignSource
        let makeGate: MakeGate
        /// Returns when a failed launch should stop waiting for the distribution's answer. A failed launch shows its error
        /// screen even while the distribution has not answered (the store may fetch over the network); the purge of a
        /// closed launch then still follows the answer (ADR 0032). The launch chooses it, so a test fires it at once.
        let settleDeadline: @Sendable () async -> Void
        /// Checks, without making or removing anything, that the launch's paths are safe to use, such as the folder of a UI
        /// test. It runs before the trace chain starts, because a closed launch purges the trace folder: a path it refuses
        /// is never purged through. It fails with a code.
        let check: @MainActor () throws(CompositionFailure) -> Void
        /// What a launch does before the folders are made, such as writing the seed of a UI test. It fails with a code.
        let prepare: @MainActor () throws(CompositionFailure) -> Void
        let wrapListEditing: WrapListEditing
        let wrapStore: WrapStore
        let wrapImport: WrapImport
        /// The time the system grants to end the writes once the app leaves the foreground: the app's platform layer
        /// gives it, since asking for it is the app's own (UIKit on iOS).
        let backgroundTime: any BackgroundTime
        /// The language of the app, which the export sheets offer first when a CV holds none.
        let appLanguage: ExportLanguage
        /// True when a share opens the stand-in of the system's share sheet: only a Debug build's launch argument sets it
        /// (`LaunchFixtures`), for the UI tests.
        let sharesWithStandIn: Bool
        /// The store of the released app, whose CVs the launch moves into the new store before any screen reads it
        let legacyStore: any LegacyStore
    }

    let paths: AppPaths
    let repository: FileCVRepository
    /// The platform renderer over the rules compiled for this composition: the one every export and the gate render with
    let renderer: any PDFRendering
    let inspector: any PDFLayoutInspecting
    let headings: HeadingsCatalog
    let samples: any SampleCVSource
    let clock: any TimeSource
    let ids: any IDGenerator
    /// The log of the app: its entries reach the open run of a trace as well
    let logger: any DiagnosticLogger
    let tracer: any DiagnosticTracer
    let traceAccess: TraceAccess
    /// Makes the view models of the screens over this composition's repository, clock and ids.
    public let screens: ScreenFactory
    /// True when a share should open the stand-in of the system's share sheet, which a UI test can read and answer. It is
    /// true only in a Debug build launched with `-PrestoCVNextShareStandIn`; a Release build has no code that sets it.
    public let sharesWithStandIn: Bool
    /// What the import of the released app's store did at this launch, before any screen read the store
    public let legacyImport: LegacyImportOutcome
    #if DEBUG
    /// The PDF of the bundle a window is handed each time it becomes active, as if another app opened it there; nil
    /// unless a Debug build was launched with `-PrestoCVNextOpenedFile`. A Release build has no such member.
    public private(set) var openedFile: OpenedFileFixture?
    #endif

    /// What `assemble` made before the composition: the rendering, and the designs with what the export offers.
    private struct Parts {
        let renderer: any PDFRendering
        let inspector: any PDFLayoutInspecting
        let headings: HeadingsCatalog
        let exporter: any CVExporting
        let lookOptions: any LookOptionsProviding
        let languages: [ExportLanguage]
    }

    private init(
        inputs: Inputs, repository: FileCVRepository, legacyImport: LegacyImportOutcome, parts: Parts, trace: TraceChain
    ) {
        paths = inputs.paths
        self.repository = repository
        self.legacyImport = legacyImport
        renderer = parts.renderer
        inspector = parts.inspector
        headings = parts.headings
        samples = DirectorySampleCVSource(directory: inputs.samples)
        clock = inputs.clock
        ids = inputs.ids
        logger = trace.logger
        tracer = trace.tracer
        traceAccess = trace.access
        sharesWithStandIn = inputs.sharesWithStandIn
        let importer = ImportCV(
            pdfReader: PDFKitTextExtractor(logger: trace.logger), limits: .standard, logger: trace.logger,
            clock: ContinuousClock(), tracer: trace.tracer
        )
        let exportFiles = ExportFileAdapter(root: inputs.paths.exportShare, logger: trace.logger)
        let importFiles = inputs.importFiles.logging(to: trace.logger)
        screens = ScreenFactory(
            repository: inputs.wrapStore(repository), samples: samples, ids: inputs.ids, clock: inputs.clock,
            editorClock: ContinuousClock(), importer: importer, importFiles: importFiles, exportFiles: exportFiles,
            exporter: parts.exporter, lookOptions: parts.lookOptions, languages: parts.languages,
            languageDetector: DetectDocumentLanguage(reader: NaturalLanguageTextReader()),
            wrapListEditing: inputs.wrapListEditing, wrapImport: inputs.wrapImport, backgroundTime: inputs.backgroundTime,
            appLanguage: inputs.appLanguage
        )
    }

    /// The renderer of this platform, over the rules compiled for this composition.
    private static func renderer(rules: WKContentRuleList) -> any PDFRendering {
        #if os(iOS)
        IOSPDFRenderer(rules: rules)
        #else
        MacPDFRenderer(rules: rules)
        #endif
    }

    /// Assembles the app, or fails with one code. The paths are checked first: paths that fail their check fail the launch
    /// before anything is made, and the trace chain never starts, so nothing is purged through them. Then the trace chain
    /// starts, so that its answer and the purge of a closed launch (ADR 0032) do not depend on the rest. When the assembly
    /// fails after that, `make` waits for the purge only until `settleDeadline`: the error screen must not wait for a
    /// distribution that has not answered. The purge is not brought forward, it follows the answer on the trace chain's own
    /// task, as it does on a launch that succeeds. A launch after a failure puts its trace behind the earlier launch's
    /// (`TraceSettlement`): it records nothing until the earlier purge has ended, so a retry never loses what it wrote.
    static func make(_ inputs: Inputs) async -> CompositionState {
        do {
            try inputs.check()
        } catch {
            return .failed(error)
        }
        let trace = TraceChain(
            directory: inputs.paths.trace, shareDirectory: inputs.paths.traceShare, gate: inputs.gate,
            device: inputs.device, log: inputs.log, after: inputs.settlement.previous()
        )
        inputs.settlement.record(trace.startup)
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
        let repository = FileCVRepository(directory: inputs.paths.store, clock: inputs.clock)
        let legacyImport = await importLegacy(from: inputs.legacyStore, into: repository)
        let rules: WKContentRuleList
        do {
            rules = try await inputs.compileRules()
        } catch {
            return .failed(CompositionFailure(error))
        }
        do {
            let parts = try await rendering(inputs, rules: rules, logger: trace.logger)
            return .ready(Composition(inputs: inputs, repository: repository, legacyImport: legacyImport, parts: parts, trace: trace))
        } catch {
            return .failed(error)
        }
    }

    /// Moves the CVs of the released app's store into the new store before any screen reads it, so the first-run decision
    /// sees them. A run that fails does not stop the launch: the legacy files stay, and the next launch runs again.
    private static func importLegacy(from source: any LegacyStore, into store: FileCVRepository) async -> LegacyImportOutcome {
        do throws(RepositoryError) {
            return .ran(try await ImportLegacyStore(source: source, target: store).run())
        } catch {
            return .failed(error)
        }
    }

    /// Makes the one renderer, inspector and headings, syncs the bundled designs into the design store through a gate
    /// over them (`DesignBootstrap`), then makes the exporter and the look options over the store, and reads the
    /// languages a PDF can be written in. The headings are read before anything renders.
    private static func rendering(
        _ inputs: Inputs, rules: WKContentRuleList, logger: any DiagnosticLogger
    ) async throws(CompositionFailure) -> Parts {
        let renderer = renderer(rules: rules)
        let inspector = PDFKitInspector()
        let headings = HeadingsCatalog(source: BundleHeadingTableSource())
        let gateHeadings: Headings
        let languages: [String]
        do throws(HeadingsCatalog.Failure) {
            gateHeadings = try headings.headings(for: GateFixture.document.language)
            languages = try headings.supportedLanguages()
        } catch {
            throw CompositionFailure(error)
        }
        let store = FileDesignStore(directory: inputs.paths.designs, validator: DesignPackageValidator(), lockWait: .standard)
        let designs = try await DesignBootstrap(
            store: store, source: inputs.designs, gate: inputs.makeGate(renderer, inspector, gateHeadings), logger: logger,
            clock: ContinuousClock()
        ).run()
        return Parts(
            renderer: renderer,
            inspector: inspector,
            headings: headings,
            exporter: DesignResolvingExporter(
                store: store, defaultDesign: DesignBootstrap.defaultDesign, renderer: renderer, inspector: inspector,
                headings: headings, policy: .standard
            ),
            lookOptions: CatalogLookOptions(installed: designs.installed, defaultDesign: designs.defaultDesign),
            languages: languages.compactMap(ExportLanguage.init)
        )
    }

    /// Assembles the app for this launch. A Debug build reads the fixtures its launch arguments ask for; a Release build
    /// has no code that does (`ReleaseHygieneTests`).
    /// - Parameter backgroundTime: The time the system grants to end the writes once the app leaves the foreground,
    ///   which the app's platform layer asks for.
    public static func launch(
        arguments: [String], settlement: TraceSettlement, backgroundTime: any BackgroundTime
    ) async -> CompositionState {
        let device = AppPaths.onDevice()
        let paths: AppPaths
        let gate: TraceLaunchGate
        let check: @MainActor () throws(CompositionFailure) -> Void
        let prepare: @MainActor () throws(CompositionFailure) -> Void
        let wrapListEditing: WrapListEditing
        let sharesWithStandIn: Bool
        let wrapStore: WrapStore
        let wrapImport: WrapImport
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let bundled = resources.appendingPathComponent("Samples", isDirectory: true)
        let samples: URL
        let legacy: URL
        #if DEBUG
        // A fixture that cannot be read, or a fixture folder that fails its check, fails the launch inside `make` before
        // the trace chain starts: nothing is made, and nothing is purged.
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
        samples = fixtures.samples(bundled: bundled, paths: paths)
        legacy = fixtures.legacyStore(device: AppPaths.legacyStoreOnDevice(), paths: paths)
        check = { () throws(CompositionFailure) in
            if let rejected { throw rejected }
            do throws(LaunchFixtures.Failure) {
                try fixtures.check(paths)
            } catch {
                throw CompositionFailure(error)
            }
        }
        prepare = { () throws(CompositionFailure) in
            do throws(LaunchFixtures.Failure) {
                try fixtures.prepare(paths)
            } catch {
                throw CompositionFailure(error)
            }
        }
        wrapListEditing = { fixtures.listEditing($0) }
        sharesWithStandIn = fixtures.sharesWithStandIn
        wrapStore = { fixtures.store($0) }
        wrapImport = { fixtures.importing($0) }
        #else
        paths = device
        gate = .asking(AppTransactionDistribution())
        samples = bundled
        legacy = AppPaths.legacyStoreOnDevice()
        check = {}
        prepare = {}
        wrapListEditing = { $0 }
        sharesWithStandIn = false
        wrapStore = { $0 }
        wrapImport = { $0 }
        #endif
        let state = await make(Inputs(
            paths: paths,
            clock: SystemTimeSource(),
            ids: UUIDGenerator(),
            log: OSLogDiagnosticLogger(subsystem: "com.PigLardLord.prestocv"),
            gate: gate,
            device: .current,
            settlement: settlement,
            samples: samples,
            importFiles: deviceImportFiles,
            compileRules: { () async throws(SecureWebViewConfiguration.Failure) -> WKContentRuleList in
                try await SecureWebViewConfiguration.compileRules()
            },
            designs: BundleDesignSource(),
            makeGate: { renderer, inspector, headings in
                FixtureRenderingGate(renderer: renderer, inspector: inspector, fixture: GateFixture.document, headings: headings)
            },
            settleDeadline: {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    // Cancelled: the wait ends at once, as when the time is up
                    return
                }
            },
            check: check,
            prepare: prepare,
            wrapListEditing: wrapListEditing,
            wrapStore: wrapStore,
            wrapImport: wrapImport,
            backgroundTime: backgroundTime,
            appLanguage: .preferred(Bundle.main.preferredLocalizations),
            sharesWithStandIn: sharesWithStandIn,
            legacyStore: DirectoryLegacyStore(directory: legacy, clock: SystemTimeSource())
        ))
        #if DEBUG
        if case .ready(let composition) = state { composition.openedFile = fixtures.openedFileFixture(in: resources) }
        #endif
        return state
    }

    /// The inbox of a window's files opened from another app. It holds a file waiting for the window's shell through the
    /// process's import file adapter, and lets go, as the import does, a file that never reaches the shell. The adapter's
    /// log here is the system's log only: a window can be handed a file before any composition, and its trace, exists.
    public static func makeOpenedFileInbox() -> OpenedFileInbox {
        OpenedFileInbox(files: deviceImportFiles)
    }

    /// The import's file adapter over the device's file system, deleting copies only in `copyFolders`. Made once for the
    /// process: when it is made, it deletes the copies an earlier run left in the copy folders, those the last launch's
    /// record at `record` names too.
    nonisolated static func importFiles(copyFolders: [URL], record: URL, logger: any DiagnosticLogger) -> ImportFileAdapter {
        ImportFileAdapter(
            files: SystemImportFiles(), copyFolders: copyFolders,
            maximumBytes: ImportLimits.standard.maximumPDFBytes, record: record, logger: logger
        )
    }

    /// The process's import file adapter, made at its first use: the first window's inbox, before any file is handed to
    /// the app.
    private nonisolated static let deviceImportFiles = importFiles(
        copyFolders: AppPaths.importCopiesOnDevice(),
        record: AppPaths.onDevice().importCopiesRecord,
        logger: OSLogDiagnosticLogger(subsystem: "com.PigLardLord.prestocv")
    )
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
