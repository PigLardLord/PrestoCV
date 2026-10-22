import Foundation
import PrestoCVCore
import CVPDFExporter
import struct PrestoCVDomain.DesignChoice

/// The design, color palette and font scheme the export sheet shows and exports with.
struct ExportLook: Equatable {
    /// The id of the design; nil when no design is installed
    var templateId: String?
    var colorPalette: ColorPalette
    var fontScheme: FontScheme

    /// The look as a CV keeps it: the ids of the design, the palette and the font, as `DesignChoice` has them. Nil
    /// without a design, and when an id is not one a stored look may hold (lowercase letters, digits and hyphens).
    var designChoice: DesignChoice? {
        guard let templateId else { return nil }
        return DesignChoice(design: templateId, palette: colorPalette.rawValue, fonts: fontScheme.rawValue)
    }
}

/// Turns the look a CV keeps, plain ids, into the design, palette and font of the exporter.
///
/// A part that is missing, or that the app does not know, gives its default and nothing else: the other parts keep what
/// the CV says. The resolver reads; it never changes what is stored, so an id the app no longer knows stays in the CV
/// until the person chooses a look in the sheet.
enum ExportLookResolver {
    static let defaultColorPalette = ColorPalette.professional
    static let defaultFontScheme = FontScheme.classic

    /// - Parameters:
    ///   - look: The look stored with the CV; nil when the person has not chosen one.
    ///   - legacy: What the old global file holds, the design chosen last on this device before CVs kept their own look.
    ///     It is the look of a CV without one, and of no CV that has a look, however little of it.
    ///   - availableTemplateIds: The ids of the installed designs, in the order the sheet lists them. The first is the
    ///     default design.
    static func resolve(look: CVLook?, legacy: ExportPreferences, availableTemplateIds: [String]) -> ExportLook {
        let design: String?
        let palette: ColorPalette?
        let fonts: FontScheme?
        if let look {
            design = look.design
            palette = look.palette.flatMap(ColorPalette.init(rawValue:))
            fonts = look.fonts.flatMap(FontScheme.init(rawValue:))
        } else {
            design = legacy.templateId
            palette = legacy.colorPalette
            fonts = legacy.fontScheme
        }
        let installedDesign = design.flatMap { availableTemplateIds.contains($0) ? $0 : nil }
        return ExportLook(
            templateId: installedDesign ?? availableTemplateIds.first,
            colorPalette: palette ?? defaultColorPalette,
            fontScheme: fonts ?? defaultFontScheme
        )
    }
}
