#if canImport(PDFKit)
import CoreGraphics
import Foundation
import PrestoCVImporting
import Testing
@testable import PrestoCVImportingPDFKit

/// The measure of the strokes of a word (`InkWeight`), on bitmaps drawn by hand.
@Suite("Measuring the weight of the ink")
struct InkWeightTests {

    /// A grey bitmap, row 0 at the top.
    private struct Canvas {
        let width: Int
        let height: Int
        var pixels: [UInt8]

        init(width: Int = 240, height: Int = 60, level: UInt8 = 255) {
            self.width = width
            self.height = height
            pixels = [UInt8](repeating: level, count: width * height)
        }

        /// A vertical bar over the whole height, with the levels of its pixels from the left.
        mutating func bar(at x: Int, levels: [UInt8]) {
            for row in 0..<height {
                for (offset, level) in levels.enumerated() { pixels[row * width + x + offset] = level }
            }
        }

        /// The rows from `first` on in a grey, under what is drawn next.
        mutating func shade(from first: Int, level: UInt8) {
            for row in first..<height {
                for column in 0..<width { pixels[row * width + column] = level }
            }
        }

        /// A line of ink across the box, `thickness` pixels high, from row `first`.
        mutating func rule(from first: Int, thickness: Int, ink: UInt8 = 0) {
            for row in first..<(first + thickness) {
                for column in 0..<width { pixels[row * width + column] = ink }
            }
        }

        /// Bars of `thickness` pixels, every `period` pixels.
        mutating func bars(thickness: Int, every period: Int = 12, ink: UInt8 = 0) {
            var x = 6
            while x + thickness < width - 6 {
                bar(at: x, levels: [UInt8](repeating: ink, count: thickness))
                x += period
            }
        }

        /// Rings of `thickness` pixels, whose outer radius is `radius`, side by side.
        mutating func rings(thickness: Double, radius: Double = 24) {
            for centre in stride(from: 40.0, to: Double(width), by: 80) {
                for row in 0..<height {
                    for column in 0..<width {
                        let distance = ((Double(column) - centre) * (Double(column) - centre)
                            + (Double(row) - Double(height) / 2) * (Double(row) - Double(height) / 2)).squareRoot()
                        if distance < radius, distance >= radius - thickness { pixels[row * width + column] = 0 }
                    }
                }
            }
        }

        func measure(em: Double = 40, box: InkWeight.PixelBox? = nil, reads: Int = 0) -> Double? {
            var reads = reads
            return pixels.withUnsafeBufferPointer {
                InkWeight.strokeWidth(
                    in: $0, width: width, box: box ?? InkWeight.PixelBox(left: 0, right: width, top: 0, bottom: height), em: em, reads: &reads
                )
            }
        }
    }

    @Test("A stroke is measured in ems: bars of four pixels in a 40 pixel em are a tenth, of six pixels 0.15")
    func inEms() throws {
        var regular = Canvas()
        regular.bars(thickness: 4)
        var bold = Canvas()
        bold.bars(thickness: 6)
        #expect(abs(try #require(regular.measure()) - 0.1) < 0.005)
        #expect(abs(try #require(bold.measure()) - 0.15) < 0.005)
        // The same strokes in a font twice as large are half as wide in ems
        #expect(abs(try #require(regular.measure(em: 80)) - 0.05) < 0.005)
    }

    @Test("A pixel half covered counts for half, so the edges of a smooth stroke add up")
    func partlyCoveredPixels() throws {
        var canvas = Canvas()
        for x in stride(from: 6, to: 200, by: 12) { canvas.bar(at: x, levels: [255, 128, 0, 0, 0, 128, 255]) }
        // 3 pixels of ink and two halves
        #expect(abs(try #require(canvas.measure()) - 0.1) < 0.005)
    }

    @Test("Light strokes on a dark background measure as dark ones on a light background")
    func lightOnDark() throws {
        var dark = Canvas(level: 0)
        dark.bars(thickness: 4, ink: 255)
        #expect(abs(try #require(dark.measure()) - 0.1) < 0.005)
        // Ink that is only a little darker than the page is still measured by its own contrast
        var grey = Canvas(level: 255)
        grey.bars(thickness: 4, ink: 150)
        #expect(abs(try #require(grey.measure()) - 0.1) < 0.005)
    }

    @Test("The weights of round and of straight strokes grow alike: a bold is half as wide again as a regular in both")
    func shapeDoesNotMatter() throws {
        var regularBars = Canvas()
        regularBars.bars(thickness: 4)
        var boldBars = Canvas()
        boldBars.bars(thickness: 6)
        var regularRings = Canvas()
        regularRings.rings(thickness: 4)
        var boldRings = Canvas()
        boldRings.rings(thickness: 6)
        let bars = try #require(boldBars.measure()) / #require(regularBars.measure())
        let rings = try #require(boldRings.measure()) / #require(regularRings.measure())
        #expect(abs(bars - 1.5) < 0.05)
        #expect(abs(rings - 1.5) < 0.1)
    }

