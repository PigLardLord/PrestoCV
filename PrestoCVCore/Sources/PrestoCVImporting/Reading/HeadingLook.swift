// MARK: - The look of the headings

/// A heading the vocabulary does not know, told by the look of the headings it knows (#454): a short line in capitals,
/// drawn as two or more known headings of the CV are drawn and after the same kind of gap, opens a section of its own,
/// so that its lines stay visible as text not imported (ADR 0027) instead of being read into the section before it.
///
/// Only the known headings vouch for a line, never the lines that could be headings themselves. A line that reads as a
/// part of an entry opens nothing: one with a digit, a period, a separator of an entry or no word of five letters (an
/// acronym), one before a period (a role), the first line of its section and one drawn as a line the section already
/// holds (an employer or a sub-heading in capitals).
struct HeadingLook {

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

    /// Whether `block`, at `position` in the document, opens a section of its own after the blocks of `section`.
    /// - Throws: `LimitReached` past the budget of `work`; `CancellationError` once the task is cancelled.
    func opensSection(
        _ block: SourceBlock, at position: Int, after section: Section, in document: SourceDocument, work: inout AnalysisWork
    ) throws -> Bool {
        guard !section.blocks.isEmpty, Self.isCandidate(block, in: document), Self.contentFollows(position, in: document) else {
            return false
        }
        try work.count(section.blocks.count + known.count)
        // A line drawn as one the section already holds is a part of its entries: an employer, a sub-heading
        let drawnAsAnEntry = section.blocks.contains { other in
            Self.isCapitals(document.text(of: other.span)) && Self.drawnAlike(other, block)
        }
        guard !drawnAsAnEntry else { return false }
        return known.count { Self.drawnAlike($0, block) && $0.followsGap == block.followsGap } >= 2
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
