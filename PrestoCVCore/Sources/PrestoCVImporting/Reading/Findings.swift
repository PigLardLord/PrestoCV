/// What the readers have found so far, and what they could not place or left out.
struct Findings {
    let document: SourceDocument
    var cv = ImportedCV()
    var unplaced: [UnplacedText] = []
    var leftOut: [LeftOutText] = []
    /// The blocks a reader has already taken as noise.
    var consumedBlocks: Set<Int> = []
    /// The work of the reading so far: a search that grows faster than the text counts its steps here before it starts
    /// (R8). It carries on from the work of a PDF's page analysis, so that a PDF has one budget.
    var work: AnalysisWork

    init(document: SourceDocument, work: AnalysisWork) {
        self.document = document
        self.work = work
    }

    mutating func unplace(_ piece: Piece, in section: Section) {
        guard !piece.isEmpty else { return }
        unplaced.append(UnplacedText(section: section.kind, heading: heading(of: section), text: piece.text, span: piece.span))
    }

    /// The heading of the section as the CV writes it, without the values a heading row also holds; nil when the
    /// section has none.
    func heading(of section: Section) -> String? {
        section.headingText(in: document)
    }

    /// A value that was read and is not used, as text not imported: the text of each of its spans.
    mutating func unplace(_ value: Sourced<String>, in section: Section) {
        for span in value.spans { unplace(Piece(text: document.text(of: span), span: span), in: section) }
    }

    /// The whole block as text not imported, its cells joined as the canonical text joins them.
    mutating func unplace(_ block: SourceBlock, in section: Section) {
        unplace(Piece(text: document.text(of: block.span), span: block.span), in: section)
    }

    /// The values of a block of the section as one passage of text not imported: a heading row gives its cells after
    /// the heading's own one, which is the passage's heading.
    mutating func unplaceValues(of block: SourceBlock, in section: Section) {
        guard block.index == section.heading?.index else { return unplace(block, in: section) }
        let values = section.cells(of: block, in: document)
        guard let first = values.first, let last = values.last else { return }
        let span = SourceSpan(first.span.lowerBound, last.span.upperBound)
        unplace(Piece(text: document.text(of: span), span: span), in: section)
    }

    mutating func leaveOut(_ piece: Piece, _ reason: LeftOutText.Reason) {
        leftOut.append(LeftOutText(text: piece.text, span: piece.span, reason: reason))
    }

    mutating func leaveOut(_ block: SourceBlock, _ reason: LeftOutText.Reason) {
        leaveOut(Piece(text: document.text(of: block.span), span: block.span), reason)
        consumedBlocks.insert(block.index)
    }
}
