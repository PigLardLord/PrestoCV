import Foundation
import Testing
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import CVDesignCatalog
import CVRenderingTestSupport

/// A design as the validator accepts it, with a preview of its own: the PNG signature, then the design's id, so that
/// two designs never share one.
private func design(_ id: String, palette: NamedPalette, fonts: FontScheme, preview: Bool = true) throws -> ValidatedDesign {
    let package = try DesignStoreContract.package(id: id, defaultPalette: palette, defaultFonts: fonts)
    var object = try #require(try JSONSerialization.jsonObject(with: package) as? [String: Any])
    if preview { object["previewImageBase64"] = png(of: id).base64EncodedString() }
    return try DesignPackageValidator().validate(try JSONSerialization.data(withJSONObject: object))
}

private func png(of id: String) -> Data { Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + Array(id.utf8)) }

/// The bundled designs as the store reads them, by identifier; the default has a palette and fonts of its own.
private func installed() throws -> (all: [ValidatedDesign], professional: DesignManifest) {
    let professional = try design("professional", palette: .slate, fonts: .serif)
    return ([try design("minimal", palette: .ink, fonts: .system), try design("modern", palette: .ocean, fonts: .rounded), professional],
            professional.manifest)
}

/// A colour from its three bytes, as a picker draws it.
private func color(_ red: Int, _ green: Int, _ blue: Int) -> LookColor {
    LookColor(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
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

    @Test("each design comes with its own palette and fonts, the ones the PDF is set in when the CV keeps none")
    func eachDesignHasItsOwnLook() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.ownLooks == [
            "minimal": DesignOwnLook(palette: "ink", fonts: "system"),
            "modern": DesignOwnLook(palette: "ocean", fonts: "rounded"),
            "professional": DesignOwnLook(palette: "slate", fonts: "serif")
        ])
    }

    @Test("the default design has its own look even when it is not installed")
    func theDefaultDesignAlwaysHasItsOwnLook() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: Array(catalog.all.prefix(2)), defaultDesign: catalog.professional).options()

        #expect(options.ownLooks["professional"] == DesignOwnLook(palette: "slate", fonts: "serif"))
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

    // MARK: - What a picker draws each choice with

    @Test("each design shows its own preview, the page the catalog keeps with it")
    func designsShowTheirPreview() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.designs.map(\.sample) == [
            .page(png: png(of: "minimal")), .page(png: png(of: "modern")), .page(png: png(of: "professional"))
        ])
    }

    @Test("a design the catalog keeps no preview for shows none")
    func aDesignWithoutAPreview() throws {
        let plain = try design("plain", palette: .ink, fonts: .system, preview: false)
        let professional = try design("professional", palette: .slate, fonts: .serif)

        let options = CatalogLookOptions(installed: [plain, professional], defaultDesign: professional.manifest).options()

        #expect(options.designs.map(\.sample) == [.none, .page(png: png(of: "professional"))])
    }

    @Test("each palette shows its primary colour and its background, as the PDF draws them")
    func palettesShowTheirColours() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.palettes.map(\.sample) == [
            .colors(primary: color(0x00, 0x00, 0x00), background: color(0xFF, 0xFF, 0xFF)),
            .colors(primary: color(0x2C, 0x3E, 0x50), background: color(0xFF, 0xFF, 0xFF)),
            .colors(primary: color(0x1E, 0x40, 0xAF), background: color(0xE0, 0xE7, 0xFF)),
            .colors(primary: color(0x6B, 0x46, 0xC1), background: color(0xFE, 0xF3, 0xC7))
        ])
    }

    @Test("each font scheme shows its typeface")
    func fontSchemesShowTheirTypeface() throws {
        let catalog = try installed()

        let options = CatalogLookOptions(installed: catalog.all, defaultDesign: catalog.professional).options()

        #expect(options.fontSchemes.map(\.sample) == [.typeface(.system), .typeface(.serif), .typeface(.rounded)])
    }
}
