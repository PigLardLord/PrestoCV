import PrestoCVWorkflowPorts
import CVDesignCatalog

/// What the look picker offers, from the design catalog: the installed designs in the catalog's order, every palette and
/// font scheme the catalog knows, the own palette and fonts of each design, and the default design for a CV that keeps
/// no look.
/// Each option is named by a code, never by a sentence (R13): `design.<id>`, `palette.<id>` and `fonts.<id>`. The view
/// words the codes. Each option also carries what the view draws it with (#407): a design its preview, a palette its
/// primary and background colours, a font scheme its kind of typeface.
public struct CatalogLookOptions: LookOptionsProviding {
    private let offered: LookOptions

    /// - Parameters:
    ///   - installed: The installed designs, as the catalog lists them
    ///   - defaultDesign: The manifest of the design a CV that keeps none exports with
    public init(installed: [ValidatedDesign], defaultDesign: DesignManifest) {
        offered = LookOptions(
            designs: installed.map { design in
                let id = design.manifest.id
                return LookOption(id: id, nameCode: "design.\(id)", sample: design.previewPNG.map { .page(png: $0) } ?? .none)
            },
            palettes: NamedPalette.allCases.map { palette in
                LookOption(
                    id: palette.rawValue, nameCode: "palette.\(palette.rawValue)",
                    sample: .colors(primary: Self.color(palette.palette.primary), background: Self.color(palette.palette.background))
                )
            },
            fontSchemes: FontScheme.allCases.map { fonts in
                LookOption(id: fonts.rawValue, nameCode: "fonts.\(fonts.rawValue)", sample: .typeface(Self.typeface(of: fonts)))
            },
            defaultDesign: defaultDesign.id,
            ownLooks: Dictionary(
                ([defaultDesign] + installed.map(\.manifest)).map { ($0.id, Self.ownLook(of: $0)) },
                uniquingKeysWith: { _, installed in installed }
            )
        )
    }

    public func options() -> LookOptions {
        offered
    }

    /// The palette and fonts the design sets a CV in when the CV keeps none: the ones the exporter falls back to.
    private static func ownLook(of design: DesignManifest) -> DesignOwnLook {
        DesignOwnLook(palette: design.defaultPalette.rawValue, fonts: design.defaultFonts.rawValue)
    }

    private static func color(_ hex: HexColor) -> LookColor {
        let channels = hex.channels
        return LookColor(red: channels.red, green: channels.green, blue: channels.blue)
    }

    /// Every scheme the catalog knows has its kind: a new one fails to build here until it is given one.
    private static func typeface(of fonts: FontScheme) -> LookTypeface {
        switch fonts {
        case .system: .system
        case .serif: .serif
        case .rounded: .rounded
        }
    }
}
