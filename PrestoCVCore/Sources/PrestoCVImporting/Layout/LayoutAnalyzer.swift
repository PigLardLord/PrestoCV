/// The page analysis of a PDF, in the core so that it is tested on Linux (ADR 0027): the words a reader saw become
/// lines and cells; headers and footers repeated on every page and page numbers are left out; a sidebar is told from
/// a table by what its left column holds; and the lines are put in reading order, the main column first.
enum LayoutAnalyzer {

    struct Analysis {
        var lines: [RawLine]
        var leftOut: [LeftOutText]
    }

    static func analyze(_ pages: [ExtractedPage]) -> Analysis {
        var leftOut: [LeftOutText] = []
        var pageLines: [[PageLine]] = pages.enumerated().map { index, page in lines(of: page, number: index + 1) }
        removeRepeated(&pageLines, pages: pages, leftOut: &leftOut)

        let allCells = pageLines.flatMap { $0.flatMap(\.cells) }
        let bodySize = median(pages.flatMap { $0.words.map(\.fontSize) }) ?? 10
        let split = columns(of: allCells, width: pages.first?.width ?? 595)

        var ordered: [(column: Int, page: Int, line: PageLine)] = []
        for (pageIndex, lines) in pageLines.enumerated() {
            for line in lines {
                guard let split else {
                    ordered.append((0, pageIndex, line))
                    continue
                }
                // A row of a table stays a row; a line across a sidebar's gutter splits into one line per column
                // A cell belongs to the column it starts in: a long address may run past the gutter
                let left = line.cells.filter { $0.frame.x < split.gutter }
                let right = line.cells.filter { $0.frame.x >= split.gutter }
                if split.isTable {
                    ordered.append((0, pageIndex, line))
                } else {
                    for (cells, side) in [(left, Side.left), (right, Side.right)] where !cells.isEmpty {
                        ordered.append((split.main == side ? 0 : 1, pageIndex, PageLine(page: line.page, cells: cells)))
                    }
                }
            }
        }
        ordered.sort { ($0.column, $0.page, $0.line.frame.y, $0.line.frame.x) < ($1.column, $1.page, $1.line.frame.y, $1.line.frame.x) }

        // The right edge of each column, over all the pages: a line that reaches it may have been wrapped there
        var rightEdges: [Int: Double] = [:]
        for entry in ordered {
            rightEdges[entry.column] = max(rightEdges[entry.column] ?? 0, entry.line.frame.maxX)
        }
        var raw: [RawLine] = []
        var previous: (column: Int, page: Int, line: PageLine)?
        for entry in ordered {
            let line = entry.line
            var followsGap = false
            if let previous, previous.column == entry.column, previous.page == entry.page {
                followsGap = line.frame.y - previous.line.frame.maxY > max(4, 0.7 * line.fontSize)
            } else if previous != nil {
                followsGap = true
            }
            var rawLine = RawLine(
                text: line.cells.map(\.text).joined(separator: "\t"), page: line.page, frame: line.frame,
                column: split == nil ? nil : entry.column,
                isEmphasized: line.isBold || line.fontSize >= bodySize * 1.15, followsGap: followsGap,
                textStart: line.textStart, fontSize: line.fontSize
            )
            rawLine.lastCellX = line.cells.last?.frame.x
            rawLine.lastCellBold = line.cells.last?.isBold ?? false
            rawLine.firstCellBold = line.cells.first?.isBold ?? false
            rawLine.firstWordWidth = line.cells.first?.words.first?.frame.width
            rawLine.columnRight = rightEdges[entry.column]
            raw.append(rawLine)
            previous = entry
        }
        return Analysis(lines: raw, leftOut: leftOut)
    }

    // MARK: Lines and cells

    struct Cell {
        let words: [ExtractedWord]
        var frame: Rect { words.dropFirst().reduce(words[0].frame) { $0.union($1.frame) } }
        var text: String { words.map(\.text).joined(separator: " ") }
        var fontSize: Double { words.map(\.fontSize).max() ?? 0 }
        var isBold: Bool { words.allSatisfy(\.isBold) }
    }

    struct PageLine {
        let page: Int
        let cells: [Cell]
        var frame: Rect { cells.dropFirst().reduce(cells[0].frame) { $0.union($1.frame) } }
        var text: String { cells.map(\.text).joined(separator: "\t") }
        var fontSize: Double { cells.map(\.fontSize).max() ?? 0 }
        var isBold: Bool { cells.allSatisfy(\.isBold) }

        /// Where the text starts past a list marker: a wrapped line of the item starts there too.
        var textStart: Double? {
            guard let first = cells.first?.words.first else { return nil }
            if bulletMarks.contains(first.text), let second = cells.first?.words.dropFirst().first { return second.frame.x }
            return first.frame.x
        }
    }

    private static let bulletMarks: Set<String> = ["•", "-", "–", "▪", "◦", "●", "■", "►", "➢", "*", "·", "o", "\u{F0B7}"]

