import CVRendering

/// What a printed CV's page breaks get wrong (#467), with the page (0 first) and the text that shows it.
public enum PageBreakFault: Sendable, Equatable {
    /// The page's lowest line is a section title: the title is alone at its foot, and its first entry starts the next page.
    case titleAlone(page: Int, title: String)
    /// The page holds no text.
    case blankPage(page: Int)
}

/// Reads page-break faults in the layout a PDF inspector gives: the native renderers' tests print documents whose
/// section titles fall at every height of a page's foot and check each PDF with it.
public enum PageBreaks {
    /// The faults of `layout`, page by page. A title matches a line whatever its case and spacing, since a design may
    /// print its titles in capitals or with spaced letters.
    public static func faults(in layout: PDFLayout, titles: [String]) -> [PageBreakFault] {
        let titleKeys = Set(titles.map(key))
        return layout.pages.indices.compactMap { page in
            guard let lowest = layout.lines.filter({ $0.pageIndex == page }).min(by: { $0.box.y < $1.box.y }) else {
                return .blankPage(page: page)
            }
            return titleKeys.contains(key(lowest.text)) ? .titleAlone(page: page, title: lowest.text) : nil
        }
    }

    private static func key(_ text: String) -> String { text.filter { !$0.isWhitespace }.lowercased() }
}
