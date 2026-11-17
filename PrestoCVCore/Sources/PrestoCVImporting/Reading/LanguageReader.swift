import PrestoCVDomain

/// Reads languages and their levels. A level is kept only when the text states a CEFR level or that the language is
/// native; any other words of a level are kept as words, with no level, and flagged (ADR 0027).
enum LanguageReader {

    static func read(_ section: Section, into findings: inout Findings) {
        // The language the block above created, when it created exactly one: a level on a line of its own is its level
        var above: Int?
        let firstLanguage = findings.cv.languages.count
        for (position, block) in section.blocks.enumerated() {
            let before = findings.cv.languages.count
            defer { above = findings.cv.languages.count == before + 1 ? before : nil }
            guard !findings.consumedBlocks.contains(block.index) else { continue }
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                continue
            }
            var cells = section.cells(of: block, in: findings.document)
            var nativeLabel: Piece?
            if let first = cells.first, SectionVocabulary.isLanguageLabel(first.text) {
                if isNative(first.text) { nativeLabel = first }
                cells.removeFirst()
            }
            if let nativeLabel, cells.isEmpty {
                // Alone on its line it is the level of the language above. Where no language can take it but one has been
                // read in the section, it is a statement left over, not a label of the row: shown, never dropped.
                if attachNative(nativeLabel, to: above, section: section, into: &findings) { continue }
                if findings.cv.languages.count > firstLanguage { findings.unplace(nativeLabel, in: section); continue }
            }
            let next = section.blocks.indices.contains(position + 1) ? section.blocks[position + 1] : nil
            let row = Row(nativeLabel: nativeLabel, above: above, levelFollows: isLevelOnly(next, in: section, findings: findings))
            read(items(of: cells), row: row, section: section, into: &findings)
        }
    }

    /// What a row knows of the rows around it.
    private struct Row {
        /// The row's label, when it says the languages are mother tongues: it is their level's evidence.
        let nativeLabel: Piece?
        /// The language the row above created, when it created exactly one.
        let above: Int?
        /// Whether the row below is a level and nothing else.
        let levelFollows: Bool
    }

    private static func items(of cells: [Piece]) -> [Piece] {
        cells.flatMap { $0.split(by: [", ", "; ", " • ", " · ", " | ", "\t"]) }
    }

    private static func isLevelOnly(_ block: SourceBlock?, in section: Section, findings: Findings) -> Bool {
        guard let block, block.kind != .tableHeader, !findings.consumedBlocks.contains(block.index) else { return false }
        let items = items(of: section.cells(of: block, in: findings.document))
        return items.count == 1 && LanguageEvidence.level(of: items[0]) != nil
    }

    /// The items of one row: a language starts at its name, and the items after it in the row give its level. An item
    /// with no language before it in the row is a level of the language of the rows before, as in a Europass grid.
    private static func read(_ items: [Piece], row: Row, section: Section, into findings: inout Findings) {
        var current: Int?
        var notes: [Int: [Piece]] = [:]
        defer { unplace(notes, section: section, into: &findings) }
        for (offset, item) in items.enumerated() {
            let levelNext = offset + 1 < items.count ? LanguageEvidence.level(of: items[offset + 1]) != nil : items.count == 1 && row.levelFollows
            if let start = start(ofLanguageIn: item, levelNext: levelNext) {
                var language = ImportedLanguage(name: start.name.quote(), heading: findings.heading(of: section))
                language.level = start.level ?? row.nativeLabel.map { Sourced(value: .native, spans: [$0.span], reading: .languageLevel) }
                findings.cv.languages.append(language)
                let index = findings.cv.languages.count - 1
                current = index
                describe(index, with: start.rest, nativeLabel: row.nativeLabel, notes: &notes, section: section, into: &findings)
            } else if let current {
                describe(current, with: [item], nativeLabel: row.nativeLabel, notes: &notes, section: section, into: &findings)
            } else if !attachLevel(item, above: row.above, section: section, into: &findings) {
                // A grid of levels, or the words of a level, under the language before it; otherwise text not imported
                findings.unplace(item, in: section)
            }
        }
    }

    /// Where a language starts in an item, by the first rule that fits: a name the lists know, a name beside a level in
    /// the item, or a name that is the whole item when a level is the next item or the next line.
    private static func start(ofLanguageIn item: Piece, levelNext: Bool) -> (name: Piece, level: Sourced<LanguageProficiency>?, rest: [Piece])? {
        if let name = languageName(in: item) { return (name, nil, item.removing([item.range(of: name.span)])) }
        if let (name, level) = LanguageEvidence.nameWithLevel(in: item) { return (name, level, []) }
        if levelNext, LanguageEvidence.isName(item) { return (item, nil, []) }
        return nil
    }

    /// Gives a language the level its parts state, or the words of one. A language has one level: what else a part says
    /// stays visible as text not imported, and so does a second level.
    private static func describe(
        _ index: Int, with parts: [Piece], nativeLabel: Piece?, notes: inout [Int: [Piece]], section: Section, into findings: inout Findings
    ) {
        for part in parts {
            let language = findings.cv.languages[index]
            if let (level, rest) = level(in: part) {
                // The row's label gives a language its level only until the language states one itself
                let isFromLabel = nativeLabel.map { language.level?.spans == [$0.span] } ?? false
                guard language.level == nil || isFromLabel else {
                    notes[index, default: []].append(part)
                    continue
                }
                if let words = language.levelWords { findings.unplace(words, in: section) }
                findings.cv.languages[index].level = level
                findings.cv.languages[index].levelWords = nil
                if !rest.isEmpty { notes[index, default: []].append(part) }
            } else if let words = levelWordsPiece(part), language.level == nil {
                addWords(words, to: index, into: &findings)
            } else {
                notes[index, default: []].append(part)
            }
        }
    }

    /// What the row of a language says besides its level, as text not imported with the language it is about: for each
    /// language one quote from its name to the end of its last note when they share a line, the notes alone otherwise.
    private static func unplace(_ notes: [Int: [Piece]], section: Section, into findings: inout Findings) {
        for index in notes.keys.sorted() {
            let parts = notes[index] ?? []
            guard let first = parts.first, let last = parts.last else { continue }
            unplace(parts, from: first.span.lowerBound, to: last.span.upperBound, ofLanguage: index, section: section, into: &findings)
        }
    }

    /// One note of a language of an earlier row, with its language when they share a line.
    private static func unplace(_ part: Piece, ofLanguage index: Int, section: Section, into findings: inout Findings) {
        unplace([part], from: part.span.lowerBound, to: part.span.upperBound, ofLanguage: index, section: section, into: &findings)
    }

    private static func unplace(
        _ parts: [Piece], from start: Int, to end: Int, ofLanguage index: Int, section: Section, into findings: inout Findings
    ) {
        if let name = findings.cv.languages[index].name.spans.first, name.lowerBound <= start {
            let span = SourceSpan(name.lowerBound, end)
            let text = findings.document.text(of: span)
            if !text.contains("\n") { return findings.unplace(Piece(text: text, span: span), in: section) }
        }
        for part in parts { findings.unplace(part, in: section) }
    }

    /// The words of a level, after the ones the language has.
    private static func addWords(_ words: Sourced<String>, to index: Int, into findings: inout Findings) {
        guard let existing = findings.cv.languages[index].levelWords else {
            findings.cv.languages[index].levelWords = words
            return
        }
        let check: CheckReason = existing.check == .levelsDiffer || words.check == .levelsDiffer ? .levelsDiffer : .levelNotCEFR
        findings.cv.languages[index].levelWords = Sourced(value: existing.value + "\n" + words.value, spans: existing.spans + words.spans, check: check)
    }

    // MARK: Names

    /// The first language a piece names, as written.
    static func languageName(in piece: Piece) -> Piece? {
        piece.text.words.first { LanguageVocabulary.isName(String($0)) }.map { piece.sub($0.startIndex..<$0.endIndex) }
    }

    // MARK: Levels

    /// A CEFR level, or the words of a native language, in a piece, and the rest of the piece. Different CEFR levels
    /// give none.
    private static func level(in piece: Piece) -> (level: Sourced<LanguageProficiency>, rest: [Piece])? {
        if isNative(piece.text) {
            return (Sourced(value: .native, spans: [piece.span], reading: .languageLevel), [])
        }
        let levels = cefrLevels(in: piece)
        guard let first = levels.first, levels.allSatisfy({ $0.1 == first.1 }) else { return nil }
        return (Sourced(value: first.1, spans: levels.map(\.0.span), reading: .languageLevel), piece.removing(levels.map { piece.range(of: $0.0.span) }))
    }

    /// Every CEFR level a piece states, with where.
    static func cefrLevels(in piece: Piece) -> [(Piece, LanguageProficiency)] {
        var found: [(Piece, LanguageProficiency)] = []
        let text = piece.text
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if next < text.endIndex, "ABCabc".contains(text[index]), "12".contains(text[next]) {
                let before = index == text.startIndex ? nil : text[text.index(before: index)]
                let afterIndex = text.index(after: next)
                let after = afterIndex == text.endIndex ? nil : text[afterIndex]
                if !(before?.isLetter ?? false) && !(before?.isNumber ?? false) && !(after?.isLetter ?? false) && !(after?.isNumber ?? false),
                   let level = LanguageProficiency(rawValue: text[index...next].lowercased()) {
                    found.append((piece.sub(index..<afterIndex), level))
                }
            }
            index = next
        }
        return found
    }

    static func isNative(_ text: String) -> Bool {
        let key = SectionVocabulary.key(text)
        return LanguageVocabulary.nativeKeys.contains { key == $0 || key.hasPrefix($0 + " ") || key.hasSuffix(" " + $0) || key.contains(" " + $0 + " ") }
    }

    /// The words of a level that are no CEFR level, as written, flagged for the review.
    private static func levelWordsPiece(_ piece: Piece) -> Sourced<String>? {
        let key = SectionVocabulary.key(piece.text)
        guard !key.isEmpty, piece.words.count <= 6 else { return nil }
        let isLevel = LanguageVocabulary.levelKeys.contains { key == $0 || key.hasPrefix($0 + " ") || key.hasSuffix(" " + $0) }
            || SkillLevelWords.isLevel(piece.text)
        return isLevel ? piece.quote(check: .levelNotCEFR) : nil
    }

    /// A piece of levels under a language that has none yet: a Europass grid ("B2 B2 B1 B1 B2"), or the words of a
    /// level on a line of their own.
    private static func attachLevel(_ piece: Piece, above: Int?, section: Section, into findings: inout Findings) -> Bool {
        if LanguageVocabulary.isNativeStatement(piece.text) { return attachNative(piece, to: above, section: section, into: &findings) }
        guard let last = findings.cv.languages.indices.last, findings.cv.languages[last].level == nil else { return false }
        let levels = cefrLevels(in: piece)
        if !levels.isEmpty {
            let rest = piece.removing(levels.map { piece.range(of: $0.0.span) })
            guard rest.allSatisfy({ levelWordsPiece($0) != nil }) else { return false }
            if levels.allSatisfy({ $0.1 == levels[0].1 }) {
                if let words = findings.cv.languages[last].levelWords { findings.unplace(words, in: section) }
                findings.cv.languages[last].level = Sourced(value: levels[0].1, spans: levels.map(\.0.span), reading: .languageLevel)
                findings.cv.languages[last].levelWords = nil
                if !rest.isEmpty { unplace(piece, ofLanguage: last, section: section, into: &findings) }
            } else {
                addWords(piece.quote(check: .levelsDiffer), to: last, into: &findings)
            }
            return true
        }
        if let words = levelWordsPiece(piece) {
            addWords(words, to: last, into: &findings)
            return true
        }
        return false
    }

    /// A native speaker's statement on a line of its own, under the one language the line above gave. It states the
    /// level of that language only when the language has none from a CEFR level: the place is the evidence, so a
    /// statement further away stays visible as text not imported. Words the language had for its level give way to it.
    private static func attachNative(_ piece: Piece, to above: Int?, section: Section, into findings: inout Findings) -> Bool {
        guard let above, findings.cv.languages[above].level == nil else { return false }
        if let words = findings.cv.languages[above].levelWords { findings.unplace(words, in: section) }
        findings.cv.languages[above].level = Sourced(value: .native, spans: [piece.span], reading: .languageLevel)
        findings.cv.languages[above].levelWords = nil
        return true
    }
}
