/// Reads certifications: a name, the issuer when the line names one, and the year a date of the line states.
enum CertificationReader {

    /// The separators a line of a certification is cut at.
    static let lineSeparators = Separators.strong + [" - ", ", "]

    /// A line of a section: its parts, cut at the separators, and the year its last date states.
    private struct Line {
        var parts: [Piece] = []
        var year: Sourced<Int>?

        init(_ cells: [Piece]) {
            for cell in cells { read(cell) }
        }

        private mutating func read(_ cell: Piece) {
            let dates = DateReader.periods(in: cell.text)
            if let last = dates.last { year = Sourced(value: Line.year(of: last), spans: [cell.sub(last.range).span], reading: .year) }
            let brackets = Brackets(of: cell, ifDatesIn: dates)
            let cut = dates.map(\.range).filter { !brackets.holdWords(around: $0) }
            parts += cell.removing(cut).flatMap { CertificationReader.cut($0, dated: !dates.isEmpty) }
        }

        private static func year(of date: DateMatch) -> Int {
            if case .date(let end)? = date.period.end { return end.year }
            return date.period.start.year
        }
    }

    /// The parts of a piece between the separators. A piece with no date and three or more parts at its commas, none of them
    /// after the first an organisation or a school, is a name that holds a list, "Managing Anxiety, Stress, Sleep": it is
    /// cut at its other separators only (#304). A piece that starts with an issuer lead is never such a name: it is cut at
    /// every comma, so that the first part is the issuer and the rest is text not imported.
    private static func cut(_ piece: Piece, dated: Bool) -> [Piece] {
        let wholeAtCommas = piece.split(by: lineSeparators.filter { $0 != ", " })
        return wholeAtCommas.flatMap { part -> [Piece] in
            let commas = part.split(by: [", "])
            let name = commas.dropFirst().allSatisfy { !EntryVocabulary.isOrganisation($0.text) && !EntryVocabulary.isSchool($0.text) }
            let led = CertificationIssuerLead.startsWithLead(part)
            return commas.count >= 3 && !dated && name && !led ? [part] : commas
        }
    }

    /// Reads each line of the section as a certification, or as the issuer of the one above it.
    static func read(_ section: Section, into findings: inout Findings) {
        var above: Int?
        for block in section.blocks {
            guard !findings.consumedBlocks.contains(block.index) else {
                above = nil
                continue
            }
            above = read(block, in: section, after: above, into: &findings)
        }
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
    ///    A certification whose line had a second part after a comma ("First Aid, Level 2") took that lone part as its
    ///    issuer, so it has one, and a lead line below it stays an entry of its own: the safe, visible split;
    /// 4. a block with no part is text not imported;
    /// 5. anything else is a certification of its own: the first part is the name, the issuer is the part that reads as an
    ///    organisation, or the only part left, and the rest is text not imported.
    private static func read(_ block: SourceBlock, in section: Section, after above: Int?, into findings: inout Findings) -> Int? {
        if block.kind == .tableHeader {
            findings.leaveOut(block, .markup)
            return nil
        }
        let cells = section.cells(of: block, in: findings.document)
        guard !cells.isEmpty else { return nil }
        let line = Line(cells)
        if let above, completeCertification(at: above, with: line, section, &findings) { return nil }
        guard let name = line.parts.first else {
            findings.unplace(block, in: section)
            return nil
        }
        add(name, line, section, &findings)
        return findings.cv.certifications.count - 1
    }

    /// Branch 3: the line is the issuer of the certification above it. False, and nothing changed, when it is not.
    private static func completeCertification(at index: Int, with line: Line, _ section: Section, _ findings: inout Findings) -> Bool {
        var certification = findings.cv.certifications[index]
        guard certification.issuer == nil, certification.year == nil || line.year == nil,
              let first = line.parts.first, let issuer = CertificationIssuerLead.issuer(in: first) else { return false }
        certification.issuer = issuer.quote()
        certification.year = certification.year ?? line.year
        findings.cv.certifications[index] = certification
        for part in line.parts.dropFirst() { findings.unplace(part, in: section) }
        return true
    }

    /// Branch 5: a certification of its own.
    private static func add(_ name: Piece, _ line: Line, _ section: Section, _ findings: inout Findings) {
        var certification = ImportedCertification(name: name.quote())
        certification.year = line.year
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
