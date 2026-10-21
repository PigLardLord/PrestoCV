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
        var budget = Budget(characters: limits.maximumCharacters, words: limits.maximumWords)
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            pages.append(try Self.words(of: page, budget: &budget))
        }
        return .pages(pages)
    }

    // MARK: Words

    /// What the pages still to read may hold: the characters and the words left of the limits.
    struct Budget {
        var characters: Int
        var words: Int
    }

    /// The characters read between two checks for the task's cancellation.
    private static let charactersBetweenChecks = 256

    /// The words of a page: runs of characters without white space, split where PDFKit puts a space or a line
    /// break, or where a gap wider than a third of the font size separates two glyphs.
    ///
    /// `characterBounds(at:)` has no box for the line breaks that `PDFPage.string` holds: every line break shifts the
    /// boxes of the rest of the page by one (Apple's FB16264926, seen on iOS 18 and macOS 26). So the string and the
    /// boxes are walked together, and a line break takes no box. A space takes one, whether the PDF draws it or PDFKit
    /// adds it across a gap. A box is a glyph's ink; a word gets the ink's width and a height from its font size, so that
    /// lines of digits and of capitals stand as tall as any other.
    ///
    /// A few kilobytes of a PDF's stream can hold a million characters (R8). The page's text, spaces and line breaks
    /// included, is counted as a pasted text is, in UTF-16 units, and a page over the characters left is refused before
    /// its style and its glyphs are read. Its words are counted as they are read, and the reading stops once its task
    /// is cancelled.
    /// - Throws: `ImportError.tooLarge` over the characters or the words left; `CancellationError`.
    static func words(of page: PDFPage, budget: inout Budget) throws -> ExtractedPage {
        let bounds = page.bounds(for: .cropBox)
        let size = page.rotation % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
        guard let string = page.string else { return ExtractedPage(width: size.width, height: size.height, words: []) }
        let text = string as NSString
        guard text.length <= budget.characters else { throw ImportError.tooLarge }
        budget.characters -= text.length
        try Task.checkCancellation()
        let attributed = page.attributedString
        let styled = attributed?.length == text.length

        var words: [ExtractedWord] = []
        var current = ""
        var ink = CGRect.null
        var fontSize = 0.0
        var isBold = true
        let wordsLeft = budget.words
        func close() throws {
            if !current.isEmpty, !ink.isNull {
                guard words.count < wordsLeft else { throw ImportError.tooLarge }
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
        var read = 0
        while index < text.length {
            read += 1
            if read % charactersBetweenChecks == 0 { try Task.checkCancellation() }
            let unit = text.character(at: index)
            let length = CFStringIsSurrogateHighCharacter(unit) && index + 1 < text.length ? 2 : 1
            let character = text.substring(with: NSRange(location: index, length: length))
            if character == "\n" || character == "\r" || character == "\u{2028}" {
                // A line break PDFKit adds: no glyph
                try close()
                index += length
                continue
            }
            if character.allSatisfy(\.isWhitespace) {
                // A space has a box, whether the PDF draws it or PDFKit adds it across a gap
                try close()
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
                if gap > reach / 3 || gap < -reach || !sameLine { try close() }
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
        try close()
        budget.words -= words.count
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
