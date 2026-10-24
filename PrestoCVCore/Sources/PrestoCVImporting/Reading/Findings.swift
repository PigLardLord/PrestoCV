/// What the readers have found so far, and what they could not place or left out.
struct Findings {
    let document: SourceDocument
    var cv = ImportedCV()
    var unplaced: [UnplacedText] = []
    var leftOut: [LeftOutText] = []
    /// The blocks a reader has already taken as noise.
    var consumedBlocks: Set<Int> = []

    init(document: SourceDocument) {
        self.document = document
    }

    mutating func unplace(_ piece: Piece, in section: Section) {
        guard !piece.isEmpty else { return }
        unplaced.append(UnplacedText(
            section: section.kind, heading: section.heading.map { document.text(of: $0.span) }, text: piece.text, span: piece.span
        ))
    }

    /// A value that was read and is not used, as text not imported: the text of each of its spans.
    mutating func unplace(_ value: Sourced<String>, in section: Section) {
        for span in value.spans { unplace(Piece(text: document.text(of: span), span: span), in: section) }
    }

    /// The whole block as text not imported, its cells joined as the canonical text joins them.
    mutating func unplace(_ block: SourceBlock, in section: Section) {
        unplace(Piece(text: document.text(of: block.span), span: block.span), in: section)
    }

    /// Whether the piece is already text left out, such as a duration that LinkedIn computes.
    func isLeftOut(_ piece: Piece) -> Bool {
        leftOut.contains { $0.span?.contains(piece.span) == true }
    }

    mutating func leaveOut(_ piece: Piece, _ reason: LeftOutText.Reason) {
        leftOut.append(LeftOutText(text: piece.text, span: piece.span, reason: reason))
    }

    mutating func leaveOut(_ block: SourceBlock, _ reason: LeftOutText.Reason) {
        leaveOut(Piece(text: document.text(of: block.span), span: block.span), reason)
        consumedBlocks.insert(block.index)
    }
}
