/// Reads a whole source document: the noise first, then the sections, each with its reader. What no reader places
/// stays visible as text not imported, and the final gate checks every value against its spans.
enum CVReader {

    static func read(_ document: SourceDocument, leftOut: [LeftOutText]) -> ImportResult {
        var findings = Findings(document: document)
        findings.leftOut = leftOut
        NoiseReader.read(into: &findings)
        let sections = SectionSegmenter.sections(of: document)

        HeaderReader.read(
            sections.filter { $0.kind == .header || $0.kind == .personal },
            hasSummarySection: sections.contains { $0.kind == .summary }, into: &findings
        )
        for section in sections {
            switch section.kind {
            case .header, .personal:
                break
            case .summary:
                readSummary(section, into: &findings)
            case .experience:
                EntryReader.read(section, kind: .experience, into: &findings)
            case .education:
                EntryReader.read(section, kind: .education, into: &findings)
            case .skills:
                ListReader.readSkills(section, into: &findings)
            case .interests:
                ListReader.readInterests(section, into: &findings)
            case .languages:
                LanguageReader.read(section, into: &findings)
            case .certifications:
                CertificationReader.read(section, into: &findings)
            case .projects, .volunteering, .references, .drivingLicence, .additional, .unknown:
                // The CV has no field for these: they stay visible, with their heading
                for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
                    findings.unplace(block, in: section)
                }
            }
        }
        let result = ImportResult(
            document: document, cv: findings.cv, language: SectionSegmenter.language(of: sections, in: document),
            unplaced: findings.unplaced.sorted { $0.span < $1.span }, leftOut: findings.leftOut
        )
        return ImportGrounding.enforced(result)
    }

    /// The summary: the lines of its section, in order.
    private static func readSummary(_ section: Section, into findings: inout Findings) {
        let pieces = section.blocks.filter { !findings.consumedBlocks.contains($0.index) }.flatMap { section.cells(of: $0, in: findings.document) }
        guard !pieces.isEmpty else { return }
        if let existing = findings.cv.person.summary, existing.check == nil {
            findings.cv.person.summary = Sourced(value: existing.value + "\n" + pieces.map(\.text).joined(separator: "\n"), spans: existing.spans + pieces.map(\.span))
        } else {
            findings.cv.person.summary = Sourced(value: pieces.map(\.text).joined(separator: "\n"), spans: pieces.map(\.span))
        }
    }
}
