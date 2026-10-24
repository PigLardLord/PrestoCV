#if canImport(PDFKit)
import CoreGraphics
import Foundation
import PDFKit
import PrestoCVImporting

/// How heavy the strokes of the words of a page are, measured on the page as it is drawn: whether a word is bold when
/// PDFKit cannot say (#287).
///
/// PDFKit finds the weight of a word in the font it makes of the PDF's embedded font. When it cannot find one, because
/// the PDF embeds a subset under a name that no installed font has, or as a CID font, it gives back a plain Times or
/// Helvetica for every run: the bold headings of such a PDF are read as regular, and a CV whose headings are read as
/// regular text has no sections. The ink does not depend on a name. A bold font draws strokes about two fifths wider
/// than its regular's, whatever the font is. The width of the strokes of a word is twice its ink over the length of
/// its edge: the ink is the sum of the pixels' distances from the background, the edge the sum of the pixels' steps to
/// their neighbours, so that a pixel half covered counts for half in both. It needs no threshold, reads every pixel
/// of the box, and does not depend on the letters' shapes as a count of the strokes that cross some rows does. A word
/// is bold when its strokes, in ems, are clearly wider than the median word's of its page: a CV is mostly regular text.
///
/// A PDF is untrusted input (R8). The page is drawn in a bitmap of at most `maximumPixels` at a fixed scale, a page
/// too large for it is not measured, and a page reads at most `maximumReads` pixels in all: past them, the words left
/// keep the weight their fonts give.
enum InkWeight {

    // MARK: Limits

    /// Pixels per point of the drawn page. At two a stroke of a small font is two pixels wide and a bold cannot be told
    /// from a regular.
    static let scale = 4.0
    static let maximumPixels = 24_000_000.0
    static let maximumReads = 64_000_000
    static let wordsBetweenChecks = 256

    // MARK: Measure

    /// The pixel levels between a word's background and its darkest ink, below which it has no ink to measure.
    static let minimumContrast = 64
    /// The smallest box, in pixels on each side, whose edges are measured.
    static let minimumSide = 3
    /// A word of fewer characters is not measured: of a few straight letters, as "BI" or "11", it measures heavier than
    /// the round letters of its page do.
    static let minimumCharacters = 3

    // MARK: Decision

    /// The measured words a page needs before its median means anything.
    static let minimumWords = 8
    /// A word is bold when its strokes are this much wider than the page's median.
    static let heavyRatio = 1.2

    // MARK: Page

    /// For each of `words`, whether its strokes are heavy against the page's: all false when the page cannot be measured.
    /// - Parameters:
    ///   - bounds: the page's crop box, the origin of the words' frames.
    static func heavyWords(on page: PDFPage, bounds: CGRect, words: [ExtractedWord]) throws -> [Bool] {
        let none = [Bool](repeating: false, count: words.count)
        // A rotated page is drawn turned, and its words' frames are in the page as it is shown
        guard page.rotation == 0, words.count >= minimumWords, fits(bounds.size) else { return none }
        try Task.checkCancellation()
        guard let bitmap = draw(page, bounds: bounds) else { return none }
        let weights = try bitmap.pixels.withUnsafeBufferPointer {
            try strokeWidths(of: words, in: $0, width: bitmap.width)
        }
        return heavy(weights)
    }

    /// The stroke width of each word, nil for a word that is too short, has no letter (a bullet, a dash, a number) or
    /// cannot be measured.
    static func strokeWidths(of words: [ExtractedWord], in pixels: UnsafeBufferPointer<UInt8>, width: Int) throws -> [Double?] {
        var weights: [Double?] = []
        weights.reserveCapacity(words.count)
        var reads = 0
        for (index, word) in words.enumerated() {
            if index % wordsBetweenChecks == 0 { try Task.checkCancellation() }
            guard word.text.count >= minimumCharacters, word.text.contains(where: \.isLetter) else {
                weights.append(nil)
                continue
            }
            let box = PixelBox(
                left: Int((word.frame.x * scale).rounded(.down)), right: Int((word.frame.maxX * scale).rounded(.up)),
                top: Int((word.frame.y * scale).rounded(.down)), bottom: Int((word.frame.maxY * scale).rounded(.up))
            )
            weights.append(strokeWidth(in: pixels, width: width, box: box, em: word.fontSize * scale, reads: &reads))
        }
        return weights
    }

