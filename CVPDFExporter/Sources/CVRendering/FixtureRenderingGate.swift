import Foundation
import CVDocumentModel
import CVDesignCatalog

/// Implements the catalog's `DesignRenderingGate`: renders a fixture document that exercises every
/// section with the candidate design, and requires the complete text in the PDF. A truncated fixture fails.
public struct FixtureRenderingGate: DesignRenderingGate {
    public enum Rejection: Error, Equatable { case truncated, missing([String]), unreadablePDF }
    let renderer: any PDFRendering, inspector: any PDFInspecting, fixture: CVDocument, headings: Headings, palette: Palette

    public init(renderer: any PDFRendering, inspector: any PDFInspecting, fixture: CVDocument, headings: Headings, palette: Palette) {
        self.renderer = renderer; self.inspector = inspector; self.fixture = fixture; self.headings = headings; self.palette = palette
    }

    public func verify(_ design: ValidatedDesign) async throws {
        let doc = DocumentHTMLBuilder().render(fixture, stylesheet: design.stylesheet, palette: palette, headings: headings)
        let pdf = try await renderer.render(html: doc.html, page: .a4)
        guard !pdf.truncated else { throw Rejection.truncated }
        guard let text = inspector.text(of: pdf.data) else { throw Rejection.unreadablePDF }
        let missing = DocumentCompleteness.missing(in: text, expected: doc.textNodes)
        guard missing.isEmpty else { throw Rejection.missing(missing) }
    }
}
