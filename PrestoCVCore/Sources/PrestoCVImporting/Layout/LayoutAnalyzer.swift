/// The page analysis of a PDF, in the core so that it is tested on Linux (ADR 0027): the words a reader saw become
/// lines and cells; headers and footers repeated on every page and page numbers are left out; a sidebar is told from
/// a table by what its left column holds; and the lines are put in reading order, the main column first.
///
/// A PDF's geometry is untrusted input (R8). Its words, lines and cells are bounded before the passes over them, every
/// pass is a sweep over sorted values, and each counts its steps in an `AnalysisWork`, which stops the analysis past
/// its budget or once its task is cancelled.
enum LayoutAnalyzer {

    struct Analysis {
        var lines: [RawLine]
        var leftOut: [LeftOutText]
    }

    /// - Throws: `LimitReached` over the limits of words, lines, cells or steps; `CancellationError`.
    static func analyze(_ pages: [ExtractedPage], limits: ImportLimits, work: inout AnalysisWork) throws -> Analysis {
        let wordCount = pages.reduce(0) { $0 + $1.words.count }
        guard wordCount <= limits.maximumWords else { throw LimitReached(.words) }
        try work.count(wordCount)
        var leftOut: [LeftOutText] = []
        var pageLines: [[PageLine]] = []
        var lineCount = 0
        var cellCount = 0
        try work.count(AnalysisWork.sortSteps(wordCount))
        let bodySize = median(pages.flatMap { $0.words.map(\.fontSize) }) ?? 10
        var pageGroups: [[[ExtractedWord]]] = []
        for page in pages {
            let groups = try lineWords(of: page, work: &work)
            lineCount += groups.count
            guard lineCount <= limits.maximumLines else { throw LimitReached(.lines) }
            pageGroups.append(groups)
        }
        let headings = try HeadingRails(lines: pageGroups, of: pages, bodySize: bodySize, work: &work)
        for (index, groups) in pageGroups.enumerated() {
            let found = lines(of: groups, headingEnds: headings.headingEnds[index], number: index + 1)
            cellCount += found.reduce(0) { $0 + $1.cells.count }
            guard cellCount <= limits.maximumCells else { throw LimitReached(.cells) }
            pageLines.append(found)
        }
        try work.count(2 * lineCount)
        removeRepeated(&pageLines, pages: pages, leftOut: &leftOut)

        let allCells = pageLines.flatMap { $0.flatMap(\.cells) }
        let split = try columns(of: allCells, width: pages.first?.width ?? 595, work: &work)

        try work.count(lineCount + cellCount)
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
        try work.count(3 * AnalysisWork.sortSteps(ordered.count))
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
            rawLine.cellLooks = line.cells.map(\.look)
            raw.append(rawLine)
            previous = entry
        }
        return Analysis(lines: raw, leftOut: leftOut)
    }

    // MARK: Lines and cells

    struct Cell {
        let words: [ExtractedWord]
        let frame: Rect

        /// - Parameter words: At least one word.
        init(words: [ExtractedWord]) {
            self.words = words
            frame = words.dropFirst().reduce(words[0].frame) { $0.union($1.frame) }
        }

        var text: String { words.map(\.text).joined(separator: " ") }
        var fontSize: Double { words.map(\.fontSize).max() ?? 0 }
        /// Where the cell's text starts and its smallest size: of its words that hold a letter or a number, so that an
        /// icon font's glyph or a bullet drawn before them changes neither.
        var look: SourceBlock.CellLook {
            let text = words.filter { $0.text.contains { $0.isLetter || $0.isNumber } }
            let measured = text.isEmpty ? words : text
            return SourceBlock.CellLook(x: measured[0].frame.x, fontSize: measured.map(\.fontSize).min() ?? 0)
        }
        var isBold: Bool { words.allSatisfy(\.isBold) }
    }

    struct PageLine {
        let page: Int
        let cells: [Cell]
        let frame: Rect

        /// - Parameter cells: At least one cell.
        init(page: Int, cells: [Cell]) {
            self.page = page
            self.cells = cells
            frame = cells.dropFirst().reduce(cells[0].frame) { $0.union($1.frame) }
        }

        var text: String { cells.map(\.text).joined(separator: "\t") }
        var fontSize: Double { cells.map(\.fontSize).max() ?? 0 }
        var isBold: Bool { cells.allSatisfy(\.isBold) }

        /// Where the text starts past a list marker: a wrapped line of the item starts there too.
        var textStart: Double? {
            cells.first.map { LayoutAnalyzer.textStart(of: $0.words[...]) }
        }
    }

    private static let bulletMarks: Set<String> = ["•", "-", "–", "▪", "◦", "●", "■", "►", "➢", "*", "·", "o", "\u{F0B7}"]

    /// The words of a page grouped into lines by their height on the page, each line's words from left to right. A word
    /// without a box on the page, one not finite or of a negative size, cannot be placed and is no text.
    private static func lineWords(of page: ExtractedPage, work: inout AnalysisWork) throws -> [[ExtractedWord]] {
        let words = page.words.filter { !$0.text.allSatisfy(\.isWhitespace) && isPlaceable($0.frame) }
            .sorted { ($0.frame.y, $0.frame.x) < ($1.frame.y, $1.frame.x) }
        try work.count(2 * AnalysisWork.sortSteps(page.words.count))
        var groups: [[ExtractedWord]] = []
        var frames: [Rect] = []
        // The lines a word may still join, oldest first. The words come from the top down: a line that ends above a
        // word ends above every word after it, and is closed.
        var open: [Int] = []
        for word in words {
            try work.count(2 * open.count + 1)
            open.removeAll { frames[$0].maxY < word.frame.y }
            if let index = open.last(where: { overlaps(frames[$0], word.frame) }) {
                groups[index].append(word)
                frames[index] = frames[index].union(word.frame)
            } else {
                groups.append([word])
                frames.append(word.frame)
                open.append(groups.count - 1)
            }
        }
        return groups.map { $0.sorted { $0.frame.x < $1.frame.x } }
    }

    /// The lines of a page, each split into cells at its wide gaps.
    ///
    /// A section's heading in a column of its own, right-aligned to the left of its section's first line, stands closer to
    /// that line than two cells of a table do. So a line's first cell also ends where `headingEnds` says a heading drawn
    /// in such a column ends: `HeadingRails` reads them (#287).
    ///
    /// - Parameter groups: The words of each line, from left to right, at least one word in each.
    private static func lines(of groups: [[ExtractedWord]], headingEnds: [Int?], number: Int) -> [PageLine] {
        groups.enumerated().map { index, sorted in
            var cells: [[ExtractedWord]] = [[sorted[0]]]
            for (offset, (previous, word)) in zip(sorted, sorted.dropFirst()).enumerated() {
                let gap = word.frame.x - previous.frame.maxX
                let size = max(previous.fontSize, word.fontSize)
                if gap > max(8, 1.5 * size) || headingEnds[index] == offset + 1 {
                    cells.append([word])
                } else {
                    cells[cells.count - 1].append(word)
                }
            }
            return PageLine(page: number, cells: cells.map(Cell.init))
        }.sorted { ($0.frame.y, $0.frame.x) < ($1.frame.y, $1.frame.x) }
    }

    /// Where the text of words, left to right, starts: past a list marker if they start with one.
    ///
    /// - Parameter words: At least one word.
    private static func textStart(of words: ArraySlice<ExtractedWord>) -> Double {
        let first = words.startIndex
        if bulletMarks.contains(words[first].text), words.count > 1 { return words[first + 1].frame.x }
        return words[first].frame.x
    }

    private static func isPlaceable(_ frame: Rect) -> Bool {
        [frame.x, frame.y, frame.width, frame.height].allSatisfy(\.isFinite) && frame.width >= 0 && frame.height >= 0
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
    ///
    /// Every cell's right edge is a candidate gutter. The cells' starts and ends are sorted once, and each candidate
    /// counts the cells on its left, on its right and across it with binary searches in them.
    private static func columns(of cells: [Cell], width: Double, work: inout AnalysisWork) throws -> ColumnSplit? {
        guard cells.count >= 6 else { return nil }
        try work.count(4 * AnalysisWork.sortSteps(cells.count))
        let ends = cells.map(\.frame.maxX).sorted()
        let starts = cells.map(\.frame.x).sorted()
        // A cell is wholly left of a gutter once the gutter is past its start and not before its end
        let wholly = cells.map { Passing(at: max($0.frame.x, $0.frame.maxX), strictly: $0.frame.x >= $0.frame.maxX) }.sorted()
        let candidates = Set(ends.map { ($0 * 2).rounded() / 2 }).filter { $0 > width * 0.12 && $0 < width * 0.8 }.sorted()
        var best: (gutter: Double, corridor: Double)?
        for edge in candidates {
            try work.count(3 * (Int.bitWidth - cells.count.leadingZeroBitCount))
            let gutter = edge + 0.5
            let leftCount = firstIndex(in: ends) { $0 > gutter }
            let startsBefore = firstIndex(in: starts) { $0 >= gutter }
            let rightCount = cells.count - startsBefore
            let crossing = startsBefore - firstIndex(in: wholly) { !$0.isPassed(by: gutter) }
            guard Double(crossing) <= Double(cells.count) * 0.03, leftCount * 7 >= cells.count, rightCount * 7 >= cells.count,
                  leftCount > 0, startsBefore < starts.count else { continue }
            let corridor = starts[startsBefore] - ends[leftCount - 1]
            if corridor >= 12, corridor > (best?.corridor ?? 0) { best = (ends[leftCount - 1] + corridor / 2, corridor) }
        }
        guard let gutter = best?.gutter else { return nil }
        try work.count(3 * cells.count)
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

    /// Where a gutter passes a cell wholly: at the point, or only past it.
    private struct Passing: Comparable {
        let at: Double
        let strictly: Bool

        func isPassed(by gutter: Double) -> Bool {
            strictly ? at < gutter : at <= gutter
        }

        static func < (a: Passing, b: Passing) -> Bool {
            (a.at, a.strictly ? 1 : 0) < (b.at, b.strictly ? 1 : 0)
        }
    }

    /// The first index of a sorted array where `isPast` holds, or its count: `isPast` must hold from some index on.
    static func firstIndex<Value>(in sorted: [Value], where isPast: (Value) -> Bool) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let middle = (low + high) / 2
            if isPast(sorted[middle]) { high = middle } else { low = middle + 1 }
        }
        return low
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
