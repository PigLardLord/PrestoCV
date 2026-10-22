import Foundation
import PDFKit
import CoreGraphics
import UIKit

/// Where the text of a PDF is, page by page, as PDFKit reads it back: enough to judge how a design paginates
struct PDFLayout {

    struct Line {
        let text: String
        /// In PDF space: the origin is the bottom left corner of the page
        let bounds: CGRect
    }

    struct Page {
        /// The lines of the page from the top down; lines side by side are ordered from left to right
        let lines: [Line]

        var text: String { lines.map(\.text).joined(separator: "\n") }
        var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var lowestTextEdge: CGFloat? { lines.map { $0.bounds.minY }.min() }
        var leftmostTextEdge: CGFloat? { lines.map { $0.bounds.minX }.min() }
        var rightmostTextEdge: CGFloat? { lines.map { $0.bounds.maxX }.max() }
        var highestTextEdge: CGFloat? { lines.map { $0.bounds.maxY }.max() }
    }

    let pages: [Page]
    /// The sizes of the fonts the text is set in, in points to a tenth, as PDFKit reads them back
    let fontSizes: Set<Double>
    let pageSize: CGSize
    let margins: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat)

    var pageCount: Int { pages.count }
    var blankPageNumbers: [Int] { pages.indices.filter { pages[$0].isBlank }.map { $0 + 1 } }
    var text: String { pages.map(\.text).joined(separator: "\n") }

    init?(pdf url: URL, margins: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat)) {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else { return nil }
        let first = document.page(at: 0)!.bounds(for: .mediaBox)
        self.pageSize = first.size
        self.margins = margins
        self.fontSizes = Self.fontSizes(of: document)
        self.pages = (0..<document.pageCount).map { index in
            let page = document.page(at: index)!
            let selection = page.selection(for: page.bounds(for: .mediaBox))
            let lines = (selection?.selectionsByLine() ?? []).compactMap { line -> Line? in
                guard let text = line.string, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return Line(text: text.trimmingCharacters(in: .whitespacesAndNewlines), bounds: line.bounds(for: page))
            }
            return Page(lines: lines.sorted { lhs, rhs in
                abs(lhs.bounds.maxY - rhs.bounds.maxY) < 2 ? lhs.bounds.minX < rhs.bounds.minX : lhs.bounds.maxY > rhs.bounds.maxY
            })
        }
    }

    private static func fontSizes(of document: PDFDocument) -> Set<Double> {
        var sizes = Set<Double>()
        for index in 0..<document.pageCount {
            guard let text = document.page(at: index)?.attributedString else { continue }
            text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, _, _ in
                if let font = value as? UIFont { sizes.insert((Double(font.pointSize) * 10).rounded() / 10) }
            }
        }
        return sizes
    }

    /// How much of the height between the margins the text of a page uses, from 0 to 1
    func fill(ofPage number: Int) -> Double {
        guard let lowest = pages[number - 1].lowestTextEdge else { return 0 }
        let printableHeight = pageSize.height - margins.top - margins.bottom
        return Double(((pageSize.height - margins.top) - lowest) / printableHeight)
    }

    /// Whether all the text of a page is inside the margins, give or take a point. `bottomMargin` stands for the margin at
    /// the foot of the page, when the page is allowed to go closer to it than the margins the layout was made with.
    func isInsideMargins(page number: Int, tolerance: CGFloat = 2, bottomMargin: CGFloat? = nil) -> Bool {
        let page = pages[number - 1]
        guard let left = page.leftmostTextEdge, let right = page.rightmostTextEdge,
              let low = page.lowestTextEdge, let high = page.highestTextEdge else { return true }
        return left >= margins.left - tolerance
            && right <= pageSize.width - margins.right + tolerance
            && low >= (bottomMargin ?? margins.bottom) - tolerance
            && high <= pageSize.height - margins.top + tolerance
    }

    var summary: String {
        let fills = pages.indices.map { String(format: "%.0f", fill(ofPage: $0 + 1) * 100) }.joined(separator: ",")
        return "pages=\(pageCount) fill%=[\(fills)] blank=\(blankPageNumbers)"
    }
}

// MARK: - Checks on where text falls

extension PDFLayout {

    /// The lines under `line` on its page that are in its column: they overlap it, or start where it starts
    private func linesBelow(_ line: Line, onPage page: Page, leftEdgeTolerance: CGFloat = 15) -> [Line] {
        page.lines.filter { other in
            other.bounds.maxY <= line.bounds.minY + 1
                && other.bounds.minY < line.bounds.minY
                && abs(other.bounds.minX - line.bounds.minX) < leftEdgeTolerance
        }
    }

