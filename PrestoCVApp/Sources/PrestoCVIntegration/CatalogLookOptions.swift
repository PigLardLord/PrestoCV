import PrestoCVWorkflowPorts
import CVDesignCatalog

/// What the look picker offers, from the design catalog: the designs that passed their check (`CheckedDesigns`), the
/// default design first, then the others by identifier; every palette and font scheme the catalog knows; the own palette
/// and fonts of each of those designs; the default design for a CV that keeps no look; and whether more designs can join
/// (#566).
/// Each option is named by a code, never by a sentence (R13): `design.<id>`, `palette.<id>` and `fonts.<id>`. The view
/// words the codes. Each option also carries what the view draws it with (#407): a design its preview, a palette its
/// primary and background colours, a font scheme its kind of typeface.
public struct CatalogLookOptions: LookOptionsProviding {
    private let designs: CheckedDesigns

    public init(designs: CheckedDesigns) {
        self.designs = designs
    }

    public func options() -> LookOptions {
        Self.options(designs.current, defaultDesign: designs.defaultDesign)
    }

    public func changes() -> AsyncStream<LookOptions> {
        let defaultDesign = designs.defaultDesign
        return designs.changes { Self.options($0, defaultDesign: defaultDesign) }
    }

    public func retry() {
        designs.retry()
    }

    private static func options(_ checked: CheckedDesignsSnapshot, defaultDesign: String) -> LookOptions {
        LookOptions(
            designs: checked.designs.map { design in
                let id = design.manifest.id
                return LookOption(id: id, nameCode: "design.\(id)", sample: design.previewPNG.map { .page(png: $0) } ?? .none)
            },
            palettes: NamedPalette.allCases.map { palette in
                LookOption(
                    id: palette.rawValue, nameCode: "palette.\(palette.rawValue)",
                    sample: .colors(primary: color(palette.palette.primary), background: color(palette.palette.background))
                )
            },
            fontSchemes: FontScheme.allCases.map { fonts in
                LookOption(id: fonts.rawValue, nameCode: "fonts.\(fonts.rawValue)", sample: .typeface(typeface(of: fonts)))
            },
            defaultDesign: defaultDesign,
            ownLooks: Dictionary(checked.designs.map { ($0.manifest.id, ownLook(of: $0.manifest)) }, uniquingKeysWith: { first, _ in first }),
            status: checked.status
        )
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
