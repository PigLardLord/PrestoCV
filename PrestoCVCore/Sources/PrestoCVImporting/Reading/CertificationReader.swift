/// Reads certifications: a name, the issuer when the line names one, and the year a date of the line states.
enum CertificationReader {

    /// The separators a line of a certification is cut at.
    static let lineSeparators = Separators.strong + [" - ", ", "]

    /// The name this reader finds on a line, and how many parts it cuts the line into (#453): a section that joins the
    /// studies and the certifications sorts each line by the name this reader would give it.
    static func nameAndParts(of cells: [Piece]) -> (name: Piece?, parts: Int) {
        let line = Line(cells)
        return (line.parts.first, line.parts.count)
    }

    /// A line of a section: its parts, cut at the separators, and the year its last date states.
    private struct Line {
        var parts: [Piece] = []
        var year: Sourced<Int>?
        /// How many dates the line holds, whether one of them is a period with an end, and whether one of them shares its
        /// part (between the separators) with other text.
        private var dateCount = 0
        private var hasPeriod = false
        private var hasDateAmongWords = false

        /// Whether the year of the line is one issuance year: the line has no date, or one single date that is a part of
        /// its own and no part beside the lead. "Issued by Red Cross, 2021, expires 2024", "Issued by Red Cross, Rome, 2021"
        /// and "Issued by Red Cross expires 2024" are not: a date among words may belong to those words, whatever they are.
        var hasUnambiguousYear: Bool {
            dateCount == 0 || (dateCount == 1 && !hasPeriod && !hasDateAmongWords && parts.count <= 1)
        }

        init(_ cells: [Piece]) {
            for cell in cells { read(cell) }
        }

        private mutating func read(_ cell: Piece) {
            let dates = DateReader.periods(in: cell.text)
            dateCount += dates.count
            hasPeriod = hasPeriod || dates.contains { $0.period.end != nil }
            if !dates.isEmpty {
                let wholeParts = Set(cell.split(by: CertificationReader.lineSeparators).map(\.span))
                hasDateAmongWords = hasDateAmongWords || dates.contains { !wholeParts.contains(cell.sub($0.range).span) }
            }
            if let last = dates.last { year = Sourced(value: Line.year(of: last), spans: [cell.sub(last.range).span], reading: .year) }
            let brackets = Brackets(of: cell, ifDatesIn: dates)
            let cut = dates.map(\.range).filter { !brackets.holdWords(around: $0) }
            for piece in cell.removing(cut) {
                parts += CertificationReader.cut(piece, dated: !dates.isEmpty, holdsTheName: parts.isEmpty)
            }
        }

        private static func year(of date: DateMatch) -> Int {
            if case .date(let end)? = date.period.end { return end.year }
            return date.period.start.year
        }
    }

    /// The parts of a piece between the separators. Only the line's first part, its name, can hold a list (#304): when the
    /// piece is the line's first, has no date, and its first part has three or more parts at its commas, none of them after
    /// the first an organisation or a school, that part is a name that holds a list, "Managing Anxiety, Stress, Sleep", and is
    /// cut at the other separators only. A first part that starts with an issuer lead is never such a name. Every later part,
    /// of this piece or of a later cell, is cut at every comma as well, so that an issuer is read alone and the rest of its part
    /// is text not imported.
    private static func cut(_ piece: Piece, dated: Bool, holdsTheName: Bool) -> [Piece] {
        let wholeAtCommas = piece.split(by: lineSeparators.filter { $0 != ", " })
        return wholeAtCommas.enumerated().flatMap { offset, part -> [Piece] in
            let commas = part.split(by: [", "])
            guard holdsTheName, offset == 0, !dated, commas.count >= 3 else { return commas }
            let name = commas.dropFirst().allSatisfy { !EntryVocabulary.isOrganisation($0.text) && !EntryVocabulary.isSchool($0.text) }
            let led = CertificationIssuerLead.startsWithLead(part)
            return name && !led ? [part] : commas
        }
    }

    /// Reads each line of the section as a certification, or as the issuer of the one above it. A line of dates alone is
    /// the year of the certification it dates: the one below it when the section starts with such a line (the dates come
    /// first), the one above it otherwise (#461).
    static func read(_ section: Section, into findings: inout Findings) {
        var walk = Walk(datesFirst: startsWithDates(section, findings.document, findings.consumedBlocks))
        for block in section.blocks {
            guard !findings.consumedBlocks.contains(block.index) else {
                walk.above = nil
                continue
            }
            walk.above = read(block, in: section, walk: &walk, into: &findings)
        }
        if let waiting = walk.waiting { findings.unplace(waiting.block, in: section) }
    }

    /// Where the walk over the blocks of a section stands: the certification just made, which the next block may complete,
    /// and, when the dates come first, the line of dates that waits for the certification below it.
    private struct Walk {
        let datesFirst: Bool
        var above: Int?
        var waiting: (block: SourceBlock, year: Sourced<Int>)?
    }

    private static func startsWithDates(_ section: Section, _ document: SourceDocument, _ consumed: Set<Int>) -> Bool {
        guard let first = section.blocks.first(where: { !consumed.contains($0.index) && $0.kind != .tableHeader }) else { return false }
        return datesAlone(Line(section.cells(of: first, in: document))) != nil
    }

    /// The year of a line that holds dates and nothing else.
    private static func datesAlone(_ line: Line) -> Sourced<Int>? {
        line.parts.isEmpty ? line.year : nil
    }

