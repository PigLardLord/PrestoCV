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
    /// Expected text nodes that the visible lines print more often than the document holds them: duplicated content.
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
        let lines = shown.map(\.text), text = lines.joined(separator: "\n")
        let missing = DocumentCompleteness.missing(in: text, expected: document.textNodes)
        let excess = missing.isEmpty ? duplicated(in: lines, expected: document.textNodes) : []
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        return faults(in: layout, starts: starts, margin: margin) + (missing.isEmpty ? [] : [.missing(missing)])
            + (excess.isEmpty ? [] : [.duplicated(excess)]) + (violations.isEmpty ? [] : [.geometry(violations)])
    }

    /// The expected nodes that `text`, the shown lines, prints more often than the document holds them, in the order the
    /// document has them. A node is printed once more than held when the text still gives one more copy of it a span of
    /// its own after every expected node has taken its own, as `DocumentCompleteness` places them: a span may cross a line
    /// end, so a node that wraps counts, and the text a longer node takes ("Experience with X") is no print of a shorter
    /// node inside it ("Experience").
    ///
    /// The spans follow no order, as a design with a sidebar or two columns prints its lines in another order than the
    /// document's. Counting a node's matches in the joined lines against its matches in the joined nodes would depend on
    /// the order: a match across two lines ("Greg" then "Officer" holds "go") that the document's order does not join
    /// reads as an extra print. Here that text belongs to the two nodes, so no copy of "Go" fits in it. A copy fits only
    /// in text that no node needs, so the search runs only where the text has that much more than the nodes and the node
    /// matches more often than held. It runs on a complete print only: with a node missing, no placement holds every node.
    /// A search stopped by its budget counts the node as duplicated, so the check fails closed.
    ///
    /// A page break may also print only one line of a wrapped node twice, so no second whole copy exists. A shown line
    /// is left over when the text without it still places every node; a left-over line that is a part of a node's text
    /// (three characters or more, so a hyphen or a bullet is none) is a duplicate of the first node that holds it. Only
    /// a line no longer than the spare text can be left over, and each distinct line is tried once on a complete print,
    /// so a correct print, whose spare is a few bullets, costs next to nothing.
    private static func duplicated(in lines: [String], expected: [String]) -> [String] {
        let text = lines.joined(separator: "\n")
        let whole = duplicatedWhole(in: text, expected: expected)
        let spare = key(text).unicodeScalars.count - expected.reduce(0) { $0 + key($1).unicodeScalars.count }
        var tried = Set<String>(), parts = Set<String>()
        for (index, line) in lines.enumerated() {
            let k = key(line), size = k.unicodeScalars.count
            guard size >= 3, size <= spare, tried.insert(k).inserted,
                  let node = expected.first(where: { key($0).contains(k) }) else { continue }
            var rest = lines
            rest.remove(at: index)
            let report = DocumentCompleteness.report(in: rest.joined(separator: "\n"), expected: expected)
            if report.missing.isEmpty || report.budgetExhausted { parts.insert(node) }
        }
        var seen = Set<String>()
        return expected.filter { (whole.contains($0) || parts.contains($0)) && seen.insert($0).inserted }
    }

    private static func duplicatedWhole(in text: String, expected: [String]) -> [String] {
        let printed = Array(key(text).unicodeScalars)
        let spare = printed.count - expected.reduce(0) { $0 + key($1).unicodeScalars.count }
        let held = Dictionary(expected.map { (key($0), 1) }, uniquingKeysWith: +)
        var seen = Set<String>()
        return expected.filter { node in
            let k = key(node), needle = Array(k.unicodeScalars)
            guard !needle.isEmpty, needle.count <= spare, seen.insert(k).inserted,
                  matches(of: needle, in: printed) > held[k, default: 0] else { return false }
            let report = DocumentCompleteness.report(in: text, expected: expected + [node])
            return report.missing.isEmpty || report.budgetExhausted
        }
    }

    /// How many disjoint times `needle` occurs in `text`. Every match has the needle's length, so taking them from the left
    /// gives the most.
    private static func matches(of needle: [Unicode.Scalar], in text: [Unicode.Scalar]) -> Int {
        var count = 0, start = 0
        while start + needle.count <= text.count {
            let found = text[start..<start + needle.count].elementsEqual(needle)
            count += found ? 1 : 0; start += found ? needle.count : 1
        }
        return count
    }

    /// A text as `DocumentCompleteness` compares it: lower case, without whitespace.
    private static func key(_ text: String) -> String {
        String(String.UnicodeScalarView(text.lowercased().unicodeScalars.filter { !$0.properties.isWhitespace }))
    }
}
