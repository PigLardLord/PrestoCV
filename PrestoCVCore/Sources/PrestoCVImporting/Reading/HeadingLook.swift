// MARK: - The look of the headings

/// A heading the vocabulary does not know, told by the look of the headings it knows (#454): a short line in capitals,
/// drawn as two or more known headings of the CV are drawn and after the same kind of gap, opens a section of its own,
/// so that its lines stay visible as text not imported (ADR 0027) instead of being read into the section before it.
///
/// Only the known headings vouch for a line, never the lines that could be headings themselves. A line that reads as a
/// part of an entry opens nothing, so that an entry is never cut from its section:
/// - one with a digit, a period, a separator of an entry or no word of five letters (an acronym);
/// - one the vocabulary of the entries knows as a role, an organisation, a school or a degree, wherever the word stands:
///   a role in capitals over its employer and its dates has the shape of a heading over a name and its dates, and only
///   the words tell them apart. A heading that holds such a word ("FOUNDER VENTURES") is read into the section before
///   (#466), so that a job is never cut from its section;
/// - one before a period (a role before its dates), or before a short bare line and then a period (a role, its employer,
///   its dates), or between a period and a detail (an employer and its dates, then the role and its bullets);
/// - the first line of its section, and one drawn as a line the section already holds (an employer or a sub-heading).
///
/// The line below settles what is left. A line of an entry of its own, cut into parts that are neither roles nor places
/// ("Hive Monitor Kit — maker, solo"), stands under a heading. A bullet, a line in one part ("Technician"), one with a
/// role ("Technician — Hollowford", "Pump Division — Technician") or one whose later part is a place ("Night Shifts —
/// Dresden") stands as well under the employer of a job: the line is doubtful. In the jobs and the studies a doubtful
/// line stays where the entries read it, and the entry that takes it is to be checked; in any other section it opens a
/// section of its own, as before.
struct HeadingLook {

    /// What a line in capitals is for the sections.
    enum Reading: Equatable {
        /// A part of the section before it.
        case partOfTheSection
        /// A heading the vocabulary does not know.
        case heading
        /// A heading or the employer of a job: the line below does not tell which.
        case doubtful
    }

    /// The known headings in capitals: alone on their line and in the vocabulary.
    private let known: [SourceBlock]

    /// - Throws: `LimitReached` past the budget of `work`; `CancellationError` once the task is cancelled.
    init(of document: SourceDocument, work: inout AnalysisWork) throws {
        try work.count(document.blocks.count)
        known = document.blocks.filter { block in
            guard block.kind == .line, block.cells.count == 1 else { return false }
            let text = document.text(of: block.span)
            return Self.isCapitals(text) && text.words.count <= SectionVocabulary.maximumWords
                && SectionVocabulary.kind(ofHeading: text) != nil
        }
    }

    /// What `block`, at `position` in the document, is after the blocks of `section`.
    /// - Throws: `LimitReached` past the budget of `work`; `CancellationError` once the task is cancelled.
    func reading(
        _ block: SourceBlock, at position: Int, after section: Section, in document: SourceDocument, work: inout AnalysisWork
    ) throws -> Reading {
        guard !section.blocks.isEmpty, Self.isCandidate(block, in: document), Self.contentFollows(position, in: document),
              !Self.sitsInAnEntryHead(position, in: document) else {
            return .partOfTheSection
        }
        try work.count(section.blocks.count + known.count)
        // A line drawn as one the section already holds is a part of its entries: an employer, a sub-heading
        let drawnAsAnEntry = section.blocks.contains { other in
            Self.isCapitals(document.text(of: other.span)) && Self.drawnAlike(other, block)
        }
        guard !drawnAsAnEntry,
              known.count(where: { Self.drawnAlike($0, block) && $0.followsGap == block.followsGap }) >= 2 else {
            return .partOfTheSection
        }
        return Self.opensAnEntry(document.blocks[position + 1], in: document) ? .heading : .doubtful
    }

    /// Whether a text has letters, all of them capitals.
    static func isCapitals(_ text: some StringProtocol) -> Bool {
        let letters = text.filter(\.isLetter)
        return !letters.isEmpty && letters.allSatisfy(\.isUppercase)
    }

    // MARK: Private

    /// What sets the parts of an entry apart on one line ("ROLE — EMPLOYER", "CITY, COUNTRY").
    private static let entrySeparators = [" — ", " – ", " - ", "|", "·", "•", ","]

