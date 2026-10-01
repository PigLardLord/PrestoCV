import Foundation
import CVDocumentModel
import CVDesignCatalog

/// Implements the catalog's `DesignRenderingGate`: renders a fixture document that exercises every
/// section with the candidate design, and requires the complete text in the PDF. A truncated fixture fails.
///
/// A user can choose any font scheme for a design, and fonts change pagination, so the fixture is rendered under every
/// one: the design's default first, then the others, and the first render that truncates or loses text fails the
/// design. The palette is the design's own default; palettes change colours only, so one is enough.
public struct FixtureRenderingGate: DesignRenderingGate {
    public enum Rejection: Error, Equatable { case truncated, missing([String]), unreadablePDF }
    let renderer: any PDFRendering, inspector: any PDFInspecting, fixture: CVDocument, headings: Headings

    public init(renderer: any PDFRendering, inspector: any PDFInspecting, fixture: CVDocument, headings: Headings) {
        self.renderer = renderer; self.inspector = inspector; self.fixture = fixture; self.headings = headings
    }

    public func verify(_ design: ValidatedDesign) async throws {
        let palette = design.manifest.defaultPalette.palette
        let defaultFonts = design.manifest.defaultFonts
        for fonts in [defaultFonts] + FontScheme.allCases.filter({ $0 != defaultFonts }) {
            let doc = DocumentHTMLBuilder().render(fixture, stylesheet: design.stylesheet, palette: palette, fonts: fonts, headings: headings)
            let pdf = try await renderer.render(html: doc.html, page: .a4)
            guard !pdf.truncated else { throw Rejection.truncated }
            guard let text = inspector.text(of: pdf.data) else { throw Rejection.unreadablePDF }
            let missing = DocumentCompleteness.missing(in: text, expected: doc.textNodes)
            guard missing.isEmpty else { throw Rejection.missing(missing) }
        }
    }
}
