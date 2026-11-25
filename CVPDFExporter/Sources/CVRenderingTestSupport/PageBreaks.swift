import CVRendering

/// What a printed CV's page breaks get wrong (#467), with the page (0 first) and the text that shows it.
public enum PageBreakFault: Sendable, Equatable {
    /// The lowest line the page shows belongs to a section's start, its title or the head of its first entry: the start
    /// ends the page, and what follows it starts the next one.
    case startSplit(page: Int, line: String)
    /// The page shows no text.
    case blankPage(page: Int)
    /// A line the page shows reaches into its top or bottom margin: the page's edge cut through it.
    case cut(page: Int, text: String)
    /// A line lies wholly in the page's top or bottom margin, where the page is clipped, and the neighbouring page does not
    /// print it in its place: no page shows it.
    case hidden(page: Int, text: String)
    /// The document's text nodes that the PDF's text lacks (`DocumentCompleteness`).
    case missing([String])
    /// Expected text nodes that more visible lines print than the document holds: duplicated content.
    case duplicated([String])
    /// Lines outside their page or too small to read (`GeometricCompleteness`).
    case geometry([GeometryViolation])
}

/// Reads page-break faults in the layout a PDF inspector gives: the native renderers' tests print documents whose
/// section titles fall at every height of a page's foot and check each PDF with it.
public enum PageBreaks {
    /// The faults of `layout`, page by page. `starts` are the lines of the sections' starts. A start line matches a line
    /// whatever its case and spacing, since a design may print its titles in capitals or with spaced letters. A line may
    /// reach `GeometricCompleteness.pageTolerance` into a margin of `margin` points, as glyph boxes overhang their line.
    ///
    /// The renderers clip each page to the area between its margins, and WebKit also paints into a page the first line of
    /// the next page, or the last line of the previous one, when that line touches the page's edge. The PDF text holds
    /// that copy, wholly in a margin, though the page does not show it (#467). A line wholly in a margin is such a copy
    /// when the neighbouring page prints it one page further, in the same place; else it is hidden. The page's foot is the
    /// lowest line the page shows.
    public static func faults(in layout: PDFLayout, starts: [String], margin: Double) -> [PageBreakFault] {
        let startKeys = Set(starts.map(key)), tolerance = GeometricCompleteness.pageTolerance
        return layout.pages.indices.flatMap { page -> [PageBreakFault] in
            let box = layout.pages[page], lines = layout.lines.filter { $0.pageIndex == page }
            let inMargin = { (line: PDFTextLine) in line.box.maxY <= box.y + margin || line.box.y >= box.maxY - margin }
            let hidden = lines.filter { inMargin($0) && !printedElsewhere($0, from: box, in: layout, margin: margin) }
                .map { PageBreakFault.hidden(page: page, text: $0.text) }
            let shown = lines.filter { !inMargin($0) }
            guard let lowest = shown.min(by: { $0.box.y < $1.box.y }) else { return hidden + [.blankPage(page: page)] }
            let cut = shown.filter { $0.box.y < box.y + margin - tolerance || $0.box.maxY > box.maxY - margin + tolerance }
                .map { PageBreakFault.cut(page: page, text: $0.text) }
            return cut + hidden + (startKeys.contains(key(lowest.text)) ? [.startSplit(page: page, line: lowest.text)] : [])
        }
    }

    /// Whether `line`, wholly in a margin of its page `box`, is printed one page further in the same place: on the next
    /// page for a line in the bottom margin, on the previous one for a line in the top margin. A page step is the page's
    /// height less its margins; WebKit rounds it to its own pixels, so the place matches within the page tolerance.
    private static func printedElsewhere(_ line: PDFTextLine, from box: PDFBox, in layout: PDFLayout, margin: Double) -> Bool {
        let step = box.height - 2 * margin, below = line.box.maxY <= box.y + margin
        let page = below ? line.pageIndex + 1 : line.pageIndex - 1, y = below ? line.box.y + step : line.box.y - step
        return layout.lines.contains {
            $0.pageIndex == page && $0.text == line.text && abs($0.box.y - y) <= GeometricCompleteness.pageTolerance
        }
    }

    /// Every fault of `document` printed as `layout`: the page faults above, the text nodes the visible lines lack, the
    /// nodes they print more often than the document holds, and the lines `GeometricCompleteness` rejects. Only the lines
    /// a page shows count: the copy a page clips in its margin is neither a node's print nor a duplicate of it, and a
    /// line in a margin that no page prints is not shown, so it counts for nothing.
    public static func faults(of document: RenderedDocument, printedAs layout: PDFLayout, starts: [String],
                              page: PageSetup) -> [PageBreakFault] {
        let margin = page.verticalMarginPoints
        let shown = layout.lines.filter { line in
            let box = layout.pages[line.pageIndex]
            return !(line.box.maxY <= box.y + margin || line.box.y >= box.maxY - margin)
        }
        let missing = DocumentCompleteness.missing(in: shown.map(\.text).joined(separator: "\n"), expected: document.textNodes)
        let excess = duplicated(in: shown, expected: document.textNodes)
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        return faults(in: layout, starts: starts, margin: margin) + (missing.isEmpty ? [] : [.missing(missing)])
            + (excess.isEmpty ? [] : [.duplicated(excess)]) + (violations.isEmpty ? [] : [.geometry(violations)])
    }

    /// The expected nodes that more shown lines print, whole, than the document holds, in the order the document has them.
    private static func duplicated(in shown: [PDFTextLine], expected: [String]) -> [String] {
        let printed = Dictionary(shown.map { (key($0.text), 1) }, uniquingKeysWith: +)
        let held = Dictionary(expected.map { (key($0), 1) }, uniquingKeysWith: +)
        var seen = Set<String>()
        return expected.filter { node in
            let k = key(node)
            return seen.insert(k).inserted && printed[k, default: 0] > held[k, default: 0]
        }
    }

    private static func key(_ text: String) -> String { text.filter { !$0.isWhitespace }.lowercased() }
}
