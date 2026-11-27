import PrestoCVDomain
import PrestoCVWorkflowPorts
import CVDesignCatalog
import CVRendering

/// Exports a CV in the look it keeps: its design choice is resolved through the design catalog, then `ExportCVWorkflow`
/// exports with that style (ADR 0007).
/// - A CV that keeps no design exports with the default design. A design the catalog does not have also gives the default
///   design, and nothing else changes: the CV keeps its palette and fonts, as in version 1. A palette or fonts the CV does
///   not name, or that the catalog does not know, give the design's own (`ResolveDesign`).
/// - A store that fails, or a default design it does not have, is `ExportFailure.renderingFailed`, and nothing is
///   rendered. A cancelled task stays a `CancellationError` (R3, R7), even when the store's wait outlives the cancel and
///   then reads or fails: nothing is rendered. The export's own failures pass through unchanged.
public struct DesignResolvingExporter: CVExporting {
    private let resolve: ResolveDesign
    private let defaultDesign: String
    private let renderer: any PDFRendering
    private let inspector: any PDFLayoutInspecting
    private let headings: HeadingsCatalog
    private let policy: ExportPolicy

    public init(store: any DesignStore, defaultDesign: String, renderer: any PDFRendering, inspector: any PDFLayoutInspecting,
                headings: HeadingsCatalog, policy: ExportPolicy) {
        resolve = ResolveDesign(store: store)
        self.defaultDesign = defaultDesign
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
        let wanted = choice?.design ?? defaultDesign
        do {
            do {
                return try await resolve(design: wanted, palette: choice?.palette, fonts: choice?.fonts)
            } catch DesignCatalogError.unknownDesign where wanted != defaultDesign {
                try Task.checkCancellation()
                return try await resolve(design: defaultDesign, palette: choice?.palette, fonts: choice?.fonts)
            }
        } catch {
            // ADR 0010: cancellation is not a failure. The file store's lock wait ignores the cancel and then times out, so a
            // cancelled task is read from the task, not from the error.
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            throw ExportFailure.renderingFailed
        }
    }
}
