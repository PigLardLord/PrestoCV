/// Which lines of a dated section belong to which date (ADR 0027). A CV puts each entry's date before the entry's other
/// lines (dates first) or after the entry's head (dates after), and no single cue tells the two apart: a section that
/// opens with a date may open with a range that sums it up, and a short line under a date may be its entry's own or the
/// head of the next one. So the section is read both ways and each reading is scored over all its entries. The better
/// reading gives every entry a head on its own side of the date, keeps every line that names a role, an employer, a
/// degree or a school in a head, and gives no entry two of them. When the two readings score the same and part the
/// lines differently, the usual layout decides and the entries they part differently are flagged.
struct EntryLayout: Equatable {
    /// The line where each date's entry starts, by date.
    var starts: [Int]
    /// The first date sums up the section: a range alone, with no line of its own, that holds every other range.
    var opensWithSummary = false
    /// The entries, by date, that the two readings part differently, where the evidence did not choose.
    var unsure: Set<Int> = []

    /// The layout of a section's lines, given its dates (`anchors`). `usuallyDatesFirst` is the layout to keep when
    /// both readings fit equally.
    static func reading(_ lines: [EntryReader.Line], anchors: [Int], kind: EntryReader.Kind, usuallyDatesFirst: Bool) -> EntryLayout {
        let evidence = Evidence(lines, anchors: anchors, kind: kind)
        var datesFirst = EntryLayout(starts: anchors)
        datesFirst.opensWithSummary = evidence.isSummary(0, entry: datesFirst.range(of: 0, lineCount: lines.count))
        let datesAfter = evidence.bestReadingWithDatesAfter()
        guard datesAfter != datesFirst else { return datesFirst }
        let first = evidence.score(of: datesFirst, side: .datesFirst)
        let after = evidence.score(of: datesAfter, side: .datesAfter)
        if first != after { return first > after ? datesFirst : datesAfter }
        var kept = usuallyDatesFirst || evidence.mostDatesHaveNoHead ? datesFirst : datesAfter
        let other = kept == datesFirst ? datesAfter : datesFirst
        kept.unsure = Set(anchors.indices.filter { kept.range(of: $0, lineCount: lines.count) != other.range(of: $0, lineCount: lines.count) })
        if kept.opensWithSummary { kept.unsure.remove(0) }
        return kept
    }

    /// The lines of the entry of date `position`.
    func range(of position: Int, lineCount: Int) -> Range<Int> {
        starts[position]..<(position + 1 < starts.count ? starts[position + 1] : lineCount)
    }
}

// MARK: - The evidence of a section

private extension EntryLayout {

    enum Side { case datesFirst, datesAfter }

    /// What each line of a section says about the layout: the parts its words mark, and where it stands among the
    /// dates. Sums over runs of lines are read from running totals.
    struct Evidence {
        let lines: [EntryReader.Line]
        let anchors: [Int]
        /// How many lines that are not a description stand directly above each date, after the previous date.
        let heads: [Int]
        /// Each date's line holds nothing but the date.
        let dateAlone: [Bool]
        /// Each date's line names both main parts of its entry.
        let complete: [Bool]
        /// The first line after each date that is a description or another date.
        let tailEnds: [Int]
        /// Running totals, from line 0: marked primary parts, marked secondary parts, lines that mark either, such
        /// lines that are not a description, and lines that are not a description or mark a part (lines no entry may
        /// leave out for free).
        let primary: [Int]
        let secondary: [Int]
        let marked: [Int]
        let markedHeads: [Int]
        let headsOrMarked: [Int]
        let periods: [ImportedPeriod]