    @Test("A box without ink, with too little contrast or too small has no weight")
    func nothingToMeasure() {
        #expect(Canvas().measure() == nil)
        var faint = Canvas()
        faint.bars(thickness: 4, ink: 220)
        #expect(faint.measure() == nil)
        var bars = Canvas()
        bars.bars(thickness: 4)
        #expect(bars.measure(box: InkWeight.PixelBox(left: 10, right: 11, top: 0, bottom: 60)) == nil)
        #expect(bars.measure(box: InkWeight.PixelBox(left: 0, right: 240, top: 20, bottom: 22)) == nil)
        #expect(bars.measure(em: 0) == nil)
    }

    @Test("A box that is partly shaded has no weight: the shade is ink with an edge only at its border", arguments: [160, 200] as [UInt8])
    func partlyShaded(level: UInt8) throws {
        // The lower two fifths of the box stand on a grey, as a band behind the foot of a line
        var shaded = Canvas()
        shaded.shade(from: 36, level: level)
        shaded.bars(thickness: 4)
        #expect(shaded.measure() == nil, "shade at level \(level)")
    }

    @Test("A box that is shaded but for a strip has no weight: the strip is what differs from the box's median")
    func mostlyShaded() {
        var canvas = Canvas()
        canvas.shade(from: 12, level: 140)
        canvas.bars(thickness: 4)
        #expect(canvas.measure() == nil)
    }

    @Test("A shade so light that it adds a few hundredths to the ink is tolerated: the box is measured, a little heavier")
    func lightShade() throws {
        var plain = Canvas()
        plain.bars(thickness: 4)
        var shaded = Canvas()
        shaded.shade(from: 36, level: 245)
        shaded.bars(thickness: 4)
        let base = try #require(plain.measure())
        let measured = try #require(shaded.measure())
        #expect(measured >= base && measured <= base * 1.08, "\(measured) against \(base)")
    }

    @Test("A box wholly on a grey or on a dark ground is measured as on a white one; a thin shade does not decide")
    func uniformGround() throws {
        for ground in [UInt8(200), 120, 30] {
            var canvas = Canvas(level: ground)
            canvas.bars(thickness: 4, ink: ground > 100 ? 0 : 255)
            #expect(abs(try #require(canvas.measure()) - 0.1) < 0.005, "ground \(ground)")
        }
        // A single row of a grey at the foot of the box is under the share of the ink that a shade may have
        var thin = Canvas()
        thin.shade(from: 59, level: 160)
        thin.bars(thickness: 4)
        #expect(abs(try #require(thin.measure()) - 0.1) < 0.01)
    }

    @Test("A hairline across the box, an underline or a border, is a stroke of its own: it is not taken for a shade")
    func ruleAcrossTheBox() throws {
        var plain = Canvas()
        plain.bars(thickness: 4)
        var underlined = plain
        underlined.rule(from: 52, thickness: 2)
        let base = try #require(plain.measure())
        #expect(try #require(underlined.measure()) <= base * 1.05)
    }

    @Test("A box that reaches past the bitmap is cut to it; one wholly outside has no weight")
    func clamped() throws {
        var canvas = Canvas()
        canvas.bars(thickness: 4)
        let past = InkWeight.PixelBox(left: -50, right: 500, top: -20, bottom: 300)
        #expect(abs(try #require(canvas.measure(box: past)) - 0.1) < 0.005)
        #expect(canvas.measure(box: InkWeight.PixelBox(left: 300, right: 400, top: 0, bottom: 60)) == nil)
        #expect(canvas.measure(box: InkWeight.PixelBox(left: 0, right: 240, top: 100, bottom: 160)) == nil)
    }

    @Test("A page reads a bounded number of pixels, and a word counts both its passes: past them, it has no weight")
    func readsAreBounded() throws {
        var canvas = Canvas()
        canvas.bars(thickness: 4)
        let box = 2 * 240 * 60
        #expect(canvas.measure(reads: InkWeight.maximumReads - box) != nil)
        #expect(canvas.measure(reads: InkWeight.maximumReads - box + 1) == nil)
        var reads = 0
        canvas.pixels.withUnsafeBufferPointer {
            _ = InkWeight.strokeWidth(in: $0, width: 240, box: InkWeight.PixelBox(left: 0, right: 240, top: 0, bottom: 60), em: 40, reads: &reads)
        }
        #expect(reads == box)
    }

