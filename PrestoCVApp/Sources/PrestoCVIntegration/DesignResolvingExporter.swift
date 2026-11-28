import PrestoCVDomain
import PrestoCVWorkflowPorts
import CVDesignCatalog
import CVRendering

/// Exports a CV in the look it keeps: its design choice is resolved through the design catalog, then `ExportCVWorkflow`
/// exports with that style (ADR 0007).
/// - A CV that keeps no design exports with the default design. A design the catalog does not have also gives the default
///   design, and nothing else changes: the CV keeps its palette and fonts, as in version 1. A palette or fonts the CV does
///   not name, or that the catalog does not know, give the design's own (`ResolveDesign`).
/// - The app opens before the bundled designs are checked (#566): the export first waits for the verdict of the design it
///   wants, then for the default design's when it falls back, never for the whole check, and never falls back while the
///   design it wants is still being checked.
/// - A default design the store does not have, after its verdict, is `ExportFailure.designsUnavailable`: no design can
///   print the PDF. So is a store that fails once the default design's verdict is that it did not pass, even while the
///   other designs are still checked, and even when a retry takes back the verdict the export was given while the store
///   is read; otherwise a store that fails is `ExportFailure.renderingFailed`. In both cases nothing is rendered. A
///   cancelled task stays a `CancellationError` (R3, R7), even when the store's wait outlives the cancel and then reads
///   or fails: nothing is rendered. The export's own failures pass through unchanged.
public struct DesignResolvingExporter: CVExporting {
    private let resolve: ResolveDesign
    private let designs: CheckedDesigns
    private let renderer: any PDFRendering
    private let inspector: any PDFLayoutInspecting
    private let headings: HeadingsCatalog
    private let policy: ExportPolicy

    public init(store: any DesignStore, designs: CheckedDesigns, renderer: any PDFRendering, inspector: any PDFLayoutInspecting,
                headings: HeadingsCatalog, policy: ExportPolicy) {
        resolve = ResolveDesign(store: store)
        self.designs = designs
        self.renderer = renderer
        self.inspector = inspector
        self.headings = headings
        self.policy = policy
    }

    @concurrent public func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome {
        let look = try await resolved(snapshot.design)
        try Task.checkCancellation()                                   // a store wait can outlive the cancel: render nothing
        let style = DocumentStyle(stylesheet: look.stylesheet, palette: look.palette, fonts: look.fonts)
        let workflow = ExportCVWorkflow(renderer: renderer, inspector: inspector, headings: headings, style: style, policy: policy)
        return try await workflow.export(snapshot, language: language)
    }

    @concurrent private func resolved(_ choice: DesignChoice?) async throws -> ResolvedDesign {
        let defaultDesign = designs.defaultDesign, wanted = choice?.design ?? defaultDesign
        // The default design's verdict as this export was given it: a retry that comes while the store is read takes the
        // verdict back from the designs, not from the export.
        var defaultFailed = false
        do {
            let passed = try await designs.verdict(on: wanted)
            if wanted == defaultDesign { defaultFailed = !passed }
            do {
                return try await resolve(design: wanted, palette: choice?.palette, fonts: choice?.fonts)
            } catch DesignCatalogError.unknownDesign where wanted != defaultDesign {
                try Task.checkCancellation()
                defaultFailed = !(try await designs.verdict(on: defaultDesign))
                return try await resolve(design: defaultDesign, palette: choice?.palette, fonts: choice?.fonts)
            }
        } catch {
            // ADR 0010: cancellation is not a failure. The file store's lock wait ignores the cancel and then times out, so a
            // cancelled task is read from the task, not from the error.
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            if case .unknownDesign? = error as? DesignCatalogError { throw ExportFailure.designsUnavailable }
            let unavailable = defaultFailed || designs.current.didNotPass(defaultDesign)
            throw unavailable ? ExportFailure.designsUnavailable : ExportFailure.renderingFailed
        }
    }
}
