extension LayoutAnalyzer {

    /// The headings a document draws in a column of its own, right-aligned beside their sections (#287): for each line of
    /// each page, the index of the word where such a heading ends, if the line starts with one.
    ///
    /// The column is a structure, not one matching coordinate. A *row* of it is a line whose first words, at most seven,
    /// are a heading of the vocabulary drawn bold or large and end at a gap of more than two spaces. Each row keeps its
    /// page, its page's size, where its heading starts and ends, where the text after it starts, and its section. A row
    /// whose gap is narrower than a cell's is read as a heading when another row, on a page of the same size, of another
    /// section and starting more than `sameEdge` away from it, ends at the same edge and has its text start at the same
    /// edge: two independent rows of one column. A row whose gap is already a cell's vouches for the others too.
    ///
    /// So no single line vouches for a heading. A line that is no row (an indented accomplishment, on the same page or
    /// another), a row of the same section (the same bold title on two jobs), a row whose heading starts where the other's
    /// does (a table's labels at one margin) and a row on a page of another size are no evidence. And the evidence is the
    /// document's: a page whose only section beside the column is one line, a name's page or a continuation page, has its
    /// heading read from the rows of the other pages of its size.
    struct HeadingRails {
        /// The gap, in font sizes, past which a heading ends a line's first cell: more than two spaces.
        private static let minimumGap = 0.7
        /// A heading is at most this many words.
        private static let maximumWords = SectionVocabulary.maximumWords
        /// How far, in points, two edges may be from one another and be the same edge: the ink of their first letters.
        private static let sameEdge = 3.0

        /// For each page, for each line, where the heading that starts it ends.
        private(set) var headingEnds: [[Int?]]

        /// - Parameters:
        ///   - lines: The words of each line of each page, from left to right, at least one word in each line.
        ///   - pages: The pages the lines are on, in the same order.
        init(lines: [[[ExtractedWord]]], of pages: [ExtractedPage], bodySize: Double, work: inout AnalysisWork) throws {
            headingEnds = lines.map { [Int?](repeating: nil, count: $0.count) }
            // The rows of each page size, and how many of them are in doubt
            var layouts: [PageSize: Int] = [:]
            var groups: [(rows: [Row], candidates: Int)] = []
            for (page, words) in lines.enumerated() {
                // A size that is no number equals no other, so its page is a layout of its own
                let size = PageSize(width: pages[page].width, height: pages[page].height)
                let layout = layouts[size] ?? groups.count
                if layout == groups.count {
                    layouts[size] = layout
                    groups.append(([], 0))
                }
                for (index, sorted) in words.enumerated() {
                    try work.count(Self.maximumWords)
                    guard let row = Self.row(of: sorted, page: page, line: index, bodySize: bodySize) else { continue }
                    groups[layout].rows.append(row)
                    if row.isCandidate { groups[layout].candidates += 1 }
                }
            }
            for group in groups where group.candidates > 0 {
                for row in try Self.vouched(group.rows, work: &work) { headingEnds[row.page][row.line] = row.end }
            }
        }

        // MARK: Rows

        /// A line that starts with a heading followed by a gap.
        private struct Row {
            /// The page, and the line's index among the page's lines.
            let page: Int
            let line: Int
            /// The index of the first word after the heading.
            let end: Int
            let section: SectionKind
            /// Where the heading starts and ends, and where the text after it starts, in points.
            let headingStart: Double
            let headingEnd: Double
            let textStart: Double
            /// The gap after the heading is narrower than a cell's: only the column splits the line there.
            let isCandidate: Bool
        }

        /// The size of a page, in points.
        private struct PageSize: Hashable {
            let width: Double
            let height: Double
        }

        /// The row a line starts, if its first words are a heading followed by a gap of more than two spaces. The first
        /// gap of a cell ends the search: a heading drawn in a column starts the line.
        private static func row(of sorted: [ExtractedWord], page: Int, line: Int, bodySize: Double) -> Row? {
            for index in 1..<min(sorted.count, maximumWords + 1) {
                let gap = sorted[index].frame.x - sorted[index - 1].frame.maxX
                let size = max(sorted[index - 1].fontSize, sorted[index].fontSize)
                let isCell = gap > max(8, 1.5 * size)
                guard isCell || gap > minimumGap * size else { continue }
                if let section = section(of: sorted[..<index], bodySize: bodySize) {
                    return Row(
                        page: page, line: line, end: index, section: section, headingStart: sorted[0].frame.x,
                        headingEnd: sorted[index - 1].frame.maxX, textStart: sorted[index].frame.x, isCandidate: !isCell
                    )
                }
                if isCell { return nil }
            }
            return nil
        }

        /// The section of the words, if they are a heading of the vocabulary drawn bold or large.
        private static func section(of words: ArraySlice<ExtractedWord>, bodySize: Double) -> SectionKind? {
            guard words.allSatisfy({ $0.isBold || $0.fontSize >= bodySize * 1.15 }) else { return nil }
            return SectionVocabulary.kind(ofHeading: words.map(\.text).joined(separator: " "))?.kind
        }

