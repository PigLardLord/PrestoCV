/// Reads the sections that are lists: skills and interests. A group's label is left out as structure; prose and a
/// level in words stay visible as text not imported, never turned into a value of their own.
enum ListReader {

    static func readSkills(_ section: Section, into findings: inout Findings) {
        for item in items(of: section, into: &findings) {
            if SkillLevelWords.isLevel(item.text) || item.text.allSatisfy({ Piece.isIcon($0) || $0 == " " }) {
                if !item.text.allSatisfy({ Piece.isIcon($0) || $0 == " " }) { findings.unplace(item, in: section) }
            } else if item.words.count <= maxSkillWords {
                findings.cv.skills.append(item.quote())
            } else {
                findings.unplace(item, in: section)
            }
        }
    }

    static func readInterests(_ section: Section, into findings: inout Findings) {
        for item in items(of: section, into: &findings) {
            if item.words.count <= 12 {
                findings.cv.interests.append(item.quote())
            } else {
                findings.unplace(item, in: section)
            }
        }
    }

    /// The items of a list section: its cells split at commas, semicolons and bullets, without a group's label.
    private static func items(of section: Section, into findings: inout Findings) -> [Piece] {
        var items: [Piece] = []
        for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                continue
            }
            var cells = section.cells(of: block, in: findings.document)
            // A row's first cell that labels a group of skills: "Fachlich:", or a short label before a list
            if cells.count >= 2, let first = cells.first,
               first.text.hasSuffix(":") || (first.words.count <= 3 && cells[1].text.contains(",")) {
                findings.leaveOut(first, .categoryLabel)
                cells.removeFirst()
            }
            for cell in cells {
                var content = cell
                if let colon = cell.text.firstIndex(of: ":") {
                    let label = cell.sub(cell.text.startIndex..<colon).trimmed()
                    let rest = cell.sub(cell.text.index(after: colon)..<cell.text.endIndex).trimmed()
                    if !label.isEmpty, label.words.count <= 4, !rest.isEmpty {
                        findings.leaveOut(label, .categoryLabel)
                        content = rest
                    }
                }
                items += listItems(of: content, languages: section.languages)
            }
        }
        return items
    }

    /// The items of one cell. Prose is one item, whatever commas it has. In a list of commas, a last item that
    /// starts with a lowercase joining word of the heading's languages loses it ("A, B, and C"); every other item is
    /// kept as written, so an "e commerce" under an English heading stays a name.
    private static func listItems(of content: Piece, languages: Set<CVLanguage>) -> [Piece] {
        let commas = content.text.filter { $0 == "," }.count
        if content.words.count > 12 && !content.text.contains(";") && commas < 3 { return [content] }
        let parts = content.split(by: separators)
        guard parts.count >= 3, !hasOtherSeparator(content) else {
            return isSentence(content, parts: parts) ? [content] : parts
        }
        let items = Array(parts.dropLast()) + [withoutJoiningWord(parts[parts.count - 1], languages: languages)]
        return isSentence(content, parts: items) ? [content] : items
    }

    /// A sentence ends with a full stop (not the dots of a list cut short), is longer than any skill and has an item of
    /// three words or more that starts with a subject ("I led teams"): cut at its commas it would give wrong values.
    /// Length alone proves nothing, and a preposition inside a phrase ("gestione dei progetti") is a noun phrase, so a
    /// list of those stays a list.
    private static func isSentence(_ content: Piece, parts: [Piece]) -> Bool {
        content.text.hasSuffix(".") && !content.text.hasSuffix("..") && content.words.count > maxSkillWords
            && parts.contains { $0.words.count >= 3 && EntryVocabulary.startsWithSubject($0.text, capitalisedNextIsAName: parts.count >= 3) }
    }

    private static func hasOtherSeparator(_ content: Piece) -> Bool {
        separators.dropFirst(2).contains { content.text.contains($0) }
    }

    private static func withoutJoiningWord(_ item: Piece, languages: Set<CVLanguage>) -> Piece {
        guard let space = item.text.firstIndex(of: " "),
              languages.contains(where: { joiningWords[$0] == String(item.text[..<space]) }) else { return item }
        let rest = item.sub(item.text.index(after: space)..<item.text.endIndex).trimmed()
        return rest.text.isEmpty || isElectronicTerm(prefix: item.text[..<space], rest: rest.text) ? item : rest
    }

    /// A one-letter "e" followed by a word that names an electronic service ("e commerce", "e learning", "e mail")
    /// is the prefix of a term written with a space, not a joining word.
    private static func isElectronicTerm(prefix: Substring, rest: String) -> Bool {
        guard prefix.count == 1 else { return false }
        let first = rest.split(separator: " ").first.map { $0.lowercased() } ?? ""
        return electronicWords.contains(first)
    }

    private static let electronicWords: Set<String> = [
        "commerce", "learning", "mail", "business", "government", "health", "banking", "procurement",
        "invoicing", "payment", "payments", "signature", "trading", "shopping", "billing", "marketplace",
        "book", "books", "sports", "voting", "democracy", "participation", "tendering",
    ]

    private static let separators = [", ", ",", "; ", ";", " • ", "•", " · ", "·", " | ", "|", " / ", "\t"]
    /// The word that joins the last item of a list, by language: a one-letter one is also the first word of a name in
    /// another language ("e commerce"), so it counts only under a heading of its own language.
    private static let joiningWords: [CVLanguage: String] = [
        .en: "and", .de: "und", .it: "e", .pt: "e", .es: "y", .fr: "et",
    ]
    private static let maxSkillWords = 6
}

/// The words of a skill's level, which the import never turns into stars.
enum SkillLevelWords {
    static func isLevel(_ text: String) -> Bool {
        words.contains(SectionVocabulary.key(text))
    }

    private static let words: Set<String> = Set([
        "beginner", "basic", "elementary", "intermediate", "advanced", "expert", "proficient", "good", "very good", "excellent",
        "base", "di base", "elementare", "intermedio", "buono", "ottimo", "avanzato", "esperto", "eccellente", "discreto",
        "grundkenntnisse", "gut", "sehr gut", "fortgeschritten", "experte", "expertin", "vertieft", "fundiert",
        "básico", "intermedio", "avanzado", "experto", "bueno", "muy bueno", "alto", "medio", "bajo",
        "débutant", "intermédiaire", "avancé", "expert", "bon", "très bon", "notions", "courant",
        "básico", "intermédio", "intermediário", "avançado", "especialista", "bom", "muito bom",
    ].map(SectionVocabulary.key))
}
