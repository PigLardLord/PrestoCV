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
import PrestoCVLegacyLeftovers
import PrestoCVIntegration
import PrestoCVPersistence
import PrestoCVPresentation
import PrestoCVTipsStoreKit
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
    /// Gives the gate the sync checks the bundled designs through from the composition's own. A launch gives it back as it
    /// is; in a Debug build a UI test's fixture replaces it.
    typealias WrapGate = @MainActor (any DesignRenderingGate) -> any DesignRenderingGate
    /// Makes what removes the files the released app left, over the launch's log. The composition calls it once, after the
    /// log is made, so a test gives a cleaner it can read.
    typealias MakeLegacyLeftovers = @Sendable (any DiagnosticLogger) -> any LegacyLeftoversCleaning
    /// Makes what listens to the store's tip transactions, over the launch's log. The first launch of a process calls it
    /// once, at its start, and starts what it gets; a retry reuses it. A test gives one that touches no store.
    typealias MakeTips = @Sendable (any DiagnosticLogger) -> any TipsListening

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
        /// The import's file adapter, one for the process (`importFiles(copyFolders:logger:)`): the windows'
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
        /// What removes the files of the released app that hold nothing the person wrote, once its import has gone through
        let legacyLeftovers: MakeLegacyLeftovers
        /// What listens to the store's tip transactions from the launch on
        let makeTips: MakeTips
        /// What the Settings sheet shows about the app, read from its bundle
        let settings: SettingsFactory.Facts
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
    /// Makes the view models of the Settings sheet and its Licences screen.
    public let settings: SettingsFactory
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
    /// What listens to the store's tip transactions: started once at launch, and held for as long as the app runs
    let tips: any TipsListening

    /// What `assemble` made before the composition: the rendering, and the designs with what the export offers.
    private struct Parts {
        let renderer: any PDFRendering
        let inspector: any PDFLayoutInspecting
        let headings: HeadingsCatalog
        let exporter: any CVExporting
        let lookOptions: any LookOptionsProviding
        let languages: [ExportLanguage]
        let exportFiles: ExportFileAdapter
    }

    private init(
        inputs: Inputs, repository: FileCVRepository, legacyImport: LegacyImportAtLaunch, parts: Parts, tips: any TipsListening,
        trace: TraceChain
    ) {
        paths = inputs.paths
        self.tips = tips
        self.repository = repository
        self.legacyImport = legacyImport.outcome
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
        settings = SettingsFactory(facts: inputs.settings, trace: trace.access, tips: tips)
        let importer = ImportCV(
            pdfReader: PDFKitTextExtractor(logger: trace.logger), limits: .standard, logger: trace.logger,
            clock: ContinuousClock(), tracer: trace.tracer
        )
        let importFiles = inputs.importFiles.logging(to: trace.logger)
        screens = ScreenFactory(
            repository: inputs.wrapStore(repository), samples: samples, ids: inputs.ids, clock: inputs.clock,
            editorClock: ContinuousClock(), importer: importer, importFiles: importFiles, exportFiles: parts.exportFiles,
            exporter: parts.exporter, lookOptions: parts.lookOptions, languages: parts.languages,
            languageDetector: DetectedCVLanguage(DetectDocumentLanguage(reader: NaturalLanguageTextReader())),
            wrapListEditing: inputs.wrapListEditing, wrapImport: inputs.wrapImport, backgroundTime: inputs.backgroundTime,
            appLanguage: inputs.appLanguage, legacyImport: legacyImport
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
        // First of all, so that the store's transactions are finished whatever the rest of the launch does: the settlement
        // holds the listener, because a failed launch leaves no composition to hold it. No trace exists yet, so the
        // listener's entries go to the unified log only until a launch has made its trace (`TraceSettlement.tipsLogger`).
        let tips = inputs.settlement.tipsListener(make: { inputs.makeTips(inputs.settlement.tipsLogger(fallback: inputs.log)) })
        do {
            try inputs.check()
        } catch {
            return .failed(error)
        }
        let trace = TraceChain(
            directory: inputs.paths.trace, shareDirectory: inputs.paths.traceShare, gate: inputs.gate,
            device: inputs.device, log: inputs.log, after: inputs.settlement.previous()
        )
        inputs.settlement.record(trace.startup, logger: trace.logger)
        let state = await assemble(inputs, tips: tips, trace: trace)
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

    private static func assemble(_ inputs: Inputs, tips: any TipsListening, trace: TraceChain) async -> CompositionState {
        do {
            try inputs.prepare()
        } catch {
            return .failed(error)
        }
        do {
            try await inputs.paths.create()
        } catch {
            return .failed(CompositionFailure(error))
        }
        let repository = FileCVRepository(directory: inputs.paths.store, clock: inputs.clock)
        let importer = ImportLegacyStore(source: inputs.legacyStore, target: repository)
        let outcome = await importLegacy(with: importer)
        await cleanLeftovers(after: outcome, with: inputs.legacyLeftovers(trace.logger))
        let legacyImport = LegacyImportAtLaunch(
            outcome: outcome, review: LegacyImportReview(outcome: outcome, importer: importer),
            reminder: LegacyReportMarker(file: inputs.paths.legacyReportOff)
        )
        let rules: WKContentRuleList
        do {
            rules = try await inputs.compileRules()
        } catch {
            return .failed(CompositionFailure(error))
        }
        do {
            let parts = try await rendering(inputs, rules: rules, logger: trace.logger)
            return .ready(Composition(
                inputs: inputs, repository: repository, legacyImport: legacyImport, parts: parts, tips: tips, trace: trace
            ))
        } catch {
            return .failed(error)
        }
    }

    /// Moves the CVs of the released app's store into the new store before any screen reads it, so the first-run decision
    /// sees them. A run that fails does not stop the launch: the legacy files stay, and the next launch runs again.
    private static func importLegacy(with importer: ImportLegacyStore) async -> LegacyImportOutcome {
        do throws(RepositoryError) {
            return .ran(try await importer.run())
        } catch {
            return .failed(error)
        }
    }

    /// Removes what the released app left that holds nothing the person wrote, after an import that ran with nothing left
    /// out: no file failed, and the store was not erased. After a failed import, or one with a failure, nothing is removed,
    /// and the next launch decides again. The removals run off the main actor (R19), and nothing reads them: the launch goes
    /// on when they end.
    static func cleanLeftovers(after outcome: LegacyImportOutcome, with cleaner: any LegacyLeftoversCleaning) async {
        guard case .ran(let report) = outcome, report.failures.isEmpty, !report.storeErased else { return }
        await cleaner.clean()
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
        let (gateHeadings, languages) = try await read(headings, gate: GateFixture.document.language)
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
            languages: languages.compactMap(ExportLanguage.init),
            exportFiles: await exportFiles(root: inputs.paths.exportShare, logger: logger)
        )
    }

    /// The headings the gate renders with, in `language`, and the languages a PDF can be written in. Reading and decoding
    /// the tables waits for the file system, so it runs off the main actor (R19) while the app shows that it is loading.
    @concurrent nonisolated static func read(
        _ headings: HeadingsCatalog, gate language: String
    ) async throws(CompositionFailure) -> (gate: Headings, languages: [String]) {
        do throws(HeadingsCatalog.Failure) {
            return (try headings.headings(for: language), try headings.supportedLanguages())
        } catch {
            throw CompositionFailure(error)
        }
    }

    /// The export's file adapter. Making it removes the PDFs an earlier launch left to share, which waits for the file
    /// system, so it is made off the main actor (R19).
    @concurrent private nonisolated static func exportFiles(root: URL, logger: any DiagnosticLogger) async -> ExportFileAdapter {
        ExportFileAdapter(root: root, logger: logger)
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
        let wrapGate: WrapGate
        let makeTips: MakeTips
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let bundled = resources.appendingPathComponent("Samples", isDirectory: true)
        let samples: URL
        let legacy: URL
        let leftovers: LegacyLeftoverPaths
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
        leftovers = fixtures.legacyLeftovers(device: AppPaths.legacyLeftoversOnDevice(), paths: paths)
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
        wrapGate = { fixtures.designGate($0) }
        makeTips = { logger in
            guard let given = fixtures.tips else { return StoreKitTips(logger: logger) }
            return GivenTips(given: given)
        }
        // Before `make` starts the trace chain, whose closed gate purges the folder. A folder that fails its check is
        // left alone here, and `make` fails the launch through `check`.
        if rejected == nil, fixtures.passesCheck(paths) {
            await fixtures.seedTrace(into: paths)
        }
        #else
        paths = device
        gate = .asking(AppTransactionDistribution())
        samples = bundled
        legacy = AppPaths.legacyStoreOnDevice()
        leftovers = AppPaths.legacyLeftoversOnDevice()
        check = {}
        prepare = {}
        wrapListEditing = { $0 }
        sharesWithStandIn = false
        wrapStore = { $0 }
        wrapImport = { $0 }
        wrapGate = { $0 }
        makeTips = { StoreKitTips(logger: $0) }
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
                wrapGate(
                    FixtureRenderingGate(renderer: renderer, inspector: inspector, fixture: GateFixture.document, headings: headings)
                )
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
            legacyStore: DirectoryLegacyStore(directory: legacy, clock: SystemTimeSource()),
            legacyLeftovers: { LegacyLeftoversAdapter(paths: leftovers, logger: $0) },
            makeTips: makeTips,
            settings: bundledSettings()
        ))
        #if DEBUG
        if case .ready(let composition) = state { composition.openedFile = fixtures.openedFileFixture(in: resources) }
        // A launch with the invented runs returns once its trace has settled, so that a UI test that sees the first screen
        // knows what the gate did with them: a closed gate has purged them. The fixture's distribution answers at once.
        if fixtures.storesTraceRuns { await settlement.previous()?.value }
        #endif
        return state
    }

    /// The inbox of a window's files opened from another app. It holds a file waiting for the window's shell through the
    /// process's import file adapter, and lets go, as the import does, a file that never reaches the shell. The adapter's
    /// log here is the system's log only: a window can be handed a file before any composition, and its trace, exists.
    public static func makeOpenedFileInbox() -> OpenedFileInbox {
        OpenedFileInbox(files: deviceImportFiles)
    }

    /// The import's file adapter over the device's file system, deleting copies only in `copyFolders`, and only those
    /// this run received. Made once for the process.
    nonisolated static func importFiles(copyFolders: [URL], logger: any DiagnosticLogger) -> ImportFileAdapter {
        ImportFileAdapter(
            files: SystemImportFiles(), copyFolders: copyFolders,
            maximumBytes: ImportLimits.standard.maximumPDFBytes, logger: logger
        )
    }

    /// The process's import file adapter, made at its first use: the first window's inbox, before any file is handed to
    /// the app.
    private nonisolated static let deviceImportFiles = importFiles(
        copyFolders: AppPaths.importCopiesOnDevice(),
        logger: OSLogDiagnosticLogger(subsystem: "com.PigLardLord.prestocv")
    )

    /// What the Settings sheet shows about this build: its name, version and build from the bundle, the fixed addresses of
    /// the site, and the notices file the bundle holds.
    private static func bundledSettings() -> SettingsFactory.Facts {
        let info = Bundle.main.infoDictionary ?? [:]
        let notices = (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Licences.json")
        return SettingsFactory.Facts(
            supportAddress: "support@prestocv.app",
            privacyPolicy: URL(string: "https://prestocv.app/privacy.html"),
            sourceCode: URL(string: "https://prestocv.app/source.html"),
            version: info["CFBundleShortVersionString"] as? String ?? "",
            build: info["CFBundleVersion"] as? String ?? "",
            appName: info["CFBundleDisplayName"] as? String ?? "PrestoCV",
            notices: { try await readNotices(at: notices) }
        )
    }

    /// The bytes of the notices file, read off the main actor (R19): the Settings sheet waits for them.
    @concurrent private nonisolated static func readNotices(at url: URL) async throws -> Data {
        try Data(contentsOf: url)
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
