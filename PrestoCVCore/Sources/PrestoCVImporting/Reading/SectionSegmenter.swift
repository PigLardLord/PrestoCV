// MARK: - Sections

/// A section of the CV: its heading, if any, and its blocks in reading order.
struct Section: Equatable {
    var kind: SectionKind
    var heading: SourceBlock?
    var blocks: [SourceBlock]
    /// The languages whose vocabulary the heading is from.
    var languages: Set<CVLanguage>
    /// The heading is one of the first level in the shape of a name that closed the head: it could have been the name
    /// (#301), so the name the head gives is to be checked.
    var headingCouldBeTheName = false
    /// The indices of the blocks that may be a heading the vocabulary does not know, left in the section (#454): the
    /// entry that takes one is to be checked.
    var doubtfulHeadings: Set<Int> = []

    /// The kinds the heading joins ("Education & Certifications"), when it joins two or more; empty otherwise.
    var parts: Set<SectionKind> = []

    /// What the heading is in the text: its block, or, when a row of cells opens the section, its first cell.
    var headingSpan: SourceSpan? {
        guard let heading else { return nil }
        return heading.cells.count > 1 && blocks.first?.index == heading.index ? heading.cells[0] : heading.span
    }

    /// The heading as the CV writes it, without the values a heading row also holds; nil when the section has none.
    func headingText(in document: SourceDocument) -> String? {
        headingSpan.map { document.text(of: $0) }
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

    /// - Throws: `LimitReached` with its steps when looking again at the head for each heading that could be the name
    ///   would pass the budget of `work`, and `CancellationError` once the task is cancelled.
    static func sections(of document: SourceDocument, work: inout AnalysisWork) throws -> [Section] {
        var sections: [Section] = [Section(kind: .header, heading: nil, blocks: [], languages: [])]
        var column = document.blocks.first?.column
        var readings = HeaderReader.HeadReadings()
        let look = try HeadingLook(of: document, work: &work)
        for (position, block) in document.blocks.enumerated() {
            // A second column starts with its own head: a sidebar that opens with the contacts
            if block.column != column {
                column = block.column
                sections.append(Section(kind: .header, heading: nil, blocks: [], languages: []))
            }
            let firstCell = document.text(ofCell: 0, in: block)
            // LinkedIn's PDF copied as text gives its sidebar first: the profile starts at the name, a few lines before
            // its summary or experience. The name is told by its shape, whatever its words: the head weighs it (#301).
            // A heading of the first level, after a name of the head that its contacts follow, opens a section instead,
            // as in the head ("Anna Weber / ## Contact / person@example.com / # University Projects / ## Experience")
            if sidebarKinds.contains(sections[sections.count - 1].kind), block.cells.count == 1, HeaderReader.hasNameShape(firstCell),
               startsProfile(after: position, in: document) {
                if case .heading(1) = block.kind,
                   try contactsAfterAName(
                    in: sections.filter { headKinds.contains($0.kind) }, column: block.column, document: document, readings: &readings, work: &work
                   ) {
                    sections.append(Section(kind: .unknown, heading: block, blocks: [], languages: [], headingCouldBeTheName: true))
                } else {
                    sections.append(Section(kind: .header, heading: nil, blocks: [block], languages: []))
                }
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
               let match = SectionVocabulary.kind(ofHeading: firstCell), firstCell.words.count <= SectionVocabulary.maximumWords {
                // A heading in the first cell of a row, its section's first value in the others
                sections.append(Section(kind: match.kind, heading: block, blocks: [block], languages: match.languages, parts: match.parts))
                continue
            }
            if let opening = try heading(
                block, in: document, isFirst: sections.count == 1 && sections[0].blocks.isEmpty,
                headIn: headKinds.contains(sections[sections.count - 1].kind) ? sections : nil, readings: &readings, work: &work
            ) {
                sections.append(Section(
                    kind: opening.match.kind, heading: block, blocks: [], languages: opening.match.languages,
                    headingCouldBeTheName: opening.couldBeTheName, parts: opening.match.parts
                ))
                continue
            }
            // A heading the vocabulary does not know, drawn as the ones it knows: its lines stay visible (#454). One that
            // may as well be the employer of a job stays in the jobs and the studies, where its entry is to be checked; one
            // with a word of an entry opens nothing elsewhere either, as no other section reads roles or employers (#466)
            let current = sections[sections.count - 1]
            if !headKinds.contains(current.kind) {
                switch try look.reading(block, at: position, after: current, in: document, work: &work) {
                case .heading:
                    sections.append(Section(kind: .unknown, heading: block, blocks: [], languages: []))
                    continue
                case .doubtful where entryKinds.contains(current.kind), .wordOfAnEntry where entryKinds.contains(current.kind):
                    sections[sections.count - 1].doubtfulHeadings.insert(block.index)
                case .doubtful:
                    sections.append(Section(kind: .unknown, heading: block, blocks: [], languages: []))
                    continue
                case .wordOfAnEntry, .partOfTheSection:
                    break
                }
            }
            sections[sections.count - 1].blocks.append(block)
        }
        return sections.filter { $0.heading != nil || !$0.blocks.isEmpty }
    }

    private static let sidebarKinds: Set<SectionKind> = [.personal, .skills, .languages, .certifications]

    /// The sections the head of the CV is read from.
    private static let headKinds: Set<SectionKind> = [.header, .personal]

    /// The sections read as entries with an employer or a school, where a line in capitals may be either.
    private static let entryKinds: Set<SectionKind> = [.experience, .education]

    /// Whether the contacts of the head follow a name, read from the head's `sections`: the head is read again for each
    /// heading of the first level that has the shape of a name, which the head grows by when it is no section's. A block of
    /// the head is read once (`readings`), and each look at the head counts a few steps for each of its blocks, whatever
    /// they are (R8).
    private static func contactsAfterAName(
        in headSections: [Section], column: Int?, document: SourceDocument,
        readings: inout HeaderReader.HeadReadings, work: inout AnalysisWork
    ) throws -> Bool {
        try work.count(headSections.count)
        let head = headSections.flatMap(\.blocks).filter { $0.column == column }
        return try follows(head, in: document, readings: &readings, work: &work)
    }

    private static func follows(
        _ head: [SourceBlock], in document: SourceDocument, readings: inout HeaderReader.HeadReadings, work: inout AnalysisWork
    ) throws -> Bool {
        try work.count(head.count * HeaderReader.HeadReadings.stepsToLook)
        try readings.read(head, in: document, work: &work)
        return HeaderReader.contactsAfterAName(head, in: document, readings: &readings) != nil
    }

    /// The blocks of the head that a block of `column` closes, in order: the head's sections at the end, in that column.
    private static func headBlocks(of sections: [Section], in column: Int?) -> [SourceBlock] {
        let head = sections.reversed().prefix { headKinds.contains($0.kind) }.reversed()
        return head.flatMap(\.blocks).filter { $0.column == column }
    }

    /// Whether a summary or an experience heading follows within four blocks.
    private static func startsProfile(after position: Int, in document: SourceDocument) -> Bool {
        document.blocks.dropFirst(position + 1).prefix(4).contains { block in
            guard block.cells.count == 1, let kind = SectionVocabulary.kind(ofHeading: document.text(of: block.span))?.kind else { return false }
            return kind == .summary || kind == .experience
        }
    }

    /// The section a block opens, if it is a heading: a heading of the vocabulary, alone in its block; or one the
    /// vocabulary does not know but the text marks as a heading. In the head, given as the sections so far when the
    /// block comes in it, a heading of the first level with the shape of a name is the name, whatever its words
    /// ("# Thomas Kiel" after the contacts), unless the head already holds a line in the shape of a name that its
    /// contacts follow: the shape tells a name from a heading no better than the words, so the heading then opens a
    /// section ("Anna Weber / person@example.com / # University Projects", #301). Such a heading could still have been
    /// the name ("Greater Wexby / person@example.com / # Anna Weber"), and the section says so. After the head it is a
    /// heading.
    private static func heading(
        _ block: SourceBlock, in document: SourceDocument, isFirst: Bool, headIn sections: [Section]?,
        readings: inout HeaderReader.HeadReadings, work: inout AnalysisWork
    ) throws -> (match: SectionVocabulary.Match, couldBeTheName: Bool)? {
        guard block.kind != .listItem, block.kind != .tableHeader else { return nil }
        let cells = block.cells.map { document.text(of: $0) }
        let nonEmpty = cells.filter { !$0.isEmpty }
        guard nonEmpty.count == 1, let text = nonEmpty.first else { return nil }
        if text.words.count <= SectionVocabulary.maximumWords, let match = SectionVocabulary.kind(ofHeading: text) {
            return (match, false)
        }
        guard !isFirst, isMarkedAsHeading(block, text: text) else { return nil }
        // The name at the top of a chat answer, after its opening sentence, the contacts or the document's title
        var couldBeTheName = false
        if case .heading(1) = block.kind, let sections, HeaderReader.hasNameShape(text) {
            // The head is gathered and read again only here, for a heading that could be the name
            let head = headBlocks(of: sections, in: block.column)
            guard try follows(head, in: document, readings: &readings, work: &work) else { return nil }
            couldBeTheName = true
        }
        return (SectionVocabulary.Match(kind: .unknown, languages: []), couldBeTheName)
    }

    /// A heading the vocabulary does not know: a Markdown heading of level 1 or 2 that is not the name at the top, or
    /// a short line in capitals that the PDF draws bold or large.
    private static func isMarkedAsHeading(_ block: SourceBlock, text: String) -> Bool {
        if case .heading(let level) = block.kind, level <= 2 { return true }
        return block.isEmphasized && block.frame != nil && HeadingLook.isCapitals(text) && text.words.count <= 4
            && !text.contains(where: \.isNumber)
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
