import Foundation
import CVDocumentModel
import CVDesignCatalog

/// Implements the catalog's `DesignRenderingGate`: renders a fixture document that exercises every
/// section with the candidate design, and requires the complete text in the PDF, inside its pages and at a readable
/// size (`GeometricCompleteness`). A truncated fixture fails.
public struct FixtureRenderingGate: DesignRenderingGate {
    /// `outsidePage` and `glyphTooSmall` name the text of the lines at fault, in page order; a line whose glyph height
    /// the inspector cannot read counts as too small.
    public enum Rejection: Error, Equatable { case truncated, missing([String]), unreadablePDF, outsidePage([String]), glyphTooSmall([String]) }
    let renderer: any PDFRendering, inspector: any PDFLayoutInspecting, fixture: CVDocument, headings: Headings, palette: Palette

    public init(renderer: any PDFRendering, inspector: any PDFLayoutInspecting, fixture: CVDocument, headings: Headings, palette: Palette) {
        self.renderer = renderer; self.inspector = inspector; self.fixture = fixture; self.headings = headings; self.palette = palette
    }

    public func verify(_ design: ValidatedDesign) async throws {
        let doc = DocumentHTMLBuilder().render(fixture, stylesheet: design.stylesheet, palette: palette, headings: headings)
        let pdf = try await renderer.render(html: doc.html, page: .a4)
        guard !pdf.truncated else { throw Rejection.truncated }
        guard let text = inspector.text(of: pdf.data), let layout = inspector.layout(of: pdf.data) else { throw Rejection.unreadablePDF }
        let missing = DocumentCompleteness.missing(in: text, expected: doc.textNodes)
        guard missing.isEmpty else { throw Rejection.missing(missing) }
        try Self.check(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight))
    }

    /// Text outside a page is rejected before text that is too small: it cannot be read at any size.
    static func check(_ violations: [GeometryViolation]) throws {
        var outside: [String] = [], tooSmall: [String] = []
        for violation in violations {
            switch violation {
            case .noPage, .noText: throw Rejection.unreadablePDF
            case .outsidePage(_, let text): outside.append(text)
            case .unknownGlyphHeight(_, let text), .glyphTooSmall(_, let text): tooSmall.append(text)
            }
        }
        guard outside.isEmpty else { throw Rejection.outsidePage(outside) }
        guard tooSmall.isEmpty else { throw Rejection.glyphTooSmall(tooSmall) }
    }
}
