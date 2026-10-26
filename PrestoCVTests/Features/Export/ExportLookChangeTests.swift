import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter
import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.DesignChoice

/// What the person changed in the sheet is the parts that differ from the look it showed before, with the look it shows
/// now.
@Suite("ExportLook - what a choice changed")
struct ExportLookChangeTests {

    private let before = ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic)

    private func shown(_ design: String, _ palette: ColorPalette, _ font: FontScheme) -> DesignChoice {
        DesignChoice(design: design, palette: palette.rawValue, fonts: font.rawValue)!
    }

    @Test("A design chosen is the design part, with the look now shown")
    func designChosen() {
        let after = ExportLook(templateId: "modern", colorPalette: .professional, fontScheme: .classic)

        #expect(after.change(from: before) == LookChange(shown: shown("modern", .professional, .classic), parts: [.design]))
    }

    @Test("A palette chosen is the palette part, and a font the fonts part")
    func paletteAndFontChosen() {
        let palette = ExportLook(templateId: "professional", colorPalette: .creative, fontScheme: .classic)
        let font = ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .serif)

        #expect(palette.change(from: before) == LookChange(shown: shown("professional", .creative, .classic), parts: [.palette]))
        #expect(font.change(from: before) == LookChange(shown: shown("professional", .professional, .serif), parts: [.fonts]))
    }

    @Test("Several parts that differ are all in the change")
    func severalParts() {
        let after = ExportLook(templateId: "minimal", colorPalette: .minimal, fontScheme: .serif)

        #expect(after.change(from: before)?.parts == [.design, .palette, .fonts])
    }

    @Test("The same look is no change")
    func sameLookIsNoChange() {
        #expect(before.change(from: before) == nil)
    }

    @Test("Without a design to name there is no change to hand over")
    func noDesignNoChange() {
        let without = ExportLook(templateId: nil, colorPalette: .creative, fontScheme: .classic)

        #expect(without.change(from: before) == nil)
    }
}
