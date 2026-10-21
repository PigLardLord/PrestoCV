import PrestoCVDomain

/// Reads certifications: a name, and the issuer, the year, the web address and the description that the text states.
/// A certification starts at a line. The lines under it that are only a web address, or read as its description, belong
/// to it; a line that states a date, a list item or a row of cells starts the next one. What no rule places stays
/// visible as text not imported.
enum CertificationReader {

    /// The certification being read: its place among the findings, and whether its line stood out from the lines under it.
    private struct Open {
        let index: Int
        let isEmphasized: Bool
    }

    static func read(_ section: Section, into findings: inout Findings) {
        var open: Open?
        for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                continue
            }
            let cells = section.cells(of: block, in: findings.document)
            guard let cell = cells.first else { continue }
            if let current = open, let continuation = continuation(of: block, cells: cells, after: current) {
                add(continuation, from: cell, to: current.index, in: section, into: &findings)
            } else {
                open = readEntry(block, cells: cells, in: section, into: &findings)
            }
        }
    }

    // MARK: A certification's line

    /// The line of a certification: its title first, then what follows it, split at the separators between the parts.
    private static func readEntry(_ block: SourceBlock, cells: [Piece], in section: Section, into findings: inout Findings) -> Open? {
        var year: Sourced<Int>?
        var link: Sourced<WebLink>?
        var parts: [Piece] = []
        var otherAddresses: [Piece] = []
        for cell in cells {
            let addresses = ContactReader.webAddresses(in: cell)
            for address in addresses {
                if link == nil {
                    link = address.link.address
                } else {
                    otherAddresses.append(cell.sub(address.range))
                }
            }
            for piece in cell.removing(addresses.map(\.range)) {
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
        }
        guard let name = parts.first else {
            findings.unplace(block, in: section)
            return nil
        }
        var certification = ImportedCertification(name: name.quote())
        certification.year = year
        certification.link = link
        let rest = parts.dropFirst()
        let issuer = rest.first { EntryVocabulary.isOrganisation($0.text) || EntryVocabulary.isSchool($0.text) } ?? (rest.count == 1 ? rest.first : nil)
        certification.issuer = issuer?.quote()
        findings.cv.certifications.append(certification)
        for piece in (rest.filter { $0 != issuer } + otherAddresses).sorted(by: { $0.span < $1.span }) {
            findings.unplace(piece, in: section)
        }
        return Open(index: findings.cv.certifications.count - 1, isEmphasized: block.isEmphasized)
    }

    /// A date inside a bracket that holds other words, "Course (Pro, 2024)", is a part of those words: it is read as the
    /// year, and it stays in the text, so that the bracket stays whole.
    private static func isPartOfBracketedWords(_ date: Range<String.Index>, in piece: Piece) -> Bool {
        guard let bracket = piece.bracketedRanges().first(where: { $0.contains(date.lowerBound) }) else { return false }
        return piece.text[bracket.lowerBound..<date.lowerBound].contains(where: \.isLetter)
            || piece.text[date.upperBound..<bracket.upperBound].contains(where: \.isLetter)
    }

    // MARK: The lines under it

    /// What a line under a certification adds to it.
    private enum Continuation {
        /// A web address, with the label around it.
        case link(addresses: [(link: ImportedLink, range: Range<String.Index>)], labels: [Piece])
        case description
    }

    /// A line goes on with the certification before it when it is a plain line of one cell that is a web address with at
    /// most the label of a link, or states no date and is a sentence, or is in the regular weight under a title that stood
    /// out. Anything else, such as a short line in a list of plain lines, or a title with its address, is a certification
    /// of its own.
    private static func continuation(of block: SourceBlock, cells: [Piece], after open: Open) -> Continuation? {
        guard block.kind == .line, cells.count == 1, let cell = cells.first else { return nil }
        let addresses = ContactReader.webAddresses(in: cell)
        let around = cell.removing(addresses.map(\.range))
        if !addresses.isEmpty, around.allSatisfy({ linkLabels.contains(SectionVocabulary.key($0.text)) }) {
            return .link(addresses: addresses, labels: around)
        }
        guard !around.contains(where: { !DateReader.periods(in: $0.text).isEmpty }) else { return nil }
        let isDescription = EntryReader.readsAsProse(block, text: cell.text) || (open.isEmphasized && !block.isEmphasized)
        return isDescription ? .description : nil
    }

    /// What labels the web address of a certification, in the six languages: "Credential: https://…". A closed list, so
    /// that a short title with its address is never taken for a label.
    private static let linkLabels: Set<String> = Set([
        "link", "url", "web", "website", "credential", "credential url", "credential link", "certificate", "certificate link",
        "certificate url", "verify", "verify at", "verification", "verification link", "verification url", "view credential",
        "view certificate", "see credential", "badge", "digital badge", "details", "more info", "more information", "online",
        "collegamento", "sito", "sito web", "verifica", "verifica online", "credenziale", "attestato", "certificato", "dettagli",
        "maggiori informazioni", "verknüpfung", "zertifikat", "zertifikatslink", "nachweis", "verifizieren", "überprüfen",
        "überprüfung", "anmeldedaten", "weitere informationen", "webseite", "enlace", "sitio web", "verificar", "verificación",
        "credencial", "certificado", "detalles", "más información", "lien", "site web", "vérifier", "vérification", "attestation",
        "certificat", "détails", "plus d'informations", "ligação", "site", "verificação", "mais informações",
    ].map(SectionVocabulary.key))

    private static func add(_ continuation: Continuation, from line: Piece, to index: Int, in section: Section, into findings: inout Findings) {
        switch continuation {
        case .description:
            let before = findings.cv.certifications[index].description
            findings.cv.certifications[index].description = Sourced(
                value: ((before.map { [$0.value] } ?? []) + [line.text]).joined(separator: "\n"),
                spans: (before?.spans ?? []) + [line.span]
            )
        case .link(let addresses, let labels):
            for label in labels { findings.leaveOut(label, .categoryLabel) }
            for address in addresses {
                if findings.cv.certifications[index].link == nil {
                    findings.cv.certifications[index].link = address.link.address
                } else {
                    findings.unplace(line.sub(address.range), in: section)
                }
            }
        }
    }
}