        init(_ lines: [EntryReader.Line], anchors: [Int], kind: EntryReader.Kind) {
            self.lines = lines
            self.anchors = anchors
            var primary = [0], secondary = [0], marked = [0], markedHeads = [0], headsOrMarked = [0]
            var parts: [(primary: Int, secondary: Int, isEmpty: Bool)] = []
            for line in lines {
                let segments = EntryReader.segments(of: EntryReader.Draft(head: [line]), kind: kind)
                let lineParts = (primary: segments.filter { $0.isMarked && $0.part == .primary }.count,
                                 secondary: segments.filter { $0.isMarked && $0.part == .secondary }.count,
                                 isEmpty: segments.isEmpty)
                parts.append(lineParts)
                let marks = lineParts.primary + lineParts.secondary > 0 ? 1 : 0
                primary.append(primary[primary.count - 1] + lineParts.primary)
                secondary.append(secondary[secondary.count - 1] + lineParts.secondary)
                marked.append(marked[marked.count - 1] + marks)
                markedHeads.append(markedHeads[markedHeads.count - 1] + (line.isBody ? 0 : marks))
                headsOrMarked.append(headsOrMarked[headsOrMarked.count - 1] + (line.isBody ? marks : 1))
            }
            (self.primary, self.secondary, self.marked, self.markedHeads) = (primary, secondary, marked, markedHeads)
            self.headsOrMarked = headsOrMarked
            heads = anchors.enumerated().map { position, anchor in
                let floor = position == 0 ? 0 : anchors[position - 1] + 1
                var index = anchor - 1
                while index >= floor, !lines[index].isBody { index -= 1 }
                return anchor - 1 - index
            }
            dateAlone = anchors.map { parts[$0].isEmpty }
            complete = anchors.map { parts[$0].primary > 0 && parts[$0].secondary > 0 }
            tailEnds = anchors.map { anchor in
                (anchor + 1..<lines.count).first { lines[$0].isBody || lines[$0].period != nil } ?? lines.count
            }
            periods = anchors.compactMap { lines[$0].period?.value }
        }

        private func sum(_ totals: [Int], _ range: Range<Int>) -> Int {
            range.isEmpty ? 0 : totals[range.upperBound] - totals[range.lowerBound]
        }

        /// The old vote: most dates have no line of their own above them.
        var mostDatesHaveNoHead: Bool { heads.filter { $0 == 0 }.count * 2 > heads.count }

        // MARK: Scoring a reading

        /// A reading's score: the score of each of its entries, less the lines it leaves before its first entry,
        /// but for descriptions that name no part (an introduction to the section).
        func score(of layout: EntryLayout, side: Side) -> Int {
            anchors.indices.reduce(-leftBefore(layout.starts[0])) { total, position in
                total + quality(position, entry: layout.range(of: position, lineCount: lines.count), side: side)
            }
        }

        /// The cost of the lines before a reading's first entry, which no entry holds.
        func leftBefore(_ start: Int) -> Int { sum(headsOrMarked, 0..<start) }

        /// How well an entry fits its reading. A line that names a part counts for the entry when it stands on the
        /// reading's side of the date: under it when the dates come first, above it when they come after. Each of the
        /// two main parts the entry names on that side and on the date's line counts for it once, and against it for
        /// each time more; a part named only on the other side of the date (an employer under the date that follows
        /// its role) counts once. A line that names a part counts against the entry when it falls among the
        /// descriptions, where no head is. An entry also loses for a date alone with no line on its side, which leaves
        /// it without a head, and for having no line but its date's. The range that sums up a section is no entry,
        /// and costs nothing.
        func quality(_ position: Int, entry: Range<Int>, side: Side) -> Int {
            let anchor = anchors[position]
            let tailEnd = min(tailEnds[position], entry.upperBound)
            let above = entry.lowerBound..<anchor
            let tail = anchor + 1..<tailEnd
            if isSummary(position, entry: entry) { return 0 }
            var quality = side == .datesFirst ? sum(marked, tail) : sum(marked, above)
            quality -= sum(markedHeads, tailEnd..<entry.upperBound)
            let own = side == .datesFirst ? anchor..<tailEnd : entry.lowerBound..<anchor + 1
            let across = side == .datesFirst ? above : tail
            for totals in [primary, secondary] {
                let count = sum(totals, own)
                quality += count > 0 ? 1 - (count - 1) : min(1, sum(totals, across))
            }
            if dateAlone[position], (side == .datesFirst ? tail : above).isEmpty { quality -= 1 }
            if entry.count == 1 { quality -= 1 }
            return quality
        }

