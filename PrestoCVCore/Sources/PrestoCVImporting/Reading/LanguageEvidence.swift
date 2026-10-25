import PrestoCVDomain

// MARK: - Where a language and its level stand

/// What a line of the languages shows by where its parts stand, besides the names the lists know (ADR 0027, #303): a
/// name beside a statement of a level is a language, whatever the name, and a level on its own is the level of the
/// language it stands under. The lists only exclude the labels that are no language; the position decides.
enum LanguageEvidence {

    /// A level on its own: one CEFR level, or the words of a native speaker, and nothing else.
    static func level(of piece: Piece) -> Sourced<LanguageProficiency>? {
        let piece = piece.trimmed()
        if LanguageVocabulary.isNativeStatement(piece.text) {
            return Sourced(value: .native, spans: [piece.span], reading: .languageLevel)
        }
        let levels = LanguageReader.cefrLevels(in: piece)
        guard levels.count == 1, levels[0].0.span == piece.span else { return nil }
        return Sourced(value: levels[0].1, spans: [piece.span], reading: .languageLevel)
    }

    /// A name and a level in one item, in either order, set apart by a separator or a bracket: "Quechua: C1",
    /// "Wolof (B2)", "C1 – Quechua", "Tigrinya – Native". Anything else beside them, or a name that is a label, gives none.
    static func nameWithLevel(in item: Piece) -> (name: Piece, level: Sourced<LanguageProficiency>)? {
        let parts = segments(of: item)
        guard parts.count == 2 else { return nil }
        if let level = level(of: parts[1]), isName(parts[0]) { return (parts[0], level) }
        if let level = level(of: parts[0]), isName(parts[1]) { return (parts[1], level) }
        return nil
    }

    /// Whether a piece has the shape of the name of a language: one or two words of letters, each starting in capitals,
    /// none of them the word of a label or of a level. The shape is no evidence alone: a level beside it is.
    static func isName(_ piece: Piece) -> Bool {
        let words = piece.words
        guard (1...2).contains(words.count), !SkillLevelWords.isLevel(piece.text) else { return false }
        guard piece.text.allSatisfy({ $0.isLetter || " -'’".contains($0) }) else { return false }
        return words.allSatisfy { word in
            (word.first?.isUppercase ?? false) && word.count > 1 && !LanguageVocabulary.isLabelWord(String(word))
        }
    }

    // MARK: Segments

    /// The parts of an item between a colon, a slash, a dash or a bracket, trimmed, without the empty ones. A hyphen
    /// inside a word is no break: "Serbo-Croatian" is one part.
    private static func segments(of item: Piece) -> [Piece] {
        let text = item.text
        var parts: [Piece] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            if isBreak(at: index, in: text) {
                parts.append(item.sub(start..<index))
                start = text.index(after: index)
            }
            index = text.index(after: index)
        }
        parts.append(item.sub(start..<text.endIndex))
        return parts.map { $0.trimmed() }.filter { !$0.isEmpty }
    }

    private static func isBreak(at index: String.Index, in text: String) -> Bool {
        let character = text[index]
        if ":/–—()[]".contains(character) { return true }
        guard character == "-" else { return false }
        let before = index == text.startIndex ? nil : text[text.index(before: index)]
        let afterIndex = text.index(after: index)
        let after = afterIndex == text.endIndex ? nil : text[afterIndex]
        return (before?.isWhitespace ?? true) && (after?.isWhitespace ?? true)
    }
}
