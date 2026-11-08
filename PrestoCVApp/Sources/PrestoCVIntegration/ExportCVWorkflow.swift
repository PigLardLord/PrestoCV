import Foundation
import PrestoCVDomain
import PrestoCVWorkflowPorts
import CVDocumentModel
import CVDesignCatalog
import CVRendering

/// How the document looks: the validated stylesheet of a design, a palette and a font scheme. Resolving the CV's
/// design choice into these is the job of the design catalog (step 3-4); the workflow takes the result.
public struct DocumentStyle: Sendable {
    public let stylesheet: ValidatedStylesheet, palette: Palette, fonts: FontScheme
    public init(stylesheet: ValidatedStylesheet, palette: Palette, fonts: FontScheme) {
        self.stylesheet = stylesheet; self.palette = palette; self.fonts = fonts
    }
}

/// Exports a snapshot of a CV as a PDF (ADR 0007, ADR 0011). Every export is checked against its own document: the text
/// of the PDF must hold every text the document has, and every line must be visible: inside its page and at least
/// `GeometricCompleteness.minimumGlyphHeight` high (R8, #80). The outcome says when the PDF is shorter than the CV needs.
/// A link the exporter would not print as it is makes the export fail (`invalidDocument`) instead of vanishing from the PDF.
/// Failures are `ExportFailure`, including any error of the renderer; a cancelled task stays a `CancellationError` (R3, R7).
public struct ExportCVWorkflow: CVExporting {
    private let renderer: any PDFRendering
    private let inspector: any PDFLayoutInspecting
    private let headings: HeadingsCatalog
    private let style: DocumentStyle
    private let policy: ExportPolicy
    private let mapper = CVToDocumentMapper()

    public init(renderer: any PDFRendering, inspector: any PDFLayoutInspecting, headings: HeadingsCatalog, style: DocumentStyle,
                policy: ExportPolicy) {
        self.renderer = renderer; self.inspector = inspector; self.headings = headings; self.style = style; self.policy = policy
    }

    public func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome {
        let personal = snapshot.personal
        let readiness = ExportReadiness(name: personal.fullName, email: personal.email?.value ?? "", phone: personal.phone?.value ?? "")
        guard readiness.canExport else { throw ExportFailure.notReady }
        let words = try headingsFor(language)
        let document = mapper.map(snapshot, language: language)
        do { try CVDocumentValidator.validate(document) } catch { throw ExportFailure.invalidDocument }
        guard DocumentLinks.unprintable(in: document).isEmpty else { throw ExportFailure.invalidDocument }   // never drop a link silently
        let rendered = DocumentHTMLBuilder().render(document, stylesheet: style.stylesheet, palette: style.palette,
                                                    fonts: style.fonts, headings: words)
        let pdf: RenderedPDF
        do { pdf = try await renderer.render(html: rendered.html, page: page) } catch is CancellationError {
            throw CancellationError()                                  // ADR 0010: cancellation is not a failure
        } catch { throw ExportFailure.renderingFailed }
        if !pdf.truncated {
            guard let text = inspector.text(of: pdf.data) else { throw ExportFailure.renderingFailed }
            let missing = DocumentCompleteness.missing(in: text, expected: rendered.textNodes)
            guard missing.isEmpty else { throw ExportFailure.incomplete(missing: missing.count) }
            guard let layout = inspector.layout(of: pdf.data) else { throw ExportFailure.renderingFailed }   // fail closed
            let hidden = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
            guard hidden.isEmpty else { throw ExportFailure.textNotVisible(lines: hidden.count) }
        }
        return ExportOutcome(pdf: pdf.data, pageCount: pdf.pageCount, requiredPages: pdf.requiredPages)
    }

    private var page: PageSetup {
        PageSetup(widthPoints: policy.pageWidth, heightPoints: policy.pageHeight, maxPages: policy.maxPages,
                  verticalMarginPoints: policy.margin)
    }

    private func headingsFor(_ language: DocumentLanguage) throws(ExportFailure) -> Headings {
        do { return try headings.headings(for: language.tag) } catch {
            switch error {
            case .unsupportedLanguage: throw .unsupportedLanguage
            case .incomplete, .corruptTable: throw .renderingFailed
            }
        }
    }
}