    /// Whether a page of this size is drawn in at most `maximumPixels`.
    static func fits(_ size: CGSize) -> Bool {
        let area = Double(size.width) * Double(size.height)
        return area > 0 && size.width.isFinite && size.height.isFinite && area * scale * scale <= maximumPixels
    }

    /// The page in grey levels, black on white, row 0 at the top.
    static func draw(_ page: PDFPage, bounds: CGRect) -> Bitmap? {
        let width = Int((Double(bounds.width) * scale).rounded(.up))
        let height = Int((Double(bounds.height) * scale).rounded(.up))
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .cropBox, to: context)
            return true
        }
        return drawn ? Bitmap(pixels: pixels, width: width) : nil
    }

    struct Bitmap {
        let pixels: [UInt8]
        let width: Int
    }

    /// A box in a bitmap, in pixels: the left and the top included, the right and the bottom not.
    struct PixelBox {
        let left: Int
        let right: Int
        let top: Int
        let bottom: Int
    }

    // MARK: Word

    /// The width, in ems, of the strokes in a box: twice the ink over the length of the edges. The background is the
    /// box's median level, so light strokes on a dark ground measure as dark ones on a light ground.
    /// - Returns: nil when the box is too small, has too little contrast to hold ink, or once the page has read its
    ///   `maximumReads`.
    static func strokeWidth(in pixels: UnsafeBufferPointer<UInt8>, width: Int, box: PixelBox, em: Double, reads: inout Int) -> Double? {
        guard width > 0, em > 0 else { return nil }
        let left = max(0, box.left)
        let right = min(width, box.right)
        let top = max(0, box.top)
        let bottom = min(pixels.count / width, box.bottom)
        guard right - left >= minimumSide, bottom - top >= minimumSide else { return nil }
        // Two passes over the box: the background, then the ink and the edges
        reads += 2 * (right - left) * (bottom - top)
        guard reads <= maximumReads else { return nil }

        var histogram = [Int](repeating: 0, count: 256)
        for row in top..<bottom {
            for column in left..<right { histogram[Int(pixels[row * width + column])] += 1 }
        }
        let background = median(of: histogram)
        let contrast = histogram.indices.filter { histogram[$0] > 0 }.map { abs($0 - background) }.max() ?? 0
        guard contrast >= minimumContrast else { return nil }

        var ink = 0
        var edge = 0.0
        for row in top..<bottom {
            for column in left..<right {
                let level = Int(pixels[row * width + column])
                ink += abs(level - background)
                // The steps to the next pixel on the right and to the one above, none past the box
                let across = column + 1 < right ? level - Int(pixels[row * width + column + 1]) : 0
                let up = row > top ? level - Int(pixels[(row - 1) * width + column]) : 0
                edge += Double(across * across + up * up).squareRoot()
            }
        }
        guard edge > 0 else { return nil }
        return 2 * Double(ink) / edge / em
    }

    /// The level that half of the pixels are at or below.
    private static func median(of histogram: [Int]) -> Int {
        let total = histogram.reduce(0, +)
        var seen = 0
        for level in histogram.indices {
            seen += histogram[level]
            if seen * 2 > total { return level }
        }
        return 255
    }

    // MARK: Page median

    /// Whether each weight is clearly heavier than the page's median: nothing is, on a page with few measured words.
    static func heavy(_ weights: [Double?]) -> [Bool] {
        let measured = weights.compactMap { $0 }.sorted()
        guard measured.count >= minimumWords else { return weights.map { _ in false } }
        let limit = measured[measured.count / 2] * heavyRatio
        return weights.map { ($0 ?? 0) >= limit }
    }
}
#endif
