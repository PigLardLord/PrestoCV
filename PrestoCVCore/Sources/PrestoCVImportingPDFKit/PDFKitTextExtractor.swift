#if canImport(PDFKit)
import DiagnosticLogging
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
///
/// It logs the pages and the words it read, and the limit that stopped it (ADR 0030): counts and names, never a word.
/// The import logs every failure by its kind.
public struct PDFKitTextExtractor: PDFTextExtracting {
    private let logger: any DiagnosticLogger

    public init(logger: any DiagnosticLogger) {
        self.logger = logger
    }

    public func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout {
        do {
            let pages = try read(data, limits: limits)
            logger.info(.importing, "pdf.read", .count("pages", pages.count), .count("words", pages.reduce(0) { $0 + $1.words.count }))
            return .pages(pages)
        } catch let reached as LimitReached {
            logger.notice(.importing, "pdf.limit", .token("limit", reached.logName))
            throw reached.importError
        }
    }

    private func read(_ data: Data, limits: ImportLimits) throws -> [ExtractedPage] {
        try Task.checkCancellation()
        guard data.count <= limits.maximumPDFBytes else { throw LimitReached(.bytes) }
        guard let document = PDFDocument(data: data) else { throw ImportError.unreadable }
        // A PDF that opens with no password has `isLocked` false even when it is encrypted
        guard !document.isLocked else { throw ImportError.encrypted }
        guard document.pageCount > 0 else { throw ImportError.empty }
        guard document.pageCount <= limits.maximumPages else { throw LimitReached(.pages) }
        var pages: [ExtractedPage] = []
        var budget = Budget(characters: limits.maximumCharacters, words: limits.maximumWords)
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            pages.append(try Self.words(of: page, budget: &budget))
        }
        return pages
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
    /// - Throws: `LimitReached` over the characters or the words left; `CancellationError`.
    static func words(of page: PDFPage, budget: inout Budget) throws -> ExtractedPage {
        let bounds = page.bounds(for: .cropBox)
        let size = page.rotation % 180 == 0 ? bounds.size : CGSize(width: bounds.height, height: bounds.width)
        guard let string = page.string else { return ExtractedPage(width: size.width, height: size.height, words: []) }
        let text = string as NSString
        guard text.length <= budget.characters else { throw LimitReached(.characters) }
        budget.characters -= text.length
        try Task.checkCancellation()
        let attributed = page.attributedString
        let styled = attributed?.length == text.length
        var colours = Colours(attributed: styled ? attributed : nil)

        var words: [ExtractedWord] = []
        // The level of each word's colour, nil for a word of several colours or of none known
        var levels: [Int?] = []
        var current = ""
        var ink = CGRect.null
        var fontSize = 0.0
        var isBold = true
        var level: Int?
        let wordsLeft = budget.words
        func close() throws {
            if !current.isEmpty, !ink.isNull {
                guard words.count < wordsLeft else { throw LimitReached(.words) }
                // Page space has its origin at the bottom left; the core's at the top left
                let middle = bounds.maxY - ink.midY
                let height = 0.925 * fontSize
                words.append(ExtractedWord(
                    text: current, frame: Rect(x: ink.minX - bounds.minX, y: middle - height / 2, width: ink.width, height: height),
                    fontSize: fontSize, isBold: isBold
                ))
                levels.append(level)
            }
            current = ""
            ink = .null
            fontSize = 0
            isBold = true
            level = nil
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
                let colour = colours.level(at: index)
                level = current.isEmpty || level == colour ? colour : nil
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
        return ExtractedPage(
            width: size.width, height: size.height, words: try withInkWeights(words, levels: levels, on: page, bounds: bounds)
        )
    }

    /// The words, bold where their fonts say it or their strokes are clearly heavier than the page's: PDFKit gives back
    /// a plain font for a font it cannot name, and a PDF's headings are bold in the ink only (`InkWeight`). A word is
    /// measured at the level of its colour, so that what the page draws across it is not taken for its ink.
    private static func withInkWeights(_ words: [ExtractedWord], levels: [Int?], on page: PDFPage, bounds: CGRect) throws -> [ExtractedWord] {
        let heavy = try InkWeight.heavyWords(on: page, bounds: bounds, words: words, levels: levels)
        return zip(words, heavy).map { word, heavy in
            heavy && !word.isBold ? ExtractedWord(text: word.text, frame: word.frame, fontSize: word.fontSize, isBold: true) : word
        }
    }

    /// The grey levels of a page's text colours, read a run of one colour at a time.
    struct Colours {
        let attributed: NSAttributedString?
        private let converter = InkWeight.Levels()
        private var run = NSRange(location: 0, length: 0)
        private var runLevel: Int?

        init(attributed: NSAttributedString?) {
            self.attributed = attributed
        }

        /// The level of the colour the character at `index` is drawn in, as the page is drawn: nil when the text has no
        /// style or the character no colour.
        mutating func level(at index: Int) -> Int? {
            guard let attributed, index < attributed.length else { return nil }
            if !NSLocationInRange(index, run) {
                var range = NSRange(location: index, length: 1)
                let value = attributed.attribute(.foregroundColor, at: index, effectiveRange: &range)
                #if canImport(UIKit)
                let colour = (value as? UIColor)?.cgColor
                #else
                let colour = (value as? NSColor)?.cgColor
                #endif
                run = range
                runLevel = colour.flatMap(converter.level(of:))
            }
            return runLevel
        }
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
