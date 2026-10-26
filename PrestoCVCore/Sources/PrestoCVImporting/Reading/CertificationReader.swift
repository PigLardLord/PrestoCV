/// Reads certifications: a name, the issuer when the line names one, and the year a date of the line states.
enum CertificationReader {

    static func read(_ section: Section, into findings: inout Findings) {
        for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                continue
            }
            let cells = section.cells(of: block, in: findings.document)
            guard !cells.isEmpty else { continue }
            var year: Sourced<Int>?
            var parts: [Piece] = []
            for cell in cells {
                let dates = DateReader.periods(in: cell.text)
                if let last = dates.last {
                    let value: Int
                    switch last.period.end {
                    case .date(let end)?: value = end.year
                    default: value = last.period.start.year
                    }
                    year = Sourced(value: value, spans: [cell.sub(last.range).span], reading: .year)
                }
                let brackets = Brackets(of: cell, ifDatesIn: dates)
                let cut = dates.map(\.range).filter { !brackets.holdWords(around: $0) }
                parts += cell.removing(cut).flatMap { $0.split(by: Separators.strong + [" - ", ", "]) }
            }
            guard let name = parts.first else {
                findings.unplace(block, in: section)
                continue
            }
            var certification = ImportedCertification(name: name.quote())
            certification.year = year
            let rest = parts.dropFirst()
            let issuer = rest.first { EntryVocabulary.isOrganisation($0.text) || EntryVocabulary.isSchool($0.text) } ?? (rest.count == 1 ? rest.first : nil)
            certification.issuer = issuer?.quote()
            findings.cv.certifications.append(certification)
            for part in rest where part != issuer { findings.unplace(part, in: section) }
        }
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
