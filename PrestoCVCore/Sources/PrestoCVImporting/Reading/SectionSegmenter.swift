// MARK: - Sections

/// A section of the CV: its heading, if any, and its blocks in reading order.
struct Section: Equatable {
    var kind: SectionKind
    var heading: SourceBlock?
    var blocks: [SourceBlock]
    /// The languages whose vocabulary the heading is from.
    var languages: Set<CVLanguage>

    /// What the heading is in the text: its block, or, when a row of cells opens the section, its first cell.
    var headingSpan: SourceSpan? {
        guard let heading else { return nil }
        return heading.cells.count > 1 && blocks.first?.index == heading.index ? heading.cells[0] : heading.span
    }

    /// The cells of a block of the section: a heading row that also holds the section's first value, as the formato
    /// europeo's "CAPACITÀ E COMPETENZE TECNICHE | …", gives only its value.
    func cells(of block: SourceBlock, in document: SourceDocument) -> [Piece] {
        let cells = Piece.cells(of: block, in: document)
        return block.index == heading?.index ? Array(cells.dropFirst()) : cells
    }
}

/// Splits the document into sections at its headings (ADR 0027).
enum SectionSegmenter {

    static func sections(of document: SourceDocument) -> [Section] {
        var sections: [Section] = [Section(kind: .header, heading: nil, blocks: [], languages: [])]
        var column = document.blocks.first?.column
        for (position, block) in document.blocks.enumerated() {
            // A second column starts with its own head: a sidebar that opens with the contacts
            if block.column != column {
                column = block.column
                sections.append(Section(kind: .header, heading: nil, blocks: [], languages: []))
            }
            let firstCell = document.text(ofCell: 0, in: block)
            // LinkedIn's PDF copied as text gives its sidebar first: the profile starts at the name, a few lines before
            // its summary or experience
            if sidebarKinds.contains(sections[sections.count - 1].kind), block.cells.count == 1, HeaderReader.looksLikeName(firstCell),
               startsProfile(after: position, in: document) {
                sections.append(Section(kind: .header, heading: nil, blocks: [block], languages: []))
                continue
            }
            if SectionVocabulary.isLanguageLabel(firstCell) {
                // A Europass row such as "Madrelingua | Italiano" opens the languages and stays in them
                if sections[sections.count - 1].kind != .languages {
                    sections.append(Section(kind: .languages, heading: nil, blocks: [], languages: []))
                }
                sections[sections.count - 1].blocks.append(block)
                continue
            }
            if block.cells.count > 1, block.kind != .listItem, block.kind != .tableHeader,
               let match = SectionVocabulary.kind(ofHeading: firstCell), firstCell.words.count <= 7 {
                // A heading in the first cell of a row, its section's first value in the others
                sections.append(Section(kind: match.kind, heading: block, blocks: [block], languages: match.languages))
                continue
            }
            if let match = heading(block, in: document, isFirst: sections.count == 1 && sections[0].blocks.isEmpty) {
                sections.append(Section(kind: match.kind, heading: block, blocks: [], languages: match.languages))
                continue
            }
            sections[sections.count - 1].blocks.append(block)
        }
        return sections.filter { $0.heading != nil || !$0.blocks.isEmpty }
    }

    private static let sidebarKinds: Set<SectionKind> = [.personal, .skills, .languages, .certifications]

    /// Whether a summary or an experience heading follows within four blocks.
    private static func startsProfile(after position: Int, in document: SourceDocument) -> Bool {
        document.blocks.dropFirst(position + 1).prefix(4).contains { block in
            guard block.cells.count == 1, let kind = SectionVocabulary.kind(ofHeading: document.text(of: block.span))?.kind else { return false }
            return kind == .summary || kind == .experience
        }
    }

    /// The section a block opens, if it is a heading: a heading of the vocabulary, alone in its block; or one the
    /// vocabulary does not know but the text marks as a heading.
    private static func heading(_ block: SourceBlock, in document: SourceDocument, isFirst: Bool) -> SectionVocabulary.Match? {
        guard block.kind != .listItem, block.kind != .tableHeader else { return nil }
        let cells = block.cells.map { document.text(of: $0) }
        let nonEmpty = cells.filter { !$0.isEmpty }
        guard nonEmpty.count == 1, let text = nonEmpty.first else { return nil }
        if text.words.count <= 7, let match = SectionVocabulary.kind(ofHeading: text) {
            return match
        }
        guard !isFirst, isMarkedAsHeading(block, text: text) else { return nil }
        // The name at the top of a chat answer, after its opening sentence
        if case .heading(1) = block.kind, HeaderReader.looksLikeName(text) { return nil }
        return SectionVocabulary.Match(kind: .unknown, languages: [])
    }

    /// A heading the vocabulary does not know: a Markdown heading of level 1 or 2 that is not the name at the top, or
    /// a short line in capitals that the PDF draws bold or large.
    private static func isMarkedAsHeading(_ block: SourceBlock, text: String) -> Bool {
        if case .heading(let level) = block.kind, level <= 2 { return true }
        let letters = text.filter(\.isLetter)
        let isCapitals = !letters.isEmpty && letters.allSatisfy(\.isUppercase)
        return block.isEmphasized && block.frame != nil && isCapitals && text.words.count <= 4 && !text.contains(where: \.isNumber)
            && DateReader.periods(in: text).isEmpty
    }

    // MARK: Language

    /// The language the CV is written in, from the vocabulary of its headings, and from its common words when the
    /// headings leave it open. Nil when nothing tells.
    static func language(of sections: [Section], in document: SourceDocument) -> CVLanguage? {
        var scores: [CVLanguage: Double] = [:]
        for section in sections where !section.languages.isEmpty {
            for language in section.languages { scores[language, default: 0] += 1 / Double(section.languages.count) }
        }
        var words: [CVLanguage: Double] = [:]
        for word in document.text.words.map({ $0.folded }) {
            for (language, common) in SectionVocabulary.commonWords where common.contains(word) { words[language, default: 0] += 1 }
        }
        let total = words.values.reduce(0, +)
        if total > 0 {
            for (language, count) in words { scores[language, default: 0] += count / total }
        }
        let ranked = scores.sorted { $0.value > $1.value }
        guard let best = ranked.first, best.value > 0 else { return nil }
        if ranked.count > 1, ranked[1].value == best.value { return nil }
        return best.key
    }
}
