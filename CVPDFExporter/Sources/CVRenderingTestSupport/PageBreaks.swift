import CVRendering

/// What a printed CV's page breaks get wrong (#467), with the page (0 first) and the text that shows it.
public enum PageBreakFault: Sendable, Equatable {
    /// The page's lowest line belongs to a section's start, its title or the head of its first entry: the start ends the
    /// page, and what follows it starts the next one.
    case startSplit(page: Int, line: String)
    /// The page holds no text.
    case blankPage(page: Int)
    /// A line reaches into the page's top or bottom margin: the page's edge cut through it.
    case cut(page: Int, text: String)
    /// The document's text nodes that the PDF's text lacks (`DocumentCompleteness`).
    case missing([String])
    /// Lines outside their page or too small to read (`GeometricCompleteness`).
    case geometry([GeometryViolation])
}

/// Reads page-break faults in the layout a PDF inspector gives: the native renderers' tests print documents whose
/// section titles fall at every height of a page's foot and check each PDF with it.
public enum PageBreaks {
    /// The faults of `layout`, page by page. `starts` are the lines of the sections' starts. A start line matches a line
    /// whatever its case and spacing, since a design may print its titles in capitals or with spaced letters. A line may
    /// reach `GeometricCompleteness.pageTolerance` into a margin of `margin` points, as glyph boxes overhang their line.
    public static func faults(in layout: PDFLayout, starts: [String], margin: Double) -> [PageBreakFault] {
        let startKeys = Set(starts.map(key))
        return layout.pages.indices.flatMap { page -> [PageBreakFault] in
            let lines = layout.lines.filter { $0.pageIndex == page }
            guard let lowest = lines.min(by: { $0.box.y < $1.box.y }) else { return [.blankPage(page: page)] }
            let box = layout.pages[page], tolerance = GeometricCompleteness.pageTolerance
            let cut = lines.filter { $0.box.y < box.y + margin - tolerance || $0.box.maxY > box.maxY - margin + tolerance }
                .map { PageBreakFault.cut(page: page, text: $0.text) }
            return cut + (startKeys.contains(key(lowest.text)) ? [.startSplit(page: page, line: lowest.text)] : [])
        }
    }

    /// Every fault of `document` printed as `layout`, whose text is `text`: the page faults above, the text nodes it
    /// lacks, and the lines `GeometricCompleteness` rejects.
    public static func faults(of document: RenderedDocument, printedAs layout: PDFLayout, text: String, starts: [String],
                              page: PageSetup) -> [PageBreakFault] {
        let missing = DocumentCompleteness.missing(in: text, expected: document.textNodes)
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        return faults(in: layout, starts: starts, margin: page.verticalMarginPoints)
            + (missing.isEmpty ? [] : [.missing(missing)]) + (violations.isEmpty ? [] : [.geometry(violations)])
    }

    private static func key(_ text: String) -> String { text.filter { !$0.isWhitespace }.lowercased() }
}
