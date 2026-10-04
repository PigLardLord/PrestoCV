import Foundation
import CVDocumentModel

/// Exports a cover letter as one A4 page (ADR 0019). The letter is built with `LetterHTMLBuilder`, printed by the platform's
/// `PDFRendering`, and the PDF that comes back is read, never trusted: it must be one page, and it must hold every text node
/// the builder produced, as for a CV (R8, ADR 0011). A letter that does not fit is an error, never a page that is cut off.
public struct LetterPDFExport: Sendable {
    public enum Failure: Error, Equatable, Sendable {
        /// The letter needed more than one page.
        case doesNotFitOnOnePage(requiredPages: Int)
        /// The PDF could not be read back.
        case unreadablePDF
        /// Text nodes the PDF does not hold.
        case missing([String])
    }

    /// A4, one page, with the vertical margins every page of the exporter keeps.
    public static let page = PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1)

    private let renderer: any PDFRendering, inspector: any PDFInspecting

    public init(renderer: any PDFRendering, inspector: any PDFInspecting) { self.renderer = renderer; self.inspector = inspector }

    /// The PDF of the letter. Throws `LetterBuildFailure` for a letter that cannot be rendered, `Failure` for a PDF that is
    /// not one complete page, and `CancellationError` when the task is cancelled.
    public func export(_ letter: LetterDocument) async throws -> Data {
        let document = try LetterHTMLBuilder().render(letter)
        let pdf = try await renderer.render(html: document.html, page: Self.page)
        guard let text = inspector.text(of: pdf.data), let pages = inspector.pageCount(of: pdf.data) else { throw Failure.unreadablePDF }
        // The renderer says whether it cut the letter, and the PDF says how many pages it has: either one is enough to refuse.
        guard !pdf.truncated, pages == 1 else { throw Failure.doesNotFitOnOnePage(requiredPages: max(pdf.requiredPages, pages)) }
        let missing = DocumentCompleteness.missing(in: text, expected: document.textNodes)
        guard missing.isEmpty else { throw Failure.missing(missing) }
        return pdf.data
    }
}
