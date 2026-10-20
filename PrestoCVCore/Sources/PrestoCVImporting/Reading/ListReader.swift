/// Reads the sections that are lists: skills and interests. A group's label is left out as structure; prose and a
/// level in words stay visible as text not imported, never turned into a value of their own.
enum ListReader {

    static func readSkills(_ section: Section, into findings: inout Findings) {
        for item in items(of: section, into: &findings) {
            if SkillLevelWords.isLevel(item.text) || item.text.allSatisfy({ Piece.isIcon($0) || $0 == " " }) {
                if !item.text.allSatisfy({ Piece.isIcon($0) || $0 == " " }) { findings.unplace(item, in: section) }
            } else if item.words.count <= 6 {
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
                // Prose is one item, whatever commas it has
                if content.words.count > 12 && !content.text.contains(";") && content.text.filter({ $0 == "," }).count < 3 {
                    items.append(content)
                    continue
                }
                items += content.split(by: [", ", ",", "; ", ";", " • ", "•", " · ", "·", " | ", "|", " / ", "\t"])
            }
        }
        return items
    }
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
