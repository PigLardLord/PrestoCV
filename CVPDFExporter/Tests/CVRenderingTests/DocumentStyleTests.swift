import Testing
import CVDesignCatalog
import CVRendering

@Suite("DocumentStyle · the look a document is rendered with")
struct DocumentStyleTests {
    @Test("two styles are equal when their stylesheet, palette and fonts are, and the fonts default to the system's")
    func equality() throws {
        let sheet = try stylesheet()
        let style = DocumentStyle(stylesheet: sheet, palette: palette)
        #expect(style.fonts == .system)
        #expect(style == DocumentStyle(stylesheet: sheet, palette: palette, fonts: .system))
        #expect(style != DocumentStyle(stylesheet: sheet, palette: palette, fonts: .serif))
        #expect(style != DocumentStyle(stylesheet: try stylesheet(".cv{margin:0}"), palette: palette))
        let darker = try #require(Palette(primary: HexColor("#003366")!, text: HexColor("#000000")!, background: HexColor("#FFFFFF")!))
        #expect(style != DocumentStyle(stylesheet: sheet, palette: darker))
    }
}
