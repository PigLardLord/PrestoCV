// MARK: - Normalisation of one line

/// A line after the closed rules of normalisation (ADR 0027): characters, then the markup of chat assistants and of
/// plain text. What it removes is markup or invisible; what it keeps is the source's text.
struct NormalizedLine: Equatable {
    enum LineEnd: Equatable {
        case plain
        /// A soft hyphen, removed from the text: the word goes on with nothing to take away.
        case softHyphen
        /// A visible hyphen, kept in the text until the next line shows whether it only broke the word.
        case hyphen
    }

    enum Markup: Equatable {
        case none
        case heading(level: Int)
        case listItem
        /// A horizontal rule: `---`, `***`, `___`.
        case rule
        /// The line under the labels of a Markdown table: `|---|:--:|`.
        case tableSeparator
    }

    var cells: [String]
    var markup: Markup
    /// The whole line was bold (`**…**` or `__…__`).
    var isBold: Bool
    /// How the line ends: a word may go on in the next line after a hyphen right after a letter.
    var lineEnd: LineEnd
    /// The cells were written between a Markdown table's bars, not set apart by tabs or by a wide gap.
    var isTableRow = false

    var text: String { cells.joined(separator: "\t") }
    var isEmpty: Bool { cells.allSatisfy(\.isEmpty) }
}

enum LineNormalizer {
    /// Normalises a line of pasted text, or one cell of a PDF's line, into its cells and markup.
    /// - Parameter splitsColumns: Tabs and runs of three spaces or more separate cells, as in text pasted from a table.
    static func normalize(_ raw: String, splitsColumns: Bool = true) -> NormalizedLine {
        let cleaned = cleanCharacters(raw)
        var line = Substring(cleaned.text).trimmingSpaces()
        var markup = NormalizedLine.Markup.none

        if isRule(line) {
            return NormalizedLine(cells: [], markup: .rule, isBold: false, lineEnd: .plain)
        }
        if let cells = tableCells(line) {
            if cells.allSatisfy(isTableSeparatorCell) {
                return NormalizedLine(cells: [], markup: .tableSeparator, isBold: false, lineEnd: .plain)
            }
            let inline = cells.map { stripInlineMarkup(Substring($0)).trimmingSpaces() }
            return NormalizedLine(
                cells: inline.map(collapsingSpaces), markup: .none, isBold: false, lineEnd: .plain, isTableRow: true
            )
        }
        // A quote's marker is followed by a space; ">5 years" is the person's text
        while line.hasPrefix(">"), line.dropFirst().first.map({ $0 == " " || $0 == ">" }) ?? true {
            line = line.dropFirst().trimmingSpaces()
        }
        if let (level, rest) = headingMarker(line) {
            markup = .heading(level: level)
            line = rest
        } else if let rest = listMarker(line, bulletGlyph: cleaned.leadingBulletGlyph) {
            markup = .listItem
            line = rest
        }
        let isBold = isWhollyBold(line)
        let text = stripInlineMarkup(line)
        let cells = splitsColumns ? columnCells(text) : [text]
        let lineEnd: NormalizedLine.LineEnd = cleaned.endsWithSoftHyphen ? .softHyphen : endsWithWordHyphen(text) ? .hyphen : .plain
        return NormalizedLine(
            cells: cells.map { collapsingSpaces($0.trimmingSpaces()) }.filter { !$0.isEmpty },
            markup: markup,
            isBold: isBold,
            lineEnd: lineEnd
        )
    }

    // MARK: Characters

    private struct CleanedText {
        var text: String
        var leadingBulletGlyph: Bool
        var endsWithSoftHyphen: Bool
    }

    /// Ligatures become their letters; soft hyphens, zero-width characters, controls and the glyphs of icon fonts (the
    /// private-use area) go; every kind of space becomes a space. A bullet drawn with a symbol font's private glyph,
    /// as Word's, is kept as the fact that the line is a list item.
    private static func cleanCharacters(_ raw: String) -> CleanedText {
        var out = String.UnicodeScalarView()
        var leadingBullet = false
        var seenText = false
        let scalars = Array(raw.unicodeScalars)
        var endsWithSoftHyphen = false
        for (index, scalar) in scalars.enumerated() {
            if let letters = ligatures[scalar.value] {
                out.append(contentsOf: letters.unicodeScalars)
                seenText = true
                continue
            }
            switch scalar.value {
            case 0x00AD:
                // A soft hyphen at the end of the line marks a word broken across lines
                if scalars[(index + 1)...].allSatisfy({ $0.properties.isWhitespace }) { endsWithSoftHyphen = true }
                continue
            case 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0xFE0E, 0xFE0F:
                continue
            case 0x09:
                out.append(scalar)
                continue
            default:
                break
            }
            if isPrivateUse(scalar) {
                if !seenText && symbolFontBullets.contains(scalar.value) { leadingBullet = true }
                continue
            }
            let category = scalar.properties.generalCategory
            if category == .control || category == .format || category == .lineSeparator || category == .paragraphSeparator {
                continue
            }
            if category == .spaceSeparator {
                out.append(" ")
                continue
            }
            if !scalar.properties.isWhitespace { seenText = true }
            out.append(scalar)
        }
        return CleanedText(text: String(out), leadingBulletGlyph: leadingBullet, endsWithSoftHyphen: endsWithSoftHyphen)
    }

