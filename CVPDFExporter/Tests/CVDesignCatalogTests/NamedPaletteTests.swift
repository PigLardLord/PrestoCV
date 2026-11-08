import Testing
import Foundation
import CVDesignCatalog

@Suite("named palettes and font schemes (#125)")
struct NamedPaletteTests {
    @Test("the named palettes are the four colour names, in this order")
    func names() {
        #expect(NamedPalette.allCases.map(\.rawValue) == ["ink", "slate", "ocean", "plum"])
    }

    @Test("each named palette has its colours, and passes the public contrast rule", arguments: [
        (NamedPalette.ink, "#000000", "#000000", "#FFFFFF"),
        (NamedPalette.slate, "#2C3E50", "#2C3E50", "#FFFFFF"),
        (NamedPalette.ocean, "#1E40AF", "#1F2937", "#E0E7FF"),
        (NamedPalette.plum, "#6B46C1", "#1F2937", "#FEF3C7"),
    ])
    func colours(named: NamedPalette, primary: String, text: String, background: String) throws {
        let primaryColour = try #require(HexColor(primary)), textColour = try #require(HexColor(text))
        let backgroundColour = try #require(HexColor(background))
        let built = try #require(Palette(primary: primaryColour, text: textColour, background: backgroundColour))
        #expect(named.palette == built)
    }

    @Test("every named palette, whatever the table above lists, rebuilds through the public checked initialisers", arguments: NamedPalette.allCases)
    func rebuilt(named: NamedPalette) throws {
        let palette = named.palette
        let primary = try #require(HexColor(palette.primary.value)), text = try #require(HexColor(palette.text.value))
        let background = try #require(HexColor(palette.background.value))
        let checked = try #require(Palette(primary: primary, text: text, background: background), "\(named.rawValue) is not readable")
        #expect(checked == palette)
    }

    @Test("the identifiers of palettes and font schemes are their raw values, and round-trip through JSON")
    func identifiers() throws {
        struct Choice: Codable, Equatable { var palette: NamedPalette, fonts: FontScheme }
        for named in NamedPalette.allCases {
            #expect(NamedPalette(rawValue: named.rawValue) == named)
        }
        #expect(FontScheme.allCases.map(\.rawValue) == ["system", "serif", "rounded"])
        for named in NamedPalette.allCases {
            for fonts in FontScheme.allCases {
                let choice = Choice(palette: named, fonts: fonts)
                let json = try JSONEncoder().encode(choice)
                #expect(try JSONDecoder().decode(Choice.self, from: json) == choice)
            }
        }
        let json = try JSONEncoder().encode(Choice(palette: .ocean, fonts: .serif))
        #expect(try JSONDecoder().decode([String: String].self, from: json) == ["palette": "ocean", "fonts": "serif"])
    }

    @Test("an identifier the catalog does not know names no palette or font scheme", arguments: ["", "Ink", "minimal", "ink ", "ink\n"])
    func unknown(identifier: String) {
        #expect(NamedPalette(rawValue: identifier) == nil)
        #expect(FontScheme(rawValue: identifier) == nil)
    }
}
