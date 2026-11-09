import Foundation
import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVBundledHeadings

/// What the native renderers' contract runs print, shared by the iOS and macOS tests (R10): the gate's own document
/// (`GateFixture`), a palette and a plain design.
public enum ContractFixture {
    public static let document = GateFixture.document

    public static let palette = Palette(primary: HexColor("#1F3A5F")!, text: HexColor("#111111")!, background: HexColor("#FFFFFF")!)!

    /// A plain design that passes the CSS policy.
    public static func stylesheet(_ css: String = ".cv-name{color:var(--color-primary)}.cv-entry-title{font-weight:600}") throws -> ValidatedStylesheet {
        let package: [String: Any] = ["manifest": ["id": "contract", "name": "Contract", "version": "1.0.0", "description": "",
                                                    "defaultPalette": NamedPalette.ink.rawValue, "defaultFonts": FontScheme.system.rawValue,
                                                    "markupContract": MarkupContract.version], "cssContent": css]
        return try DesignPackageValidator().validate(JSONSerialization.data(withJSONObject: package)).stylesheet
    }

    /// The fixture as the builder renders it: the HTML and the text nodes the PDF must contain.
    public static func rendered(css: String? = nil) throws -> RenderedDocument {
        let sheet = try css.map { try stylesheet($0) } ?? stylesheet()
        return DocumentHTMLBuilder().render(document, stylesheet: sheet, palette: palette, headings: try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: "it"))
    }
}
