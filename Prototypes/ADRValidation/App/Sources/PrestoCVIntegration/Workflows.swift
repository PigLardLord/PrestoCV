import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts
import CVDesignCatalog
import CVRendering

public struct EditCVWorkflow: CVEditing {
    let makeNew: NewCV, saveCV: SaveCV, loadCV: LoadCV
    public init(repository: any CVRepository, ids: any IDGenerator) {
        makeNew = NewCV(ids: ids); saveCV = SaveCV(repository: repository); loadCV = LoadCV(repository: repository)
    }
    public func newCV() -> CV { makeNew() }
    public func save(_ cv: CV) async throws(AuthoringError) -> CV { try await saveCV(cv) }
    public func load(_ id: CVID) async throws(AuthoringError) -> CV { try await loadCV(id) }
}

/// Every export is checked against its own document: the PDF text must contain every field (R8, ADR 0011).
public struct ExportCVWorkflow: CVExporting {
    let renderer: any PDFRendering, inspector: any PDFInspecting, stylesheet: ValidatedStylesheet, palette: Palette
    public init(renderer: any PDFRendering, inspector: any PDFInspecting, stylesheet: ValidatedStylesheet, palette: Palette) {
        self.renderer = renderer; self.inspector = inspector; self.stylesheet = stylesheet; self.palette = palette
    }
    public func export(_ snapshot: CV, language: String) async throws -> ExportOutcome {
        let headings: Headings
        do throws(HeadingsCatalog.Failure) { headings = try HeadingsCatalog.headings(for: language) } catch { throw ExportFailure.unsupportedLanguage }
        let doc = CVToDocumentMapper().map(snapshot, language: language)
        let rendered = DocumentHTMLBuilder().render(doc, stylesheet: stylesheet, palette: palette, headings: headings)
        let pdf = try await renderer.render(html: rendered.html, page: .a4)
        if !pdf.truncated {
            guard let text = inspector.text(of: pdf.data) else { throw ExportFailure.renderingFailed }
            let missing = DocumentCompleteness.missing(in: text, expected: rendered.textNodes)
            guard missing.isEmpty else { throw ExportFailure.incomplete(missing: missing.count) }
        }
        return ExportOutcome(pdf: pdf.data, pageCount: pdf.pageCount, requiredPages: pdf.requiredPages)
    }
}