    /// Decides what a block is, by the first branch that holds. The result is the index of the certification it made, which
    /// the next block may complete, or nil when the next block cannot complete anything. The link to the block above is also
    /// cut by a table header, by a block with no cell, by a line that completed the one above, and, in the caller, by a block
    /// another reader consumed:
    /// 1. a table header is left out as markup;
    /// 2. a block with no cell has nothing to read;
    /// 3. a block whose first part starts with an issuer lead ("Issued by", "Rilasciato da", ...) followed by at most six
    ///    words, while the block above made a certification that has no issuer and does not state a year the line also
    ///    states, is that certification's issuer (and its year, when it has none); the rest of the line is text not imported.
    ///    The line must also have an unambiguous year: no date, or one single date (not a period) that is a part of its
    ///    own, between the separators, with no part beside the lead, so that "Issued by Red Cross, 2021, expires 2024",
    ///    "..., 2021–2024" or "Issued by Red Cross expires 2024" is an entry of its own: a date of other text never
    ///    becomes the year of the certification above;
    ///    A certification whose line had a second part after a comma ("First Aid, Level 2") took that lone part as its
    ///    issuer, so it has one, and a lead line below it stays an entry of its own: the safe, visible split;
    /// 4. a block with no part is text not imported;
    /// 5. anything else is a certification of its own: the first part is the name, the issuer is the part that reads as an
    ///    organisation, or the only part left, and the rest is text not imported.
    private static func read(_ block: SourceBlock, in section: Section, walk: inout Walk, into findings: inout Findings) -> Int? {
        let above = walk.above
        if block.kind == .tableHeader {
            findings.leaveOut(block, .markup)
            return nil
        }
        let cells = section.cells(of: block, in: findings.document)
        guard !cells.isEmpty else { return nil }
        let line = Line(cells)
        if let dates = datesAlone(line), dateLine(block, dates, &walk, section, &findings) { return nil }
        if let above, completeCertification(at: above, with: line, section, &findings) { return nil }
        guard let name = line.parts.first else {
            findings.unplace(block, in: section)
            return nil
        }
        add(name, line, waiting: walk.waiting, section, &findings)
        if let waiting = walk.waiting, line.year != nil { findings.unplace(waiting.block, in: section) }
        walk.waiting = nil
        return findings.cv.certifications.count - 1
    }

    /// A line of dates alone: when the dates come first it waits for the certification below (a line that waited already
    /// is text not imported), otherwise it is the year of the certification above, when that one has no year yet. False,
    /// and nothing changed, when it is neither.
    private static func dateLine(_ block: SourceBlock, _ year: Sourced<Int>, _ walk: inout Walk, _ section: Section, _ findings: inout Findings) -> Bool {
        if walk.datesFirst {
            if let waiting = walk.waiting { findings.unplace(waiting.block, in: section) }
            walk.waiting = (block, year)
            return true
        }
        guard let above = walk.above, findings.cv.certifications[above].year == nil else { return false }
        findings.cv.certifications[above].year = year
        return true
    }

    /// Branch 3: the line is the issuer of the certification above it. False, and nothing changed, when it is not.
    private static func completeCertification(at index: Int, with line: Line, _ section: Section, _ findings: inout Findings) -> Bool {
        var certification = findings.cv.certifications[index]
        guard line.hasUnambiguousYear, certification.issuer == nil, certification.year == nil || line.year == nil,
              let first = line.parts.first, let issuer = CertificationIssuerLead.issuer(in: first) else { return false }
        certification.issuer = issuer.quote()
        certification.year = certification.year ?? line.year
        findings.cv.certifications[index] = certification
        for part in line.parts.dropFirst() { findings.unplace(part, in: section) }
        return true
    }

    /// Branch 5: a certification of its own.
    private static func add(
        _ name: Piece, _ line: Line, waiting: (block: SourceBlock, year: Sourced<Int>)?, _ section: Section, _ findings: inout Findings
    ) {
        var certification = ImportedCertification(name: name.quote())
        certification.year = line.year ?? waiting?.year
        let rest = line.parts.dropFirst()
        let issuer = rest.first { EntryVocabulary.isOrganisation($0.text) || EntryVocabulary.isSchool($0.text) } ?? (rest.count == 1 ? rest.first : nil)
        certification.issuer = issuer?.quote()
        findings.cv.certifications.append(certification)
        for part in rest where part != issuer { findings.unplace(part, in: section) }
    }

    /// The brackets of a cell, each with the places of its first and its last letter, read in one pass over the cell: a cell
    /// holds many dates, and none of them reads the cell's brackets or its letters again (R8).
    private struct Brackets {
        private struct Bracket {
            let range: Range<String.Index>
            let firstLetter: String.Index?
            let lastLetter: String.Index?
        }

        private let brackets: [Bracket]

        /// The brackets of the cell, when it has dates to be told from them.
        init(of cell: Piece, ifDatesIn dates: [DateMatch]) {
            guard !dates.isEmpty else {
                brackets = []
                return
            }
            brackets = cell.bracketedRanges().map { range in
                let inside = cell.text[range]
                return Bracket(range: range, firstLetter: inside.firstIndex(where: \.isLetter), lastLetter: inside.lastIndex(where: \.isLetter))
            }
        }

        /// Whether the date is inside a bracket that holds other words, "Course (Pro, 2024)": it is a part of those words, so
        /// it is read as the year, and it stays in the text, so that the bracket stays whole.
        func holdWords(around date: Range<String.Index>) -> Bool {
            var low = 0
            var high = brackets.count
            while low < high {
                let middle = (low + high) / 2
                if brackets[middle].range.upperBound <= date.lowerBound { low = middle + 1 } else { high = middle }
            }
            guard low < brackets.count, brackets[low].range.lowerBound <= date.lowerBound else { return false }
            let bracket = brackets[low]
            if let first = bracket.firstLetter, first < date.lowerBound { return true }
            if let last = bracket.lastLetter, last >= date.upperBound { return true }
            return false
        }
    }
}