    @Test("A word of fewer than three characters, or without a letter, is not measured")
    func shortWords() throws {
        var canvas = Canvas(width: 400, height: 80)
        canvas.bars(thickness: 4)
        func word(_ text: String) -> ExtractedWord {
            ExtractedWord(text: text, frame: Rect(x: 2, y: 2, width: 90, height: 16), fontSize: 10, isBold: false)
        }
        let weights = try canvas.pixels.withUnsafeBufferPointer {
            try InkWeight.strokeWidths(of: ["Abc", "BI", "11", "···", "Abcdef"].map(word), in: $0, width: 400)
        }
        #expect(weights.map { $0 != nil } == [true, false, false, false, true])
        #expect(abs(try #require(weights[0]) - 0.1) < 0.01)
    }

    @Test("A word is heavy when it is a fifth heavier than the page's median; a page of few words decides nothing")
    func heavyAgainstTheMedian() {
        let regular = [Double?](repeating: 0.1, count: 10)
        #expect(InkWeight.heavy(regular + [0.14, 0.13, 0.11, 0.09, nil]) == [Bool](repeating: false, count: 10) + [true, true, false, false, false])
        #expect(InkWeight.heavy(regular) == [Bool](repeating: false, count: 10))
        let few = [Double?](repeating: 0.1, count: InkWeight.minimumWords - 2) + [0.2]
        #expect(InkWeight.heavy(few) == [Bool](repeating: false, count: few.count))
    }

    @Test("The median is the regular text's as long as the regular words are the most; past half, the bold is the page's text")
    func manyBoldWords() {
        for bold in [6, 10, 11] {
            let weights = [Double?](repeating: 0.1, count: 24 - bold) + [Double?](repeating: 0.14, count: bold)
            let heavy = InkWeight.heavy(weights)
            #expect(heavy.count(where: { $0 }) == bold, "\(bold) bold of 24")
        }
        let mostlyBold = InkWeight.heavy([Double?](repeating: 0.1, count: 10) + [Double?](repeating: 0.14, count: 14))
        #expect(!mostlyBold.contains(true))
    }

    @Test("A page is drawn if it needs at most the pixels allowed: an A3 sheet is, a poster or a page without a size is not")
    func fits() {
        #expect(InkWeight.fits(CGSize(width: 595, height: 842)))
        #expect(InkWeight.fits(CGSize(width: 842, height: 1_191)))
        #expect(!InkWeight.fits(CGSize(width: 1_500, height: 2_000)))
        #expect(!InkWeight.fits(CGSize(width: 14_400, height: 14_400)))
        #expect(!InkWeight.fits(.zero))
        #expect(!InkWeight.fits(CGSize(width: CGFloat.infinity, height: 800)))
        #expect(!InkWeight.fits(CGSize(width: CGFloat.nan, height: 800)))
    }

    @Test("A sliver of a page is not drawn: its area is small, but each side is rounded up to a whole pixel")
    func sliver() {
        // 0.001 by 1e9 points is an area of a million, and a bitmap of one pixel by four billion
        #expect(!InkWeight.fits(CGSize(width: 0.001, height: 1e9)))
        #expect(!InkWeight.fits(CGSize(width: 1e9, height: 0.001)))
        #expect(!InkWeight.fits(CGSize(width: 0.001, height: 1e300)))
        #expect(InkWeight.fits(CGSize(width: 0.001, height: 1e6)))
    }

    @Test("A frame that is not finite, or lies far past the bitmap, has no weight and traps nothing")
    func hostileFrames() throws {
        var canvas = Canvas(width: 400, height: 80)
        canvas.bars(thickness: 4)
        let fine = Rect(x: 2, y: 2, width: 90, height: 16)
        func word(_ frame: Rect, size: Double = 10) -> ExtractedWord {
            ExtractedWord(text: "Abcdef", frame: frame, fontSize: size, isBold: false)
        }
        let words = [
            word(Rect(x: 1e300, y: 2, width: 90, height: 16)),
            word(Rect(x: -1e300, y: 2, width: 90, height: 16)),
            word(Rect(x: 1e19, y: 2, width: 90, height: 16)),
            word(Rect(x: 2, y: 1e19, width: 90, height: 16)),
            word(Rect(x: .nan, y: 2, width: 90, height: 16)),
            word(Rect(x: 2, y: 2, width: .infinity, height: 16)),
            word(Rect(x: 2, y: 2, width: 90, height: .nan)),
            word(Rect(x: 1e308, y: 2, width: 1e308, height: 16)),
            word(fine, size: .infinity),
            word(fine, size: .nan),
            word(fine, size: -10),
            word(fine),
        ]
        let weights = try canvas.pixels.withUnsafeBufferPointer { try InkWeight.strokeWidths(of: words, in: $0, width: 400) }
        #expect(weights.map { $0 != nil } == [Bool](repeating: false, count: words.count - 1) + [true])
    }
}
#endif
