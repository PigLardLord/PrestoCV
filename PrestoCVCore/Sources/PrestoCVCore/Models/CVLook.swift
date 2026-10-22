import Foundation

/// The look of a CV's PDF: the design, the color palette and the font scheme it is exported with, kept with the CV.
///
/// Each part is an id as plain text, because PrestoCVCore knows nothing of the exporter: the app maps the ids to the
/// exporter's designs, palettes and fonts. The ids are those of `DesignChoice` in the new domain (lowercase letters,
/// digits and hyphens, 1 to 64 characters), so that the importer of the new persistence copies them as they are. A part
/// that is missing, or that the app no longer knows, is a part the person has not chosen: the app shows its default
/// and keeps the stored text until the person chooses.
public struct CVLook: Codable, Sendable, Equatable, Hashable {
    /// The id of the design (the template).
    public var design: String?
    /// The id of the color palette.
    public var palette: String?
    /// The id of the font scheme.
    public var fonts: String?

    public init(design: String? = nil, palette: String? = nil, fonts: String? = nil) {
        self.design = design
        self.palette = palette
        self.fonts = fonts
    }

    /// The look a new CV starts with: the Professional design, the professional colors and the classic fonts. These are
    /// the ids of the exporter's defaults; a test in the app checks that the exporter still knows them.
    public static let standard = CVLook(design: "professional", palette: "professional", fonts: "classic")
}
