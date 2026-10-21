/// Reads certifications: a name, the issuer when the line names one, and the year a date of the line states.
enum CertificationReader {

    static func read(_ section: Section, into findings: inout Findings) {
        for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                continue
            }
            let cells = section.cells(of: block, in: findings.document)
            guard let line = cells.first.map({ _ in cells }) else { continue }
            var year: Sourced<Int>?
            var parts: [Piece] = []
            for cell in line {
                let dates = DateReader.periods(in: cell.text)
                if let last = dates.last {
                    let value: Int
                    switch last.period.end {
                    case .date(let end)?: value = end.year
                    default: value = last.period.start.year
                    }
                    year = Sourced(value: value, spans: [cell.sub(last.range).span], reading: .year)
                }
                parts += cell.removing(dates.map(\.range)).flatMap { $0.split(by: Separators.strong + [" - ", ", "]) }
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
}
