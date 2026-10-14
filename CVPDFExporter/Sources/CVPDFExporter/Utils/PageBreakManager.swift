import Foundation

// MARK: - Page Break Manager

/// Manages page breaks in HTML for PDF generation.
///
/// The injected rules do not force sections or entries to stay whole: a design that wants a block kept
/// together says so itself. Forcing it here made every design leave pages half empty.
/// The print renderer does not keep a heading with the text after it (`break-after: avoid` has no effect), so a
/// design that wants this makes the heading part of the first lines of the entry that follows it.
public final class PageBreakManager: Sendable {

    public init() {}

    /// Insert page break CSS and rules into HTML
    public func insertPageBreaks(in html: String) -> String {
        // Empty HTML returns as-is
        guard !html.isEmpty else { return html }

        let pageBreakCSS = """

        /* Page break management */
        @media print {
            /* Force page breaks */
            .page-break {
                page-break-after: always;
                break-after: always;
            }

            /* Blocks a design marks as unbreakable */
            .avoid-break {
                page-break-inside: avoid;
                break-inside: avoid;
            }

            /* A heading is not cut across two pages */
            h1, h2, h3, h4, h5, h6 {
                page-break-inside: avoid;
                break-inside: avoid;
            }

            /* Never leave a single line alone at the top or bottom of a page */
            p, li, div {
                orphans: 2;
                widows: 2;
            }
        }

        """

        // Insert CSS into HTML
        return insertCSS(pageBreakCSS, into: html)
    }

    // MARK: - Private Methods

    private func insertCSS(_ css: String, into html: String) -> String {
        // Try to find existing </style> tag
        if let range = html.range(of: "</style>", options: .caseInsensitive) {
            // Insert before closing style tag
            var modifiedHTML = html
            modifiedHTML.insert(contentsOf: css, at: range.lowerBound)
            return modifiedHTML
        }

        // Try to find <head> section
        if let headRange = html.range(of: "</head>", options: .caseInsensitive) {
            // Insert new style tag before </head>
            let styleTag = "<style>\(css)</style>\n"
            var modifiedHTML = html
            modifiedHTML.insert(contentsOf: styleTag, at: headRange.lowerBound)
            return modifiedHTML
        }

        // Try to find <html> tag
        if let htmlRange = html.range(of: "<html", options: .caseInsensitive),
           let closeRange = html.range(of: ">", range: htmlRange.upperBound..<html.endIndex) {
            // Insert after opening html tag
            let styleTag = "\n<head><style>\(css)</style></head>\n"
            var modifiedHTML = html
            modifiedHTML.insert(contentsOf: styleTag, at: closeRange.upperBound)
            return modifiedHTML
        }

        // If no standard structure, prepend style
        return "<style>\(css)</style>\n\(html)"
    }
}