    /// The titles in `titles` that have no text under them, within `distance` points, on their page: a title left
    /// alone at the foot of a page
    func titlesWithoutText(_ titles: Set<String>, distance: CGFloat = 60) -> [String] {
        var found: [String] = []
        for (index, page) in pages.enumerated() {
            for line in page.lines where titles.contains(line.text.lowercased()) {
                let hasTextUnder = page.lines.contains { other in
                    other.bounds.maxY <= line.bounds.minY + 1
                        && line.bounds.minY - other.bounds.maxY < distance
                        && other.bounds.maxX > line.bounds.minX
                        && other.bounds.minX < line.bounds.maxX
                        && !titles.contains(other.text.lowercased())
                }
                if !hasTextUnder {
                    found.append("page \(index + 1): \"\(line.text)\" has no text under it")
                }
            }
        }
        return found
    }

    /// The entries that start on a page with fewer than `minimum` lines of their own under the title, which is
    /// what is left of an entry whose first lines are alone at the foot of a page.
    /// An entry's lines are the ones under its title that start where the title starts, up to the next title.
    func entriesCutTooEarly(titlePattern: String, stopAt stopTitles: Set<String>, minimum: Int) -> [String] {
        var found: [String] = []
        for (index, page) in pages.enumerated() {
            for line in page.lines where isEntryTitle(line, titlePattern) {
                let own = linesBelow(line, onPage: page).prefix { other in
                    !isEntryTitle(other, titlePattern) && !stopTitles.contains(other.text.lowercased())
                }
                if own.count < minimum {
                    found.append("page \(index + 1): \"\(line.text)\" has \(own.count) lines under it")
                }
            }
        }
        return found
    }

    /// The pages that open with fewer than `minimum` lines of an entry that began on the page before: the last lines
    /// of an entry, alone at the top of a page. An entry continues on the next page when its title is the last
    /// title or heading of the column on its page.
    /// - Parameter column: where the lines of the entries start
    func continuationsCutTooLate(titlePattern: String, stopAt stopTitles: Set<String>, minimum: Int, column: ClosedRange<CGFloat>) -> [String] {
        func isBreak(_ line: Line) -> Bool { isEntryTitle(line, titlePattern) || stopTitles.contains(line.text.lowercased()) }

        var found: [String] = []
        for index in pages.indices.dropFirst() {
            let before = pages[index - 1].lines.filter { column.contains($0.bounds.minX) }
            guard let lastBreak = before.last(where: isBreak), isEntryTitle(lastBreak, titlePattern) else { continue }

            let leading = pages[index].lines.filter { column.contains($0.bounds.minX) }.prefix { !isBreak($0) }
            if !leading.isEmpty && leading.count < minimum {
                found.append("page \(index + 1) opens with \(leading.count) lines of \"\(lastBreak.text)\"")
            }
        }
        return found
    }

    /// The pairs of lines on a page that run into each other by more than `tolerance` points, side to side and top to
    /// bottom: text set so close that one line is drawn over the next
    func overlappingLines(tolerance: CGFloat = 3) -> [String] {
        var found: [String] = []
        for (index, page) in pages.enumerated() {
            for (position, line) in page.lines.enumerated() {
                for other in page.lines[(position + 1)...] {
                    let overlap = line.bounds.intersection(other.bounds)
                    if !overlap.isNull && overlap.width > tolerance && overlap.height > tolerance {
                        found.append("page \(index + 1): \"\(line.text)\" and \"\(other.text)\"")
                    }
                }
            }
        }
        return found
    }

    /// The lines that start or end with `separator`: a mark between two items, left at the edge of a line by a wrap
    func linesWithSeparatorAtAnEdge(_ separator: Character = "\u{2022}") -> [String] {
        var found: [String] = []
        for (index, page) in pages.enumerated() {
            for line in page.lines where line.text.first == separator || line.text.last == separator {
                found.append("page \(index + 1): \"\(line.text)\"")
            }
        }
        return found
    }

    /// The lines with a skill rating that does not hold whole ratings of five dots: a rating cut in two by a line break
    func brokenRatings() -> [String] {
        var found: [String] = []
        for (index, page) in pages.enumerated() {
            for line in page.lines {
                let dots = line.text.filter { $0 == "\u{25CF}" || $0 == "\u{25CB}" }.count
                if dots % 5 != 0 {
                    found.append("page \(index + 1): \"\(line.text)\" has \(dots) dots")
                }
            }
        }
        return found
    }

    /// The words of `address`, cut at the places where an address may break, that are not whole on any line:
    /// the address was cut in the middle of a word
    func addressWordsCut(_ address: String, minimumLength: Int = 4) -> [String] {
        let words = address.split(whereSeparator: { "/-?&=".contains($0) }).map(String.init).filter { $0.count >= minimumLength }
        let lines = pages.flatMap(\.lines).map(\.text)
        return words.filter { word in !lines.contains { $0.contains(word) } }
    }

    /// The markers that the text of the PDF does not contain, ignoring the white space a line break puts in them
    func missing(markers: [String]) -> [String] {
        let flat = text.filter { !$0.isWhitespace }
        return markers.filter { !flat.contains($0.filter { !$0.isWhitespace }) }
    }

    private func isEntryTitle(_ line: Line, _ pattern: String) -> Bool {
        line.text.range(of: pattern, options: .regularExpression) != nil
    }
}

