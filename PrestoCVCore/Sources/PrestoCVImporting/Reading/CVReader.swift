/// Reads a whole source document: the noise first, then the sections, each with its reader. What no reader places
/// stays visible as text not imported, and the final gate checks every value against its spans.
enum CVReader {

    /// What reading a document gave: the result, and the sections the document was split into, which the log counts.
    struct Reading {
        var result: ImportResult
        var sections: [Section]
    }

    /// - Throws: `CancellationError` once the task is cancelled; `LimitReached` with its steps when the reading passes
    ///   the budget of `work`.
    static func read(_ document: SourceDocument, leftOut: [LeftOutText], work: AnalysisWork) throws -> Reading {
        let (findings, sections) = try readSections(document, leftOut: leftOut, work: work)
        let result = ImportResult(
            document: document, cv: findings.cv, language: SectionSegmenter.language(of: sections, in: document),
            unplaced: findings.unplaced.sorted { $0.span < $1.span }, leftOut: findings.leftOut
        )
        return Reading(result: Remainder.swept(ImportGrounding.enforced(result), sections: sections), sections: sections)
    }

    /// What the readers found in each section, before anything is checked.
    static func readSections(
        _ document: SourceDocument, leftOut: [LeftOutText], work: AnalysisWork
    ) throws -> (findings: Findings, sections: [Section]) {
        var findings = Findings(document: document, work: work)
        findings.leftOut = leftOut
        NoiseReader.read(into: &findings)
        let sections = try SectionSegmenter.sections(of: document, work: &findings.work)

        HeaderReader.read(
            sections.filter { $0.kind == .header || $0.kind == .personal }, headingsThatCouldBeTheName: sections.filter(\.headingCouldBeTheName),
            hasSummarySection: sections.contains { $0.kind == .summary }, into: &findings
        )
        for section in sections {
            try Task.checkCancellation()
            switch section.kind {
            case .header, .personal:
                break
            case .summary:
                readSummary(section, into: &findings)
            case .experience:
                try EntryReader.read(section, kind: .experience, into: &findings)
            case .education:
                try readStudies(section, into: &findings)
            case .additional where section.parts == StudiesAndCertifications.joinedKinds:
                try readStudies(section, into: &findings)
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
        return (findings, sections)
    }

    /// The rules that read a section, as the trace of a test build names them (ADR 0032): both readers for a heading that
    /// joins the studies and the certifications, the reader of its kind otherwise.
    static func readerName(of section: Section) -> String {
        section.parts == StudiesAndCertifications.joinedKinds ? "EntryReader.education+CertificationReader" : readerName(of: section.kind)
    }

    /// The rule that reads a kind of section, as the trace of a test build names it (ADR 0032). It follows the switch of
    /// `readSections`; "none" for a kind the CV has no field for, whose text stays visible.
    static func readerName(of kind: SectionKind) -> String {
        switch kind {
        case .header, .personal: "HeaderReader"
        case .summary: "CVReader.summary"
        case .experience: "EntryReader.experience"
        case .education: "EntryReader.education"
        case .skills: "ListReader.skills"
        case .interests: "ListReader.interests"
        case .languages: "LanguageReader"
        case .certifications: "CertificationReader"
        case .projects, .volunteering, .references, .drivingLicence, .additional, .unknown: "none"
        }
    }

    /// A section of studies, or one that joins the studies and the certifications: each run of lines of one kind by its own
    /// reader, in the order of the CV (#453). A joined section whose lines show neither kind stays visible, with its heading,
    /// and so does a line whose kind the reading cannot tell.
    private static func readStudies(_ section: Section, into findings: inout Findings) throws {
        for run in StudiesAndCertifications.runs(of: section, in: findings.document, consumed: findings.consumedBlocks) {
            switch run.kind {
            case .certifications:
                CertificationReader.read(run, into: &findings)
            case .education:
                try EntryReader.read(run, kind: .education, into: &findings)
            default:
                // A line whose kind the reading cannot tell, or a section that shows neither kind: visible under its own
                // heading and the kind of its section
                for block in run.blocks where !findings.consumedBlocks.contains(block.index) {
                    findings.unplace(block, in: section)
                }
            }
        }
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