    private static let ligatures: [UInt32: String] = [
        0xFB00: "ff", 0xFB01: "fi", 0xFB02: "fl", 0xFB03: "ffi", 0xFB04: "ffl", 0xFB05: "st", 0xFB06: "st",
    ]

    /// The bullets of Word's Symbol and Wingdings fonts, which reach the clipboard as private-use characters.
    private static let symbolFontBullets: Set<UInt32> = [0xF0B7, 0xF0A7, 0xF076, 0xF0D8, 0xF0FC, 0xF0A8, 0xF06E, 0xF0E8]

    private static func isPrivateUse(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0xE000...0xF8FF).contains(v) || (0xF0000...0xFFFFD).contains(v) || (0x100000...0x10FFFD).contains(v)
    }

    // MARK: Markup

    private static func isRule(_ line: Substring) -> Bool {
        let marks = line.filter { $0 != " " }
        guard marks.count >= 3, let first = marks.first, "-*_=~—–".contains(first) else { return false }
        return marks.allSatisfy { $0 == first }
    }

    /// The cells of a Markdown table's row: `| a | b |`.
    private static func tableCells(_ line: Substring) -> [String]? {
        guard line.hasPrefix("|"), line.filter({ $0 == "|" }).count >= 2 else { return nil }
        var body = line.dropFirst()
        if body.hasSuffix("|") { body = body.dropLast() }
        return body.split(separator: "|", omittingEmptySubsequences: false).map { String($0.trimmingSpaces()) }
    }

    private static func isTableSeparatorCell(_ cell: String) -> Bool {
        let dashes = cell.filter { $0 != ":" && $0 != " " }
        return !dashes.isEmpty && dashes.allSatisfy { $0 == "-" }
    }

    private static func headingMarker(_ line: Substring) -> (Int, Substring)? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard let first = rest.first, first == " " else { return nil }
        // A closing run of hashes after a space is part of the markup too; one that ends a word is the word's, as in C#
        let text = rest.trimmingSpaces()
        let closing = text.reversed().prefix { $0 == "#" }.count
        let beforeClosing = text.dropLast(closing)
        guard closing > 0, beforeClosing.isEmpty || beforeClosing.last == " " else { return (hashes.count, text) }
        return (hashes.count, beforeClosing.trimmingSpaces())
    }

    /// The text of a list item without its marker: `- `, `* `, `• `, `1. `, Word's `o` followed by a tab, and the like.
    private static func listMarker(_ line: Substring, bulletGlyph: Bool) -> Substring? {
        if bulletGlyph { return line.trimmingSpaces() }
        guard let first = line.first else { return nil }
        let rest = line.dropFirst()
        if bulletCharacters.contains(first), let next = rest.first, next == " " || next == "\t" {
            return rest.trimmingSpaces()
        }
        // Word's second-level bullet: a letter o followed by a tab
        if first == "o", rest.first == "\t" { return rest.trimmingSpaces() }
        // A numbered item: 1. or 1), unless the number is the day or the month of a date, as in "1. April 2020"
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        if (1...2).contains(digits.count) {
            let afterDigits = line.dropFirst(digits.count)
            if let mark = afterDigits.first, mark == "." || mark == ")", afterDigits.dropFirst().first == " " {
                let rest = afterDigits.dropFirst().trimmingSpaces()
                let text = String(rest)
                if DateReader.periods(in: text).first?.range.lowerBound != text.startIndex { return rest }
            }
        }
        return nil
    }

    private static let bulletCharacters: Set<Character> = [
        "-", "*", "+", "•", "·", "▪", "▫", "◦", "‣", "⁃", "●", "○", "■", "□", "►", "▶", "➢", "➤", "✓", "✔", "→", "–", "—", "∙", "⦁",
    ]

    private static func isWhollyBold(_ line: Substring) -> Bool {
        for mark in ["**", "__"] where line.hasPrefix(mark) && line.hasSuffix(mark) && line.count > 2 * mark.count {
            return !line.dropFirst(2).dropLast(2).contains(mark)
        }
        return false
    }

    /// Removes the inline markup of Markdown: emphasis, code, links written `[text](address)`, and escapes. The text
    /// stays as it is written.
    static func stripInlineMarkup(_ line: Substring) -> String {
        var text = replacingLinks(String(line))
        for mark in ["**", "__", "`"] { text = removingPairs(of: mark, in: text) }
        text = removingEmphasis(marked: "*", in: text)
        text = removingEmphasis(marked: "_", in: text)
        return removingEscapes(in: text)
    }

    /// `[text](address)` becomes "text address", or "address" when the text is the address.
    private static func replacingLinks(_ text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "[") {
            guard let close = rest[open...].firstIndex(of: "]"),
                  rest.index(after: close) < rest.endIndex, rest[rest.index(after: close)] == "(",
                  let end = rest[close...].firstIndex(of: ")") else { break }
            let label = rest[rest.index(after: open)..<close]
            let address = rest[rest.index(close, offsetBy: 2)..<end]
            result += rest[..<open]
            result += label == address || label.isEmpty ? address : label + " " + address
            rest = rest[rest.index(after: end)...]
        }
        return result + rest
    }

    /// Removes a mark that opens before text and closes after it on the same line, such as `**bold**`.
    private static func removingPairs(of mark: String, in text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let open = rest.firstRange(of: mark) {
            let afterOpen = rest[open.upperBound...]
            guard let first = afterOpen.first, first != " ",
                  let close = afterOpen.firstRange(of: mark), close.lowerBound > afterOpen.startIndex,
                  afterOpen[afterOpen.index(before: close.lowerBound)] != " " else {
                result += rest[..<open.upperBound]
                rest = afterOpen
                continue
            }
            result += rest[..<open.lowerBound]
            result += afterOpen[..<close.lowerBound]
            rest = afterOpen[close.upperBound...]
        }
        return result + rest
    }

    /// `_emphasis_` or `*emphasis*` between word boundaries; a mark inside a word, an address or a rating ("4*") stays.
    private static func removingEmphasis(marked mark: Character, in text: String) -> String {
        let characters = Array(text)
        var drop = Set<Int>()
        var index = 0
        while index < characters.count {
            if characters[index] == mark, index == 0 || !isWordCharacter(characters[index - 1]),
               index + 1 < characters.count, characters[index + 1] != " " {
                var end = index + 1
                while end < characters.count, characters[end] != mark { end += 1 }
                if end < characters.count, characters[end - 1] != " ",
                   end + 1 == characters.count || !(characters[end + 1].isLetter || characters[end + 1].isNumber) {
                    drop.insert(index)
                    drop.insert(end)
                    index = end
                }
            }
            index += 1
        }
        return String(characters.enumerated().filter { !drop.contains($0.offset) }.map(\.element))
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "@" || character == "." || character == "/"
    }

    /// A backslash escapes only ASCII punctuation, as in Markdown; before anything else it is the person's text.
    private static func removingEscapes(in text: String) -> String {
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                if !(character.isASCII && (character.isPunctuation || character.isSymbol)) { result.append("\\") }
                result.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        if escaping { result.append("\\") }
        return result
    }

    // MARK: Cells

    /// Tabs, and runs of three spaces or more, separate the cells of text pasted from a table or aligned by spaces.
    private static func columnCells(_ text: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var spaces = 0
        for character in text {
            if character == "\t" {
                cells.append(current)
                current = ""
                spaces = 0
            } else if character == " " {
                spaces += 1
                if spaces == 3 {
                    current = String(current.dropLast(2))
                    cells.append(current)
                    current = ""
                } else if spaces < 3 {
                    current.append(character)
                }
            } else {
                spaces = 0
                current.append(character)
            }
        }
        cells.append(current)
        return cells
    }

    private static func collapsingSpaces(_ text: some StringProtocol) -> String {
        var result = ""
        var lastWasSpace = false
        for character in text {
            if character == " " {
                if !lastWasSpace { result.append(character) }
                lastWasSpace = true
            } else {
                result.append(character)
                lastWasSpace = false
            }
        }
        return result
    }

    private static func endsWithWordHyphen(_ text: String) -> Bool {
        let trimmed = text.trimmingSpaces()
        guard trimmed.hasSuffix("-") || trimmed.hasSuffix("‐") else { return false }
        let beforeHyphen = trimmed.dropLast()
        return beforeHyphen.last?.isLetter == true
    }
}

// MARK: - Helpers

extension StringProtocol {
    /// Without the spaces and tabs at both ends.
    func trimmingSpaces() -> SubSequence {
        let isSpace: (Character) -> Bool = { $0.isWhitespace }
        guard let start = firstIndex(where: { !isSpace($0) }) else { return self[endIndex...] }
        guard let last = lastIndex(where: { !isSpace($0) }) else { return self[endIndex...] }
        return self[start...last]
    }
}
