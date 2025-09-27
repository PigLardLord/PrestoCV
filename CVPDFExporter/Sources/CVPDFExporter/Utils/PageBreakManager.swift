import Foundation

// MARK: - Page Break Manager

/// Manages page breaks in HTML for PDF generation
/// Sprint 4: Smart page break management
public final class PageBreakManager: Sendable {

    /// Maximum number of pages for CV (default: 4)
    public let maxPages: Int

    /// Initialize with maximum page limit
    public init(maxPages: Int = 4) {
        self.maxPages = maxPages
    }

    /// Insert page break CSS and rules into HTML
    public func insertPageBreaks(in html: String) -> String {
        // Empty HTML returns as-is
        guard !html.isEmpty else { return html }

        // Page break CSS rules
        let pageBreakCSS = """

        /* Page Break Management - Sprint 4 */
        @media print {
            /* Force page breaks */
            .page-break {
                page-break-after: always;
                break-after: always;
            }

            /* Avoid breaking inside these elements */
            .avoid-break,
            .item,
            .section,
            .skills-group {
                page-break-inside: avoid;
                break-inside: avoid;
            }

            /* Headers should not be orphaned */
            h1, h2, h3, h4, h5, h6 {
                page-break-after: avoid;
                break-after: avoid;
                page-break-inside: avoid;
                break-inside: avoid;
            }

            /* Keep headers with their content */
            h2 {
                page-break-after: avoid;
                break-after: avoid;
            }

            /* Items should stay together */
            .item {
                page-break-inside: avoid;
                break-inside: avoid;
                orphans: 3;
                widows: 3;
            }

            /* Sections should preferably stay together */
            .section {
                page-break-inside: avoid;
                break-inside: avoid;
            }

            /* Ensure minimum content on pages */
            p, li, div {
                orphans: 2;
                widows: 2;
            }

            /* Page size and margins */
            @page {
                orphans: 3;
                widows: 3;
            }

            /* Max pages: \(maxPages) */
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