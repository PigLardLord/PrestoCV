/// Reads certifications: a name, the issuer when the line names one, the year a date of the line states, and the link and
/// the description the lines under it give (#283).
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
    struct Line {
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

    /// Reads each line of the section as a certification, or as the issuer, the link or the description of the one above it. A
    /// line of dates alone is the year of the certification it dates: the one below it when the section starts with such a
    /// line (the dates come first), the one above it otherwise (#461).
    static func read(_ section: Section, into findings: inout Findings) {
        var walk = Walk(datesFirst: startsWithDates(section, findings.document, findings.consumedBlocks))
        for block in section.blocks {
            guard !findings.consumedBlocks.contains(block.index) else {
                walk.above = nil
                continue
            }
            walk.above = read(block, in: section, walk: &walk, into: &findings)
        }
        guard let waiting = walk.waiting else { return }
        if let before = waiting.before, findings.cv.certifications[before].year == nil {
            findings.cv.certifications[before].year = waiting.year
        } else {
            findings.unplace(waiting.block, in: section)
        }
    }

    /// Where the walk over the blocks of a section stands: the certification just made, which the next block may complete,
    /// and, when the dates come first, the line of dates that waits for the certification below it.
    private struct Walk {
        let datesFirst: Bool
        var above: OpenCertification?
        var waiting: Waiting?
    }

    /// A line of dates that waits for the certification below it, and the certification above it, which takes the dates when
    /// nothing follows the line.
    private typealias Waiting = (block: SourceBlock, year: Sourced<Int>, before: Int?)

    private static func startsWithDates(_ section: Section, _ document: SourceDocument, _ consumed: Set<Int>) -> Bool {
        guard let first = section.blocks.first(where: { !consumed.contains($0.index) && $0.kind != .tableHeader }) else { return false }
        return datesAlone(Line(section.cells(of: first, in: document))) != nil
    }

    /// The year of a line that holds dates and nothing else.
    private static func datesAlone(_ line: Line) -> Sourced<Int>? {
        line.parts.isEmpty ? line.year : nil
    }

    /// Decides what a block is, by the first branch that holds. The result is the certification the lines under it may go
    /// on with, or nil when they go on with none. The link to the certification above is cut by a table header, by a block
    /// with no cell, by a line that is no certification, and, in the caller, by a block another reader consumed:
    /// 1. a table header is left out as markup;
    /// 2. a block with no cell has nothing to read;
    /// 3. a block with no web address whose first part starts with an issuer lead ("Issued by", "Rilasciato da", ...)
    ///    followed by at most six words, right under the line of a certification that has no issuer and does not state a
    ///    year the line also states, is that certification's issuer (and its year, when it has none); the rest of the line
    ///    is text not imported. The line must also have an unambiguous year: no date, or one single date (not a period)
    ///    that is a part of its own, between the separators, with no part beside the lead, so that "Issued by Red Cross,
    ///    2021, expires 2024", "..., 2021–2024" or "Issued by Red Cross expires 2024" is an entry of its own: a date of
    ///    other text never becomes the year of the certification above;
    ///    A certification whose line had a second part after a comma ("First Aid, Level 2") took that lone part as its
    ///    issuer, so it has one, and a lead line below it stays an entry of its own: the safe, visible split;
    /// 4. a line that is the link or the description of the certification above, by the rules of `CertificationLine`
    ///    (split rather than merge), goes on with it, and a description that only its words placed there marks that
    ///    certification to check; a line of web addresses with no certification above is text not imported;
    /// 5. a block with no part is text not imported;
    /// 6. anything else is a certification of its own: the first part is the name, the issuer is the part that reads as an
    ///    organisation, or the only part left, the first web address is the link, a label of a link is left out, and the
    ///    rest is text not imported. One that may as well be the description of the certification above is marked to check.
    ///
    /// Before these branches, a line of dates alone (and no web address: the address is read by the branches) is the year of a certification (#461): it waits for the certification
    /// below it, or dates the one above it when that one has no year; the certification it dates below it takes its year.
    private static func read(_ block: SourceBlock, in section: Section, walk: inout Walk, into findings: inout Findings)
        -> OpenCertification? {
        let open = walk.above
        if block.kind == .tableHeader {
            findings.leaveOut(block, .markup)
            return nil
        }
        let cells = section.cells(of: block, in: findings.document)
        guard !cells.isEmpty else { return nil }
        let line = CertificationLine(block: block, cells: cells)
        if line.addresses.isEmpty, let dates = datesAlone(line.split), dateLine(block, dates, &walk, section, &findings) { return nil }
        if var open, open.isRightAbove, line.addresses.isEmpty, completeCertification(at: open.index, with: line.split, section, &findings) {
            open.statesIssuerOrYear = true
            open.isRightAbove = false
            return open
        }
        switch line.role(after: open) {
        case .link(var open):
            addLink(line, to: open.index, section, &findings)
            open.isRightAbove = false
            return open
        case .description(var open, let check):
            addDescription(line, to: open.index, &findings)
            if let check { findings.cv.certifications[open.index].check = check }
            open.isRightAbove = false
            return open
        case .unplaced:
            for cell in cells { findings.unplace(cell, in: section) }
            return nil
        case .entry(let check):
            let entry = addEntry(line, check: check, waiting: walk.waiting, section, &findings)
            if entry != nil {
                if let waiting = walk.waiting, line.split.year != nil { findings.unplace(waiting.block, in: section) }
                walk.waiting = nil
            }
            return entry
        }
    }

    /// A line of dates alone: it waits for the certification below it (a line that waited already is text not imported) or
    /// is the year of the certification above it, when that one has no year yet. The neighbour is the one the splitter chose
    /// for the line (`Section.dateOwners`), else the direction of the section. False, and nothing changed, when it is neither.
    private static func dateLine(_ block: SourceBlock, _ year: Sourced<Int>, _ walk: inout Walk, _ section: Section, _ findings: inout Findings) -> Bool {
        let owner = section.dateOwners[block.index] ?? (walk.datesFirst ? .below : .above)
        if owner == .below {
            if let waiting = walk.waiting { findings.unplace(waiting.block, in: section) }
            walk.waiting = (block, year, walk.above?.index)
            return true
        }
        guard let above = walk.above?.index, findings.cv.certifications[above].year == nil else { return false }
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

    /// Branch 4: the line's first address is the link of the certification above, unless it has one; its labels are left
    /// out, and any other address stays visible as text not imported.
    private static func addLink(_ line: CertificationLine, to index: Int, _ section: Section, _ findings: inout Findings) {
        var addresses = line.addresses[...]
        if findings.cv.certifications[index].link == nil, let first = addresses.popFirst() {
            findings.cv.certifications[index].link = first.link.address
        }
        for label in line.labels { findings.leaveOut(label, .categoryLabel) }
        for address in addresses { findings.unplace(address.piece, in: section) }
    }

    /// Branch 4: the line goes on with the description of the certification above, on a line of its own.
    private static func addDescription(_ line: CertificationLine, to index: Int, _ findings: inout Findings) {
        let previous = findings.cv.certifications[index].description
        let texts = (previous.map { [$0.value] } ?? []) + line.cells.map(\.text)
        findings.cv.certifications[index].description = Sourced(value: texts.joined(separator: "\n"), spans: (previous?.spans ?? []) + line.cells.map(\.span))
    }

    /// Branches 5 and 6: a certification of its own, with the reason to check it if any, or text not imported when the line
    /// has no part. The certification is open for the lines under it.
    private static func addEntry(
        _ line: CertificationLine, check: CheckReason?, waiting: Waiting?, _ section: Section, _ findings: inout Findings
    )
        -> OpenCertification? {
        var split = line.split
        // On a line with an address, a part can be the label of the link: "Swift Basics – Verify: https://…"
        let labels = line.addresses.isEmpty ? [] : split.parts.filter { CertificationLinkLabel.isLabel($0.text) }
        split.parts.removeAll { labels.contains($0) }
        guard let name = split.parts.first else {
            findings.unplace(line.block, in: section)
            return nil
        }
        add(name, split, waiting: waiting, section, &findings)
        let index = findings.cv.certifications.count - 1
        findings.cv.certifications[index].link = line.addresses.first?.link.address
        findings.cv.certifications[index].check = check
        for label in line.labels + labels { findings.leaveOut(label, .categoryLabel) }
        for address in line.addresses.dropFirst() { findings.unplace(address.piece, in: section) }
        let certification = findings.cv.certifications[index]
        return OpenCertification(index: index, title: line.block, titleIsSentence: line.readsAsSentence,
                                 statesIssuerOrYear: certification.issuer != nil || certification.year != nil,
                                 startsWithTheName: line.block.cells.first?.lowerBound == name.span.lowerBound)
    }

    /// Branch 6: a certification of its own, its name, issuer and year.
    private static func add(
        _ name: Piece, _ line: Line, waiting: Waiting?, _ section: Section, _ findings: inout Findings
    ) {
        var certification = ImportedCertification(name: name.quote())
        certification.year = line.year ?? waiting?.year
        certification.heading = findings.heading(of: section)
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