        // MARK: Evidence

        /// The candidate rows of one page size that another row vouches for.
        ///
        /// A sweep over the rows sorted by where their heading ends keeps the rows whose heading ends within `sameEdge`
        /// of the candidate's in a tree, by where their text starts. Among the rows of the tree whose text starts within
        /// `sameEdge` of the candidate's, the tree gives the leftmost and the rightmost heading starts of the sections
        /// other than the candidate's: one more than `sameEdge` away from the candidate's start vouches for it.
        private static func vouched(_ rows: [Row], work: inout AnalysisWork) throws -> [Row] {
            // Two sorts; each row in and out of the tree once; for each candidate two searches and a range of the tree
            try work.count(8 * AnalysisWork.sortSteps(rows.count))
            let byEnd = rows.indices.sorted { rows[$0].headingEnd < rows[$1].headingEnd }
            let byText = rows.indices.sorted { (rows[$0].textStart, $0) < (rows[$1].textStart, $1) }
            var rank = [Int](repeating: 0, count: rows.count)
            for (position, index) in byText.enumerated() { rank[index] = position }
            let textStarts = byText.map { rows[$0].textStart }

            var tree = StartTree(count: rows.count)
            var vouched: [Row] = []
            var entering = 0
            var leaving = 0
            for index in byEnd where rows[index].isCandidate {
                let row = rows[index]
                // The candidate itself is in the window, so neither sweep passes it
                while entering < byEnd.count, rows[byEnd[entering]].headingEnd <= row.headingEnd + sameEdge {
                    let next = rows[byEnd[entering]]
                    tree.set(Starts(next), at: rank[byEnd[entering]])
                    entering += 1
                }
                while rows[byEnd[leaving]].headingEnd < row.headingEnd - sameEdge {
                    tree.set(Starts(), at: rank[byEnd[leaving]])
                    leaving += 1
                }
                let first = firstIndex(in: textStarts) { $0 >= row.textStart - sameEdge }
                let last = firstIndex(in: textStarts) { $0 > row.textStart + sameEdge }
                let starts = tree.starts(from: first, to: last)
                if starts.leftmost.least(apartFrom: row.section) < row.headingStart - sameEdge
                    || -starts.rightmost.least(apartFrom: row.section) > row.headingStart + sameEdge {
                    vouched.append(row)
                }
            }
            return vouched
        }

        /// The least of some values with the section of each, kept as the least value with its section and the least
        /// value of the other sections: enough to tell the least value of the sections other than any one.
        private struct Least {
            private var first: (value: Double, section: SectionKind)?
            private var others = Double.infinity

            init() {}

            init(_ value: Double, of section: SectionKind) {
                first = (value, section)
            }

            /// The least value of the sections other than `section`, or infinity.
            func least(apartFrom section: SectionKind) -> Double {
                guard let first else { return .infinity }
                return first.section == section ? others : first.value
            }

            func merged(with other: Least) -> Least {
                guard let mine = first else { return other }
                guard let theirs = other.first else { return self }
                var merged = mine.value <= theirs.value ? self : other
                let loser = mine.value <= theirs.value ? other : self
                let section = mine.value <= theirs.value ? mine.section : theirs.section
                merged.others = min(merged.others, loser.least(apartFrom: section))
                return merged
            }
        }

        /// The leftmost and the rightmost heading starts of some rows, the rightmost kept as the least negated start.
        private struct Starts {
            var leftmost = Least()
            var rightmost = Least()

            init() {}

            init(_ row: Row) {
                leftmost = Least(row.headingStart, of: row.section)
                rightmost = Least(-row.headingStart, of: row.section)
            }

            func merged(with other: Starts) -> Starts {
                var merged = Starts()
                merged.leftmost = leftmost.merged(with: other.leftmost)
                merged.rightmost = rightmost.merged(with: other.rightmost)
                return merged
            }
        }

        /// The heading starts of the rows in the sweep's window, by the rank of where their text starts: a segment tree
        /// that sets one rank and merges a range of ranks in steps of the order of their count's bit length.
        private struct StartTree {
            private let leaves: Int
            private var nodes: [Starts]

            init(count: Int) {
                var leaves = 1
                while leaves < count { leaves *= 2 }
                self.leaves = leaves
                nodes = Array(repeating: Starts(), count: 2 * leaves)
            }

            mutating func set(_ starts: Starts, at rank: Int) {
                var node = rank + leaves
                nodes[node] = starts
                while node > 1 {
                    node /= 2
                    nodes[node] = nodes[2 * node].merged(with: nodes[2 * node + 1])
                }
            }

            /// The starts of the ranks from `first` up to `last`, excluded.
            func starts(from first: Int, to last: Int) -> Starts {
                var result = Starts()
                var low = first + leaves
                var high = last + leaves
                while low < high {
                    if low % 2 == 1 {
                        result = result.merged(with: nodes[low])
                        low += 1
                    }
                    if high % 2 == 1 {
                        high -= 1
                        result = result.merged(with: nodes[high])
                    }
                    low /= 2
                    high /= 2
                }
                return result
            }
        }
    }
}
