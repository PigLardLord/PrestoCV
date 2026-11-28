import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVBundledHeadings

/// #558: the documents whose layout is recorded for every bundled design: the contract fixture, every section in
/// Italian on A4 (two pages in every bundled design), and a page-break document of #467 in English (three pages).
public enum LayoutDocument: String, Sendable, CaseIterable {
    case contractFixture = "contract-fixture"
    case pageBreaks = "page-breaks"

    /// The profile lines and the body of the page-break document: its first role breaks across pages.
    public static let pageBreaksSummaryLines = 20

    public var document: CVDocument {
        switch self {
        case .contractFixture: ContractFixture.document
        case .pageBreaks: PageBreakDocument.document(summaryLines: Self.pageBreaksSummaryLines, body: .longFirstRole)
        }
    }

    /// The page the document is printed on.
    public var page: PageSetup {
        switch self {
        case .contractFixture: .a4
        case .pageBreaks: PageBreakDocument.page
        }
    }

    /// The document as the builder renders it in a design.
    public func rendered(stylesheet: ValidatedStylesheet, palette: Palette, fonts: FontScheme) throws -> RenderedDocument {
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: document.language)
        return DocumentHTMLBuilder().render(document, stylesheet: stylesheet, palette: palette, fonts: fonts, headings: headings)
    }
}
