#if canImport(PDFKit)   // Apple platforms only (R11)
import CoreGraphics
import CoreText
import Foundation
import PDFKit

/// PDFs drawn with CoreGraphics and CoreText at known positions and sizes: text a renderer would never place, such as
/// text past an edge or too small to read, so the geometry check can be shown to find it on a real PDFKit reading.
public enum DrawnPDF {
    /// One line of Helvetica: `size` points, its baseline starting at (`x`, `y`) in page space, drawn under a `scale`
    /// transform (1 draws it as is; 0.25 draws 12 pt text at 3 pt).
    public struct Line: Sendable {
        public let text: String
        public let size: Double
        public let x: Double
        public let y: Double
        public let scale: Double

        public init(text: String, size: Double, x: Double, y: Double, scale: Double) {
            self.text = text
            self.size = size
            self.x = x
            self.y = y
            self.scale = scale
        }
    }

    /// An A4 PDF (595 x 842 pt) with one page per element of `pages`.
    public static func pages(_ pages: [[Line]]) -> Data {
        let data = NSMutableData()
        var media = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { return Data() }
        for page in pages {
            context.beginPDFPage(nil)
            for item in page {
                context.saveGState()
                context.scaleBy(x: item.scale, y: item.scale)
                let font = CTFontCreateWithName("Helvetica" as CFString, item.size, nil)
                let attributed = NSAttributedString(
                    string: item.text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                let line = CTLineCreateWithAttributedString(attributed)
                context.textPosition = CGPoint(x: item.x / item.scale, y: item.y / item.scale)
                CTLineDraw(line, context)
                context.restoreGState()
            }
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    /// `data` with its first page rotated by `degrees` (a multiple of 90), as a reader would show it turned.
    public static func rotated(_ data: Data, by degrees: Int) -> Data {
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else { return Data() }
        page.rotation = degrees
        return document.dataRepresentation() ?? Data()
    }
}
#endif
