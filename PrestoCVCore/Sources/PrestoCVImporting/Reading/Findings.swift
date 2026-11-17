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

    /// The heading of the section as the CV writes it; nil when the section has none.
    func heading(of section: Section) -> String? {
        section.heading.map { document.text(of: $0.span) }
    }

    /// A value that was read and is not used, as text not imported: the text of each of its spans.
    mutating func unplace(_ value: Sourced<String>, in section: Section) {
        for span in value.spans { unplace(Piece(text: document.text(of: span), span: span), in: section) }
    }

    /// The whole block as text not imported, its cells joined as the canonical text joins them.
    mutating func unplace(_ block: SourceBlock, in section: Section) {
        unplace(Piece(text: document.text(of: block.span), span: block.span), in: section)
    }

    mutating func leaveOut(_ piece: Piece, _ reason: LeftOutText.Reason) {
        leftOut.append(LeftOutText(text: piece.text, span: piece.span, reason: reason))
    }

    mutating func leaveOut(_ block: SourceBlock, _ reason: LeftOutText.Reason) {
        leaveOut(Piece(text: document.text(of: block.span), span: block.span), reason)
        consumedBlocks.insert(block.index)
    }
}
