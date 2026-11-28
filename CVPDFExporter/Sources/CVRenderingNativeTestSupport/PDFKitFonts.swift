#if canImport(PDFKit)   // Apple platforms only (R11)
import Foundation
import PDFKit
#if os(macOS)
import AppKit
private typealias PlatformFont = NSFont
#else
import UIKit
private typealias PlatformFont = UIFont
#endif

/// The letter sizes PDFKit's fonts give a PDF's lines: how the inspector sized lines before #562, kept as the oracle
/// the reading from the page's text operators is checked against. Slow and verbose for the system font, so only tests
/// use it.
public enum PDFKitFonts {
    /// A line of text, as PDFKit's line selections give it, and the smallest point size of the fonts of its characters
    /// (nil when one of them has none).
    public struct Line: Sendable, Equatable {
        public let page: Int
        public let text: String
        public let height: Double?

        public init(page: Int, text: String, height: Double?) {
            self.page = page
            self.text = text
            self.height = height
        }
    }

    /// Every line of `data` with text, page by page, or nil when PDFKit cannot read it.
    public static func lines(of data: Data) -> [Line]? {
        guard let document = PDFDocument(data: data) else { return nil }
        var lines: [Line] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), page.numberOfCharacters > 0,
                  let selection = page.selection(for: NSRange(location: 0, length: page.numberOfCharacters)) else { continue }
            for line in selection.selectionsByLine() {
                let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                lines.append(Line(page: index, text: text, height: smallestFontSize(of: line.attributedString)))
            }
        }
        return lines
    }

    private static func smallestFontSize(of text: NSAttributedString?) -> Double? {
        guard let text, text.length > 0 else { return nil }
        var sizes: [Double] = []
        var everyCharacterHasAFont = true
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let font = value as? PlatformFont { sizes.append(Double(font.pointSize)) } else { everyCharacterHasAFont = false }
        }
        return everyCharacterHasAFont ? sizes.min() : nil
    }
}
#endif
