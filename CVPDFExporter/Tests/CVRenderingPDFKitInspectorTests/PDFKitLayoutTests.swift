#if canImport(PDFKit)   // Apple platforms only (R11)
import Testing
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CVRendering
import CVRenderingNativeTestSupport
@testable import CVRenderingPDFKitInspector

/// PDFKit's reading of PDFs drawn at known positions and sizes, on macOS and on the iOS simulator (#80): Helvetica drawn
/// with CoreText, boxes in page space with the origin at the lower left, and the font size as drawn, the transform
/// included. The boxes are the ones PDFKit gives for these strings; a line's width is its advance at the drawn size.
@Suite("#80 · the PDFKit layout")
struct PDFKitLayoutTests {
    static let page = PDFBox(x: 0, y: 0, width: 595, height: 842)

    static func line(_ text: String, size: Double, x: Double, y: Double, scale: Double = 1) -> DrawnPDF.Line {
        DrawnPDF.Line(text: text, size: size, x: x, y: y, scale: scale)
    }

    static func layout(_ lines: [DrawnPDF.Line]) throws -> PDFLayout {
        try #require(PDFKitInspector().layout(of: DrawnPDF.pages([lines])))
    }

    static func close(_ box: PDFBox, _ expected: PDFBox) -> Bool {
        abs(box.x - expected.x) <= 0.5 && abs(box.y - expected.y) <= 0.5
            && abs(box.width - expected.width) <= 0.5 && abs(box.height - expected.height) <= 0.5
    }

    /// Seven lines, one inside the page and six partly or wholly past one of its edges, all 12 pt.
    static let outside = [
        line("Inside the page", size: 12, x: 100, y: 700),
        line("Below the bottom edge", size: 12, x: 100, y: -30),
        line("Straddling the bottom edge", size: 12, x: 100, y: -4),
        line("Past the right edge of the page", size: 12, x: 560, y: 500),
        line("Wholly right of the page", size: 12, x: 700, y: 400),
        line("Above the top edge", size: 12, x: 100, y: 860),
        line("Left of the page", size: 12, x: -300, y: 300),
    ]

    @Test("reads each line's box and font size from a PDF drawn with known positions")
    func knownPositions() throws {
        let layout = try Self.layout([
            Self.line("Twelve point text", size: 12, x: 100, y: 700),
            Self.line("Three point", size: 3, x: 100, y: 600),
            Self.line("Twelve scaled to three", size: 12, x: 100, y: 500, scale: 0.25),
            Self.line("Three scaled to twelve", size: 3, x: 100, y: 400, scale: 4),
            Self.line("Six point text", size: 6, x: 100, y: 300),
        ])
        #expect(layout.pages == [Self.page])
        let expected: [(String, PDFBox, Double)] = [
            ("Twelve point text", PDFBox(x: 100, y: 697.24, width: 89.39, height: 12), 12),
            ("Three point", PDFBox(x: 100, y: 599.31, width: 15.177, height: 3), 3),
            ("Twelve scaled to three", PDFBox(x: 100, y: 499.31, width: 29.8512, height: 3), 3),
            ("Three scaled to twelve", PDFBox(x: 100, y: 397.24, width: 120.06, height: 12), 12),
            ("Six point text", PDFBox(x: 100, y: 298.62, width: 34.3524, height: 6), 6),
        ]
        #expect(layout.lines.map(\.text) == expected.map(\.0))
        for (line, (text, box, size)) in zip(layout.lines, expected) {
            #expect(line.pageIndex == 0, "\(text) is on page \(line.pageIndex)")
            #expect(Self.close(line.box, box), "\(text): box \(line.box), expected \(box)")
            #expect(line.glyphHeight == size, "\(text): glyph height \(String(describing: line.glyphHeight)), expected \(size)")
        }
    }

    @Test("a page's box is its crop box: a line past the crop box but inside the media box is outside, one inside is not")
    func cropBox() throws {
        let cropBox = CGRect(x: 50, y: 100, width: 300, height: 400)
        let data = DrawnPDF.pages([[
            Self.line("Inside the crop box", size: 12, x: 100, y: 300),
            Self.line("Straddling the crop box edge", size: 12, x: 100, y: 497),
        ]], cropBox: cropBox)
        let layout = try #require(PDFKitInspector().layout(of: data))
        #expect(layout.pages == [PDFBox(x: 50, y: 100, width: 300, height: 400)], "\(layout.pages)")
        let inside = try #require(layout.lines.first { $0.text == "Inside the crop box" })
        #expect(abs(inside.box.x - 100) <= 0.5 && abs(inside.box.y - 298.62) <= 1.5, "the line's box is \(inside.box)")
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        #expect(violations == [.outsidePage(page: 0, text: "Straddling the crop box edge")], "\(violations)")
    }