    /// A short line in capitals, alone in its block, that reads as no part of an entry.
    private static func isCandidate(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        guard block.kind == .line, block.cells.count == 1 else { return false }
        let text = document.text(of: block.span)
        let words = text.words
        return isCapitals(text) && words.count <= 4 && words.contains { $0.count(where: \.isLetter) >= 5 }
            && !text.contains(where: \.isNumber) && DateReader.periods(in: text).isEmpty
            && !entrySeparators.contains { text.contains($0) }
            && !(EntryVocabulary.isRole(text) || EntryVocabulary.isOrganisation(text)
                || EntryVocabulary.isSchool(text) || EntryVocabulary.isDegree(text))
    }

    /// Whether the block after `position` is content of the same column for the heading: no period (a role in capitals
    /// comes before its dates) and no heading of the vocabulary (a heading with nothing under it would hold no line).
    private static func contentFollows(_ position: Int, in document: SourceDocument) -> Bool {
        guard position + 1 < document.blocks.count else { return false }
        let block = document.blocks[position]
        let next = document.blocks[position + 1]
        let text = document.text(of: next.span)
        let isHeading = text.words.count <= SectionVocabulary.maximumWords && SectionVocabulary.kind(ofHeading: text) != nil
        return next.column == block.column && DateReader.periods(in: text).isEmpty && !isHeading
    }

    /// Whether the line at `position` sits where an entry has its role, whatever its words: between a line with a period
    /// and a detail (the employer and its dates, then the role and its bullets), or before a short bare line followed by
    /// a period (the role, its employer, its dates). An unknown heading after an entry that ends with its dates is still
    /// told, as long as an entry, not a detail, opens under it.
    private static func sitsInAnEntryHead(_ position: Int, in document: SourceDocument) -> Bool {
        let blocks = document.blocks
        let column = blocks[position].column
        let next = position + 1 < blocks.count ? blocks[position + 1] : nil
        if position > 0, let next, holdsAPeriod(blocks[position - 1], in: document), isADetail(next, in: document) {
            return true
        }
        guard let next, isBare(next, in: document), position + 2 < blocks.count else { return false }
        let after = blocks[position + 2]
        return after.column == column && holdsAPeriod(after, in: document)
    }

    /// Whether a block reads as the first line of an entry of its own: a line cut by the separators of the entries into
    /// two or more parts with letters, none of them a role and none past the first a place ("Hive Monitor Kit — maker,
    /// solo"). Under the employer of a job stand a bullet, a role alone ("Technician"), a role with its place, known or
    /// not ("Technician — Hollowford"), a team and its role ("Pump Division — Technician") and a line whose later part
    /// is a known place.
    private static func opensAnEntry(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        guard block.kind == .line else { return false }
        let parts = Piece.cells(of: block, in: document).flatMap { $0.split(by: Separators.strong) }
            .filter { $0.text.contains(where: \.isLetter) }
        return parts.count >= 2 && !parts.contains { EntryVocabulary.isRole($0.text) }
            && !parts.dropFirst().contains { Places.isKnownPlace($0.text) }
    }

    /// Whether the text of a block holds a period ("2017 – Present", "July 2017 – June 2019").
    private static func holdsAPeriod(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        !DateReader.periods(in: document.text(of: block.span)).isEmpty
    }

    /// A detail of an entry: a bullet, or a line that ends as a sentence.
    private static func isADetail(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        block.kind == .listItem || document.text(of: block.span).hasSuffix(".")
    }

    /// A short line alone in its block, with no separator of an entry and no end of a sentence: the name of an employer
    /// or of a school.
    private static func isBare(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        guard block.kind == .line, block.cells.count == 1 else { return false }
        let text = document.text(of: block.span)
        return text.words.count <= 6 && !text.hasSuffix(".") && !entrySeparators.contains { text.contains($0) }
    }

    /// Drawn alike: the same emphasis and column and, in a PDF, the same size and left edge.
    private static func drawnAlike(_ first: SourceBlock, _ second: SourceBlock) -> Bool {
        guard first.isEmphasized == second.isEmphasized, first.column == second.column else { return false }
        switch (first.frame, second.frame) {
        case (nil, nil):
            return true
        case let (firstFrame?, secondFrame?):
            guard let firstSize = first.fontSize, let secondSize = second.fontSize else { return false }
            return abs(firstSize - secondSize) <= 0.25 && abs(firstFrame.x - secondFrame.x) <= 2
        default:
            return false
        }
    }
}
