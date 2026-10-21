#if canImport(PDFKit)
import Foundation
import PDFKit
import PrestoCVImporting
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Reads a PDF's words with PDFKit: each word with its box in page space (origin at the top left), its font size and
/// whether it is bold, in PDFKit's order (ADR 0027). It decides nothing about the reading order: PDFKit does not
/// promise one, and the core orders the words, tested on Linux. It opens no connection and keeps nothing.
public struct PDFKitTextExtractor: PDFTextExtracting {

    public init() {}

    public func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout {
        try Task.checkCancellation()
        guard data.count <= limits.maximumPDFBytes else { throw ImportError.tooLarge }
        guard let document = PDFDocument(data: data) else { throw ImportError.unreadable }
        // A PDF that opens with no password has `isLocked` false even when it is encrypted
        guard !document.isLocked else { throw ImportError.encrypted }
        guard document.pageCount > 0 else { throw ImportError.empty }
        guard document.pageCount <= limits.maximumPages else { throw ImportError.tooManyPages }
        var pages: [ExtractedPage] = []
        var characters = 0
        var words = 0
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let extracted = Self.words(of: page)
            characters += extracted.words.reduce(0) { $0 + $1.text.count }
            words += extracted.words.count
            guard characters <= limits.maximumCharacters, words <= limits.maximumWords else { throw ImportError.tooLarge }
            pages.append(extracted)
        }
        return .pages(pages)
    }

    // MARK: Words

    /// The words of a page: runs of characters without white space, split where PDFKit puts a space or a line
    /// break, or where a gap wider than a third of the font size separates two glyphs.
    ///
    /// `characterBounds(at:)` has no box for the line breaks that `PDFPage.string` holds: every line break shifts the
    /// boxes of the rest of the page by one (Apple's FB16264926, seen on iOS 18 and macOS 26). So the string and the
    /// boxes are walked together, and a line break takes no box. A space takes one, whether the PDF draws it or PDFKit
    /// adds it across a gap. A box is a glyph's ink; a word gets the ink's width and a height from its font size, so that
    /// lines of digits and of capitals stand as tall as any other.
    static func words(of page: PDFPage) -> ExtractedPage {
        let bounds = page.bounds(for: .cropBox)
        let size = page.rotation % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
        guard let string = page.string else { return ExtractedPage(width: size.width, height: size.height, words: []) }
        let text = string as NSString
        let attributed = page.attributedString
        let styled = attributed?.length == text.length

        var words: [ExtractedWord] = []
        var current = ""
        var ink = CGRect.null
        var fontSize = 0.0
        var isBold = true
        func close() {
            if !current.isEmpty, !ink.isNull {
                // Page space has its origin at the bottom left; the core's at the top left
                let middle = bounds.maxY - ink.midY
                let height = 0.925 * fontSize
                words.append(ExtractedWord(
                    text: current, frame: Rect(x: ink.minX - bounds.minX, y: middle - height / 2, width: ink.width, height: height),
                    fontSize: fontSize, isBold: isBold
                ))
            }
            current = ""
            ink = .null
            fontSize = 0
            isBold = true
        }

        var index = 0
        var glyph = 0
        while index < text.length {
            let unit = text.character(at: index)
            let length = CFStringIsSurrogateHighCharacter(unit) && index + 1 < text.length ? 2 : 1
            let character = text.substring(with: NSRange(location: index, length: length))
            if character == "\n" || character == "\r" || character == "\u{2028}" {
                // A line break PDFKit adds: no glyph
                close()
                index += length
                continue
            }
            if character.allSatisfy(\.isWhitespace) {
                // A space has a box, whether the PDF draws it or PDFKit adds it across a gap
                close()
                glyph += length
                index += length
                continue
            }
            let box = page.characterBounds(at: glyph)
            let style = styled ? Self.style(at: index, in: attributed) : (size: Double(box.height), bold: false)
            if !ink.isNull, !box.isEmpty {
                let gap = box.minX - ink.maxX
                let reach = max(style.size, fontSize)
                let sameLine = abs(box.midY - ink.midY) < reach * 0.6
                if gap > reach / 3 || gap < -reach || !sameLine { close() }
            }
            if !box.isEmpty {
                current += character
                ink = ink.isNull ? box : ink.union(box)
                fontSize = max(fontSize, style.size)
                isBold = isBold && style.bold
            }
            glyph += length
            index += length
        }
        close()
        return ExtractedPage(width: size.width, height: size.height, words: words)
    }

    /// The font size at a character, and whether its font is bold: by its traits, or by its name, as many PDF fonts
    /// carry no traits.
    private static func style(at index: Int, in attributed: NSAttributedString?) -> (size: Double, bold: Bool) {
        #if canImport(UIKit)
        guard let font = attributed?.attribute(.font, at: index, effectiveRange: nil) as? UIFont else { return (0, false) }
        let traitBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
        #else
        guard let font = attributed?.attribute(.font, at: index, effectiveRange: nil) as? NSFont else { return (0, false) }
        let traitBold = font.fontDescriptor.symbolicTraits.contains(.bold)
        #endif
        let name = font.fontName.lowercased()
        let namedBold = ["bold", "black", "heavy", "semibold", "demi"].contains { name.contains($0) }
        return (Double(font.pointSize), traitBold || namedBold)
    }
}
#endif
