import PrestoCVWorkflowPorts
import CVDesignCatalog

/// What the look picker offers, from the design catalog: the installed designs in the catalog's order, every palette and
/// font scheme the catalog knows, and the default design with its own palette and fonts for a CV that keeps no look.
/// Each option is named by a code, never by a sentence (R13): `design.<id>`, `palette.<id>` and `fonts.<id>`. The view
/// words the codes.
public struct CatalogLookOptions: LookOptionsProviding {
    private let offered: LookOptions

    /// - Parameters:
    ///   - installed: The manifests of the installed designs, as the catalog lists them
    ///   - defaultDesign: The manifest of the design a CV that keeps none exports with
    public init(installed: [DesignManifest], defaultDesign: DesignManifest) {
        offered = LookOptions(
            designs: installed.map { LookOption(id: $0.id, nameCode: "design.\($0.id)") },
            palettes: NamedPalette.allCases.map { LookOption(id: $0.rawValue, nameCode: "palette.\($0.rawValue)") },
            fontSchemes: FontScheme.allCases.map { LookOption(id: $0.rawValue, nameCode: "fonts.\($0.rawValue)") },
            defaultDesign: defaultDesign.id,
            defaultPalette: defaultDesign.defaultPalette.rawValue,
            defaultFonts: defaultDesign.defaultFonts.rawValue
        )
    }

    public func options() -> LookOptions {
        offered
    }
}
