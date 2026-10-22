/// Reads certifications: a name, and the issuer, the year, the web address and the description that the text states.
/// A certification starts at a line. A line goes on with the certification above it only on clear evidence, the rules of
/// `CertificationLine.role(after:)`; anything else starts a certification of its own, and what no rule places stays
/// visible as text not imported.
enum CertificationReader {

    static func read(_ section: Section, into findings: inout Findings) {
        var open: OpenCertification?
        for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                open = nil
                continue
            }
            let cells = section.cells(of: block, in: findings.document)
            guard !cells.isEmpty else { continue }
            let line = CertificationLine(block: block, cells: cells)
            switch line.role(after: open) {
            case .link:
                if let open { addLink(of: line, to: open.index, in: section, into: &findings) }
            case .description:
                if let open { addDescription(of: line, to: open.index, into: &findings) }
            case .entry(let check):
                open = readEntry(line, check: check, in: section, into: &findings)
            case .unplaced:
                findings.unplace(block, in: section)
            }
        }
    }

    // MARK: A certification's line

    /// The line of a certification: its title first, then what follows it, split at the separators between the parts.
    /// A web address of the line is its link.
    private static func readEntry(_ line: CertificationLine, check: CheckReason?, in section: Section, into findings: inout Findings) -> OpenCertification? {
        // A sentence is no title with an issuer: no date, comma or address cuts it, and the person sees it whole
        if line.endsAsSentence, let cell = line.cells.first {
            findings.cv.certifications.append(ImportedCertification(name: cell.quote(check: check)))
            return OpenCertification(index: findings.cv.certifications.count - 1, title: line.block, titleIsSentence: true, statesIssuerOrYear: false)
        }
        var year: Sourced<Int>?
        var parts: [Piece] = []
        for piece in line.around {
            let dates = DateReader.periods(in: piece.text)
            if let last = dates.last {
                let value: Int
                switch last.period.end {
                case .date(let end)?: value = end.year
                default: value = last.period.start.year
                }
                year = Sourced(value: value, spans: [piece.sub(last.range).span], reading: .year)
            }
            let cut = dates.map(\.range).filter { !isPartOfBracketedWords($0, in: piece) }
            parts += piece.removing(cut).flatMap { $0.split(by: Separators.strong + [" - ", ", "]) }
        }
        // The label of the line's link, "Verify:", is left out, not read as the issuer
        let labels = line.addresses.isEmpty ? [] : parts.filter { EntryVocabulary.isLinkLabel($0.text) }
        parts.removeAll { labels.contains($0) }
        guard let name = parts.first else {
            findings.unplace(line.block, in: section)
            return nil
        }
        for label in labels { findings.leaveOut(label, .categoryLabel) }
        var certification = ImportedCertification(name: name.quote(check: check))
        certification.year = year
        certification.link = line.addresses.first?.link.address
        let rest = parts.dropFirst()
        let issuer = rest.first { EntryVocabulary.isOrganisation($0.text) || EntryVocabulary.isSchool($0.text) } ?? (rest.count == 1 ? rest.first : nil)
        certification.issuer = issuer?.quote()
        findings.cv.certifications.append(certification)
        for piece in (rest.filter { $0 != issuer } + line.addresses.dropFirst().map(\.piece)).sorted(by: { $0.span < $1.span }) {
            findings.unplace(piece, in: section)
        }
        return OpenCertification(
            index: findings.cv.certifications.count - 1, title: line.block, titleIsSentence: EntryReader.endsAsSentence(name.text),
            statesIssuerOrYear: certification.issuer != nil || certification.year != nil
        )
    }

    /// A date inside a bracket that holds other words, "Course (Pro, 2024)", is a part of those words: it is read as the
    /// year, and it stays in the text, so that the bracket stays whole.
    private static func isPartOfBracketedWords(_ date: Range<String.Index>, in piece: Piece) -> Bool {
        guard let bracket = piece.bracketedRanges().first(where: { $0.contains(date.lowerBound) }) else { return false }
        return piece.text[bracket.lowerBound..<date.lowerBound].contains(where: \.isLetter)
            || piece.text[date.upperBound..<bracket.upperBound].contains(where: \.isLetter)
    }

    // MARK: The lines under it

    /// The first address is the link, if the certification has none yet; the labels around it are left out, and any
    /// other address stays visible as text not imported.
    private static func addLink(of line: CertificationLine, to index: Int, in section: Section, into findings: inout Findings) {
        for label in line.around { findings.leaveOut(label, .categoryLabel) }
        for address in line.addresses {
            if findings.cv.certifications[index].link == nil {
                findings.cv.certifications[index].link = address.link.address
            } else {
                findings.unplace(address.piece, in: section)
            }
        }
    }

    /// A sentence goes on with the description in its own line.
    private static func addDescription(of line: CertificationLine, to index: Int, into findings: inout Findings) {
        let text = findings.document.text(of: line.block.span)
        let before = findings.cv.certifications[index].description
        findings.cv.certifications[index].description = Sourced(
            value: ((before.map { [$0.value] } ?? []) + [text]).joined(separator: "\n"),
            spans: (before?.spans ?? []) + [line.block.span]
        )
    }
}
