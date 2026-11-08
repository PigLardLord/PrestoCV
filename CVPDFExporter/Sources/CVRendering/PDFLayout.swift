import Foundation

/// A rectangle in PDF points, origin at the lower left of the page, as PDF draws it.
public struct PDFBox: Sendable, Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// One line of text as the PDF draws it: the page it is on (0 first), its text, its box and the height of its
/// glyphs. `glyphHeight` is nil when the inspector cannot tell it, and such a line never passes the check.
public struct PDFTextLine: Sendable, Equatable {
    public var pageIndex: Int, text: String, box: PDFBox, glyphHeight: Double?
    public init(pageIndex: Int, text: String, box: PDFBox, glyphHeight: Double?) {
        self.pageIndex = pageIndex; self.text = text; self.box = box; self.glyphHeight = glyphHeight
    }
}

/// Where a PDF draws its text: the box of every page (its media box, in its own page space) and every text line.
public struct PDFLayout: Sendable, Equatable {
    public var pages: [PDFBox], lines: [PDFTextLine]
    public init(pages: [PDFBox], lines: [PDFTextLine]) { self.pages = pages; self.lines = lines }
}

/// An inspector that also reads where the text lies (PDFKit on Apple platforms). A protocol of its own, not a new
/// requirement on `PDFInspecting`, so the inspectors that only read text keep compiling.
public protocol PDFLayoutInspecting: PDFInspecting {
    /// The layout of `data`, or nil when it is not a PDF the inspector can lay out.
    func layout(of data: Data) -> PDFLayout?
}

/// What `GeometricCompleteness` finds wrong in a layout. A line is reported once, by its first fault in this order:
/// outside its page, glyph height unknown, glyph too small.
public enum GeometryViolation: Sendable, Equatable {
    case noPage, noText
    case outsidePage(page: Int, text: String)
    case unknownGlyphHeight(page: Int, text: String)
    case glyphTooSmall(page: Int, text: String)
}

/// Geometric completeness (R8, ADR 0011, #80): text that a PDF holds is also visible. Every text line lies inside
/// its page and its glyphs are at least `minimumGlyphHeight` high. A document with no page or no text never passes.
public enum GeometricCompleteness {
    /// 6 pt: the design grammar's smallest `font-size` is 7 pt, and the extra point absorbs the rounding in the
    /// PDF's own font metrics (markup-contract.md, "design CSS").
    public static let minimumGlyphHeight: Double = 6
    /// How far a line's box may reach past its page, in points: glyph boxes overhang their advance slightly.
    public static let pageTolerance: Double = 1

    public static func violations(in layout: PDFLayout, minimumGlyphHeight: Double) -> [GeometryViolation] {
        guard !layout.pages.isEmpty else { return [.noPage] }
        guard !layout.lines.isEmpty else { return [.noText] }
        let ordered = layout.lines.enumerated().sorted {
            $0.element.pageIndex != $1.element.pageIndex ? $0.element.pageIndex < $1.element.pageIndex : $0.offset < $1.offset
        }.map(\.element)
        return ordered.compactMap { line in
            guard layout.pages.indices.contains(line.pageIndex), lies(line.box, inside: layout.pages[line.pageIndex]) else {
                return .outsidePage(page: line.pageIndex, text: line.text)
            }
            guard let height = line.glyphHeight else { return .unknownGlyphHeight(page: line.pageIndex, text: line.text) }
            guard height >= minimumGlyphHeight else { return .glyphTooSmall(page: line.pageIndex, text: line.text) }
            return nil
        }
    }

    static func lies(_ box: PDFBox, inside page: PDFBox) -> Bool {
        box.x >= page.x - pageTolerance && box.y >= page.y - pageTolerance
            && box.maxX <= page.maxX + pageTolerance && box.maxY <= page.maxY + pageTolerance
    }
}
