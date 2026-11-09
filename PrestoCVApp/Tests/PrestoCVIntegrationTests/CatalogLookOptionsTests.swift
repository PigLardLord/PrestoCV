import Testing
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import CVDesignCatalog
import CVRenderingTestSupport

private func manifest(_ id: String, palette: NamedPalette, fonts: FontScheme) throws -> DesignManifest {
    try DesignStoreContract.design(id: id, defaultPalette: palette, defaultFonts: fonts).manifest
}

/// The bundled designs as the store lists them, by identifier; the default has a palette and fonts of its own.
private func installed() throws -> (all: [DesignManifest], professional: DesignManifest) {
    let professional = try manifest("professional", palette: .slate, fonts: .serif)
    return ([try manifest("minimal", palette: .ink, fonts: .system), try manifest("modern", palette: .ocean, fonts: .rounded), professional],
            professional)
}

@Suite("The look options come from the design catalog")
struct CatalogLookOptionsTests {
    @Test("the designs are the installed ones, in the catalog's order")
    func designsAreTheInstalledOnes() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.designs.map(\.id) == ["minimal", "modern", "professional"])
    }

    @Test("the palettes and fonts are every one the catalog knows, in its order")
    func palettesAndFontsAreTheCatalogs() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.palettes.map(\.id) == NamedPalette.allCases.map(\.rawValue))
        #expect(options.fontSchemes.map(\.id) == FontScheme.allCases.map(\.rawValue))
    }

    @Test("the defaults are the default design and its own palette and fonts")
    func defaultsComeFromTheDefaultDesign() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.defaultDesign == "professional")
        #expect(options.defaultPalette == "slate")
        #expect(options.defaultFonts == "serif")
    }

    @Test("the name codes are stable: the kind of the option, a dot and its id")
    func nameCodesAreStable() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.designs.map(\.nameCode) == ["design.minimal", "design.modern", "design.professional"])
        #expect(options.palettes.map(\.nameCode) == ["palette.ink", "palette.slate", "palette.ocean", "palette.plum"])
        #expect(options.fontSchemes.map(\.nameCode) == ["fonts.system", "fonts.serif", "fonts.rounded"])
    }
}
