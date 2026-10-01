import Testing
import Foundation
import CVDesignCatalog
import CVRenderingTestSupport

@Suite("resolving a design choice (#125)")
struct ResolveDesignTests {
    /// A store with `clean` (defaults slate and serif) and `bold` (defaults plum and rounded).
    private func store() async throws -> InMemoryDesignStore {
        let store = InMemoryDesignStore()
        try await store.save(DesignStoreContract.design(id: "clean", css: ".cv-name{color:var(--color-primary)}", defaultPalette: .slate, defaultFonts: .serif))
        try await store.save(DesignStoreContract.design(id: "bold", css: ".cv-entry-title{font-weight:700}", defaultPalette: .plum, defaultFonts: .rounded))
        return store
    }

    @Test("a known palette and font scheme are the ones chosen, with the stylesheet of the design")
    func known() async throws {
        let resolved = try await ResolveDesign(store: store())(design: "clean", palette: "ocean", fonts: "rounded")
        #expect(resolved.id == "clean")
        #expect(resolved.palette == NamedPalette.ocean.palette && resolved.fonts == .rounded)
        #expect(resolved.stylesheet.css == ".cv-name{color:var(--color-primary)}")
    }

    @Test("each design brings its own stylesheet and defaults")
    func perDesign() async throws {
        let resolve = ResolveDesign(store: try await store())
        let bold = try await resolve(design: "bold", palette: nil, fonts: nil)
        #expect(bold.id == "bold" && bold.stylesheet.css == ".cv-entry-title{font-weight:700}")
        #expect(bold.palette == NamedPalette.plum.palette && bold.fonts == .rounded)
    }

    @Test("a palette or font scheme that is not named falls back to the design's default")
    func notNamed() async throws {
        let resolve = ResolveDesign(store: try await store())
        let bothDefault = try await resolve(design: "clean", palette: nil, fonts: nil)
        #expect(bothDefault.palette == NamedPalette.slate.palette && bothDefault.fonts == .serif)
        let paletteOnly = try await resolve(design: "clean", palette: "ocean", fonts: nil)
        #expect(paletteOnly.palette == NamedPalette.ocean.palette && paletteOnly.fonts == .serif)
        let fontsOnly = try await resolve(design: "clean", palette: nil, fonts: "rounded")
        #expect(fontsOnly.palette == NamedPalette.slate.palette && fontsOnly.fonts == .rounded)
    }

    @Test("an identifier the catalog does not know falls back to the default, the other choice still counts",
          arguments: ["", "minimal", "Ocean", "ocean ", "ocean\n", "../ocean"])
    func unknownPalette(identifier: String) async throws {
        let resolved = try await ResolveDesign(store: store())(design: "clean", palette: identifier, fonts: "rounded")
        #expect(resolved.palette == NamedPalette.slate.palette && resolved.fonts == .rounded)
    }

    @Test("a font scheme the catalog does not know falls back to the default, the palette still counts",
          arguments: ["", "comic", "Rounded", "rounded ", "rounded\n", "../rounded"])
    func unknownFonts(identifier: String) async throws {
        let resolved = try await ResolveDesign(store: store())(design: "clean", palette: "ocean", fonts: identifier)
        #expect(resolved.palette == NamedPalette.ocean.palette && resolved.fonts == .serif)
    }

    @Test("a design the store does not have is unknown, whatever else is chosen", arguments: ["nope", "", "Clean", "clean\n"])
    func unknownDesign(id: String) async throws {
        let resolve = ResolveDesign(store: try await store())
        await #expect(throws: DesignCatalogError.unknownDesign(id)) { _ = try await resolve(design: id, palette: "ocean", fonts: "rounded") }
    }

    @Test("a store that cannot be reached is reported")
    func unavailable() async {
        await #expect(throws: DesignCatalogError.storeUnavailable) {
            _ = try await ResolveDesign(store: UnavailableStore())(design: "clean", palette: nil, fonts: nil)
        }
    }
}
