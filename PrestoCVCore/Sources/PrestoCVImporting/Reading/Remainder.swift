/// The last look at a read document: any line of the text that no value, no text not imported, no text left out and no
/// heading holds becomes text not imported (ADR 0027). The readers place or unplace everything themselves; this is the
/// net under them, for the order of lines and the layouts they were not written for, so that nothing the person wrote
/// goes without a trace.
enum Remainder {

    /// The result with every line that nothing accounts for added to the text not imported, in its section.
    static func swept(_ result: ImportResult, sections: [Section]) -> ImportResult {
        var swept = result
        var spans = result.cv.sourceSpans
        spans += result.unplaced.map(\.span)
        spans += result.leftOut.compactMap(\.span)
        spans += sections.compactMap(\.headingSpan)
        // The section of a passage is the first one that holds it in one of its blocks
        let blocks = sections.enumerated().flatMap { place, section in section.blocks.map { (span: $0.span, section: place) } }
        let holders = SpanIndex(blocks.map(\.span))
        for piece in lost(in: result.document, by: spans) {
            let section = holders.firstHolding(piece.span).map { sections[blocks[$0].section] }
            swept.unplaced.append(UnplacedText(
                section: section?.kind ?? .unknown, heading: section?.headingText(in: result.document),
                text: piece.text, span: piece.span
            ))
        }
        swept.unplaced = merged(swept.unplaced, in: result.document)
        return swept
    }

    /// The text not imported as separate passages of the source, in order: passages that share some of their text are
    /// one passage, so that nothing the person wrote is shown twice. The passage has the section of the first of them
    /// that is in a section.
    static func merged(_ unplaced: [UnplacedText], in document: SourceDocument) -> [UnplacedText] {
        var passages: [UnplacedText] = []
        for item in unplaced.sorted(by: { $0.span < $1.span }) {
            guard let last = passages.last, item.span.lowerBound < last.span.upperBound else {
                passages.append(item)
                continue
            }
            let span = SourceSpan(last.span.lowerBound, max(last.span.upperBound, item.span.upperBound))
            let owner = last.section == .unknown ? item : last
            passages[passages.count - 1] = UnplacedText(
                section: owner.section, heading: owner.heading, text: document.text(of: span), span: span
            )
        }
        return passages
    }

    /// What the person wrote that the spans do not cover, line by line, and that is no structure: the labels and the
    /// connectors of a layout are not content, a line of text is.
    static func lost(in document: SourceDocument, by spans: [SourceSpan]) -> [Piece] {
        uncovered(document, by: spans).flatMap { $0.split(by: ["\n", "\t"]) }.filter { !isStructural($0.text) }
    }

    /// The runs of the text that no span covers and that hold a letter or a digit.
    static func uncovered(_ document: SourceDocument, by spans: [SourceSpan]) -> [Piece] {
        var covered = [Bool](repeating: false, count: document.scalarCount)
        for span in spans where span.lowerBound >= 0 && span.upperBound <= covered.count {
            for index in span.lowerBound..<span.upperBound { covered[index] = true }
        }
        let scalars = Array(document.text.unicodeScalars)
        var runs: [Piece] = []
        var start: Int?
        for index in 0...scalars.count {
            let isOpen = index < scalars.count && !covered[index]
            if isOpen, start == nil { start = index }
            if !isOpen, let begin = start {
                let span = SourceSpan(begin, index)
                let text = document.text(of: span)
                if text.contains(where: { $0.isLetter || $0.isNumber }) { runs.append(Piece(text: text, span: span)) }
                start = nil
            }
        }
        return runs
    }

    /// A label of a form or of a table of the Europass, a language label, or the word between a role and its employer.
    static func isStructural(_ text: String) -> Bool {
        if ContactReader.isContactLabel(text) || EntryVocabulary.personalLabel(text) != nil || EntryVocabulary.entryLabel(text) != nil
            || SectionVocabulary.isLanguageLabel(text) { return true }
        let key = SectionVocabulary.key(text)
        return EntryVocabulary.roleEmployerConnectors.contains { SectionVocabulary.key($0) == key }
    }
}