    /// The words of a page grouped into lines by their height on the page, and each line into cells at its wide gaps.
    static func lines(of page: ExtractedPage, number: Int) -> [PageLine] {
        let words = page.words.filter { !$0.text.allSatisfy(\.isWhitespace) }.sorted { ($0.frame.y, $0.frame.x) < ($1.frame.y, $1.frame.x) }
        var groups: [[ExtractedWord]] = []
        var frames: [Rect] = []
        for word in words {
            if let index = frames.indices.last(where: { overlaps(frames[$0], word.frame) }) {
                groups[index].append(word)
                frames[index] = frames[index].union(word.frame)
            } else {
                groups.append([word])
                frames.append(word.frame)
            }
        }
        return groups.map { group in
            let sorted = group.sorted { $0.frame.x < $1.frame.x }
            var cells: [[ExtractedWord]] = [[sorted[0]]]
            for (previous, word) in zip(sorted, sorted.dropFirst()) {
                let gap = word.frame.x - previous.frame.maxX
                if gap > max(8, 1.5 * max(previous.fontSize, word.fontSize)) {
                    cells.append([word])
                } else {
                    cells[cells.count - 1].append(word)
                }
            }
            return PageLine(page: number, cells: cells.map(Cell.init))
        }.sorted { ($0.frame.y, $0.frame.x) < ($1.frame.y, $1.frame.x) }
    }

    /// Two boxes on the same line: they share at least half the height of the smaller.
    private static func overlaps(_ a: Rect, _ b: Rect) -> Bool {
        let shared = min(a.maxY, b.maxY) - max(a.y, b.y)
        return shared >= 0.5 * min(a.height, b.height)
    }

    // MARK: Headers, footers and page numbers

    /// Lines at the top or the bottom of the pages that repeat on two pages or more, digits aside, and page numbers.
    private static func removeRepeated(_ pageLines: inout [[PageLine]], pages: [ExtractedPage], leftOut: inout [LeftOutText]) {
        func isMargin(_ line: PageLine, of page: ExtractedPage) -> Bool {
            line.frame.y < page.height * 0.08 || line.frame.maxY > page.height * 0.92
        }
        func key(_ line: PageLine) -> String {
            String(line.text.folded.map { $0.isNumber ? "#" : $0 })
        }
        var pagesOfKey: [String: Set<Int>] = [:]
        for (index, lines) in pageLines.enumerated() {
            for line in lines where isMargin(line, of: pages[index]) { pagesOfKey[key(line), default: []].insert(index) }
        }
        for index in pageLines.indices {
            pageLines[index] = pageLines[index].filter { line in
                guard isMargin(line, of: pages[index]) else { return true }
                if NoiseReader.isPageNumber(line.text) {
                    leftOut.append(LeftOutText(text: line.text, span: nil, reason: .pageNumber))
                    return false
                }
                if pages.count > 1, (pagesOfKey[key(line)]?.count ?? 0) >= 2 {
                    leftOut.append(LeftOutText(text: line.text, span: nil, reason: .repeatedOnPages))
                    return false
                }
                return true
            }
        }
    }

    // MARK: Columns

    enum Side { case left, right }

    struct ColumnSplit {
        let gutter: Double
        /// The left column holds mostly dates: the page is a table, read row by row.
        let isTable: Bool
        let main: Side
    }

    /// An empty corridor that runs down the pages with text on both sides: a sidebar, or the date column of a table.
    private static func columns(of cells: [Cell], width: Double) -> ColumnSplit? {
        guard cells.count >= 6 else { return nil }
        var best: (gutter: Double, corridor: Double)?
        let candidates = Set(cells.map { ($0.frame.maxX * 2).rounded() / 2 }).filter { $0 > width * 0.12 && $0 < width * 0.8 }
        for edge in candidates {
            let gutter = edge + 0.5
            let crossing = cells.filter { $0.frame.x < gutter && $0.frame.maxX > gutter }.count
            let left = cells.filter { $0.frame.maxX <= gutter }
            let right = cells.filter { $0.frame.x >= gutter }
            guard Double(crossing) <= Double(cells.count) * 0.03, left.count * 7 >= cells.count, right.count * 7 >= cells.count,
                  let leftEdge = left.map(\.frame.maxX).max(), let rightEdge = right.map(\.frame.x).min() else { continue }
            let corridor = rightEdge - leftEdge
            if corridor >= 12, corridor > (best?.corridor ?? 0) { best = (leftEdge + corridor / 2, corridor) }
        }
        guard let gutter = best?.gutter else { return nil }
        let left = cells.filter { $0.frame.maxX <= gutter }
        let right = cells.filter { $0.frame.x >= gutter }
        // A table's left column holds dates and labels; a sidebar's holds a flow of its own. Headings count for neither.
        let content = left.filter { SectionVocabulary.kind(ofHeading: $0.text) == nil }
        let labels = content.filter { isLabelOrDate($0.text) }.count
        if !content.isEmpty, Double(labels) >= Double(content.count) * 0.5 {
            return ColumnSplit(gutter: gutter, isTable: true, main: .left)
        }
        let largestLeft = left.map(\.fontSize).max() ?? 0
        let largestRight = right.map(\.fontSize).max() ?? 0
        let main: Side
        if largestLeft != largestRight {
            main = largestLeft > largestRight ? .left : .right
        } else {
            main = gutter > width / 2 ? .left : .right
        }
        return ColumnSplit(gutter: gutter, isTable: false, main: main)
    }

    /// A date, or the label of a row: a personal detail, a Europass row, a language, a document's title, a bullet row.
    private static func isLabelOrDate(_ text: String) -> Bool {
        if !DateReader.periods(in: text).isEmpty || text.hasSuffix(":") || text.hasPrefix("•") { return true }
        if EntryVocabulary.personalLabel(text) != nil || EntryVocabulary.entryLabel(text) != nil || EntryVocabulary.isDocumentTitle(text) {
            return true
        }
        let piece = Piece(text: text, span: SourceSpan(0, text.unicodeScalars.count))
        return SectionVocabulary.isLanguageLabel(text) || (LanguageReader.languageName(in: piece) != nil && text.words.count <= 2)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