        /// The first date, alone and with no line of its own, whose range holds every other date's.
        func isSummary(_ position: Int, entry: Range<Int>) -> Bool {
            guard position == 0, anchors.count >= 2, dateAlone[0], entry == anchors[0]..<anchors[0] + 1,
                  let whole = periods.first, periods.count == anchors.count else { return false }
            return periods.dropFirst().allSatisfy { Self.holds(whole, $0) }
        }

        private static func holds(_ outer: ImportedPeriod, _ inner: ImportedPeriod) -> Bool {
            start(of: outer) <= start(of: inner) && end(of: outer) >= end(of: inner)
        }

        private static func start(of period: ImportedPeriod) -> Int { period.start.year * 12 + (period.start.month ?? 1) }

        private static func end(of period: ImportedPeriod) -> Int {
            switch period.end {
            case .date(let date): return date.year * 12 + (date.month ?? 12)
            case .current, .unstated: return Int.max
            case nil: return period.start.year * 12 + (period.start.month ?? 12)
            }
        }

        // MARK: The best reading with the dates after their heads

        /// The best of fits, the first of them on a tie. Every date has at least one choice, so `fits` is never empty.
        private static func first(of fits: [Fit]) -> Fit {
            fits.dropFirst().reduce(fits[0]) { $1 > $0 ? $1 : $0 }
        }

        /// How many lines each date's entry takes from above it, chosen over the whole section for the best score. A
        /// date alone takes at least one line when it has any above it. Of readings that score the same, the one
        /// nearest the section's own pattern wins: each date takes as many lines as the first entry's head has (the
        /// first head after a leading range alone), and a date whose line names both parts takes none.
        func bestReadingWithDatesAfter() -> EntryLayout {
            let pattern = heads[0] == 0 && dateAlone[0]
                ? anchors.indices.dropFirst().filter { dateAlone[$0] && heads[$0] > 0 }.map { heads[$0] }.min() ?? 0
                : heads[0]
            let choices = anchors.indices.map { dateAlone[$0] && heads[$0] > 0 ? Array(1...heads[$0]) : Array(0...heads[$0]) }
            let target = anchors.indices.map { complete[$0] ? 0 : min(heads[$0], pattern) }

            // best[position][choice]: the best fit of the entries before this date, given the lines this date takes
            var best: [[Fit]] = [choices[0].map { taken in
                Fit(score: -leftBefore(anchors[0] - taken), distance: abs(taken - target[0]), previous: nil)
            }]
            for position in anchors.indices.dropFirst() {
                best.append(choices[position].map { taken in
                    let start = anchors[position] - taken
                    let candidates = choices[position - 1].indices.map { index in
                        let previous = best[position - 1][index]
                        let entry = anchors[position - 1] - choices[position - 1][index]..<start
                        return Fit(score: previous.score + quality(position - 1, entry: entry, side: .datesAfter),
                                   distance: previous.distance + abs(taken - target[position]), previous: index)
                    }
                    return Self.first(of: candidates)
                })
            }
            let last = anchors.count - 1
            let ends = choices[last].indices.map { index in
                let fit = best[last][index]
                let entry = anchors[last] - choices[last][index]..<lines.count
                return (index, Fit(score: fit.score + quality(last, entry: entry, side: .datesAfter), distance: fit.distance, previous: fit.previous))
            }
            var index = ends.dropFirst().reduce(ends[0]) { $1.1 > $0.1 ? $1 : $0 }.0
            var taken = Array(repeating: 0, count: anchors.count)
            for position in anchors.indices.reversed() {
                taken[position] = choices[position][index]
                index = best[position][index].previous ?? 0
            }
            var layout = EntryLayout(starts: anchors.indices.map { anchors[$0] - taken[$0] })
            layout.opensWithSummary = isSummary(0, entry: layout.range(of: 0, lineCount: lines.count))
            return layout
        }
    }

    /// A partial reading's score and its distance from the section's pattern: a higher score is better, then a
    /// smaller distance.
    struct Fit: Comparable {
        let score: Int
        let distance: Int
        let previous: Int?

        static func < (lhs: Fit, rhs: Fit) -> Bool {
            lhs.score != rhs.score ? lhs.score < rhs.score : lhs.distance > rhs.distance
        }

        static func == (lhs: Fit, rhs: Fit) -> Bool { lhs.score == rhs.score && lhs.distance == rhs.distance }
    }
}