    @Test("text drawn below the bottom edge is reported outside the page")
    func belowTheBottomEdge() throws {
        let layout = try Self.layout(Self.outside)
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        #expect(violations.contains(.outsidePage(page: 0, text: "Straddling the bottom edge")), "\(violations)")
        let straddling = try #require(layout.lines.first { $0.text == "Straddling the bottom edge" })
        #expect(straddling.box.y < -1, "the line's box starts at \(straddling.box.y)")
    }

    @Test("text drawn past the right edge is reported")
    func pastTheRightEdge() throws {
        let layout = try Self.layout(Self.outside)
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        let past = try #require(layout.lines.first { $0.text.hasPrefix("Past th") })
        #expect(past.box.maxX > 596, "the line's box ends at \(past.box.maxX)")
        #expect(violations.contains(.outsidePage(page: 0, text: past.text)), "\(violations)")
        #expect(!violations.contains(.outsidePage(page: 0, text: "Inside the page")), "\(violations)")
    }

    @Test("text wholly outside the page is absent, so completeness reports it")
    func whollyOutside() throws {
        let layout = try Self.layout(Self.outside)
        let text = try #require(PDFKitInspector().text(of: DrawnPDF.pages([Self.outside])))
        let wholly = ["Below the bottom edge", "Wholly right of the page", "Above the top edge", "Left of the page"]
        #expect(DocumentCompleteness.missing(in: text, expected: wholly) == wholly, "the page's text: \(text)")
        #expect(layout.lines.map(\.text).allSatisfy { !wholly.contains($0) })
    }

    @Test("3 pt text is reported as too small")
    func tooSmall() throws {
        let layout = try Self.layout([
            Self.line("Big enough", size: 6, x: 100, y: 700),
            Self.line("Too small to read", size: 3, x: 100, y: 600),
            Self.line("Shrunk by the transform", size: 12, x: 100, y: 500, scale: 0.25),
        ])
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        #expect(violations == [.glyphTooSmall(page: 0, text: "Too small to read"), .glyphTooSmall(page: 0, text: "Shrunk by the transform")])
    }

    @Test("a rotated page is measured in its own page space")
    func rotatedPage() throws {
        let lines = [Self.line("Inside the page", size: 12, x: 100, y: 700), Self.line("Near the right edge", size: 12, x: 450, y: 100)]
        let upright = DrawnPDF.pages([lines])
        let turned = try #require(PDFKitInspector().layout(of: DrawnPDF.rotated(upright, by: 90)))
        let plain = try #require(PDFKitInspector().layout(of: upright))
        #expect(turned.pages == plain.pages)
        #expect(turned.lines.count == plain.lines.count)
        for (rotated, straight) in zip(turned.lines, plain.lines) {
            #expect(rotated.text == straight.text && Self.close(rotated.box, straight.box), "\(rotated) against \(straight)")
        }
        #expect(GeometricCompleteness.violations(in: turned, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight).isEmpty)
    }

    @Test("a line with no font attribute fails closed")
    func noFont() throws {
        #if os(macOS)
        let big = NSFont.systemFont(ofSize: 12), small = NSFont.systemFont(ofSize: 3)
        #else
        let big = UIFont.systemFont(ofSize: 12), small = UIFont.systemFont(ofSize: 3)
        #endif
        #expect(PDFKitInspector.glyphHeight(of: nil) == nil)
        #expect(PDFKitInspector.glyphHeight(of: NSAttributedString(string: "")) == nil)
        #expect(PDFKitInspector.glyphHeight(of: NSAttributedString(string: "No font")) == nil)
        let mixed = NSMutableAttributedString(string: "Sized", attributes: [.font: big])
        mixed.append(NSAttributedString(string: " and not"))
        #expect(PDFKitInspector.glyphHeight(of: mixed) == nil)
        let two = NSMutableAttributedString(string: "Twelve", attributes: [.font: big])
        two.append(NSAttributedString(string: " and three", attributes: [.font: small]))
        #expect(PDFKitInspector.glyphHeight(of: two) == 3)
    }

    @Test("what is not a PDF has no layout")
    func notAPDF() {
        #expect(PDFKitInspector().layout(of: Data("not a PDF".utf8)) == nil)
        #expect(PDFKitInspector().layout(of: Data()) == nil)
    }
}
#endif
