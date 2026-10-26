// MARK: - Lines in

/// A line of the document in reading order, before normalisation: a line of pasted text, or a line the page analysis
/// made from a PDF's words, with its cells separated by tabs.
struct RawLine: Equatable {
    var text: String
    var page: Int?
    var frame: Rect?
    var column: Int?
    /// The PDF draws it bold, or larger than the body text.
    var isEmphasized: Bool = false
    /// A wider gap than between lines comes before it on the page.
    var followsGap: Bool = false
    /// Where the line's text starts, past a list marker, in a PDF: a wrapped line of a list item starts there too.
    var textStart: Double?
    /// The largest font size of the line, in a PDF.
    var fontSize: Double?
    /// In a PDF: where the line's last cell starts and whether it is bold, whether its first cell is bold, how wide its
    /// first word is, and the right edge of its column. A line was wrapped when the next one's first word would not
    /// have fitted after it.
    var lastCellX: Double?
    var lastCellBold = false
    var firstCellBold = false
    var firstWordWidth: Double?
    var columnRight: Double?

    init(text: String, page: Int? = nil, frame: Rect? = nil, column: Int? = nil,
         isEmphasized: Bool = false, followsGap: Bool = false, textStart: Double? = nil, fontSize: Double? = nil) {
        self.text = text
        self.page = page
        self.frame = frame
        self.column = column
        self.isEmphasized = isEmphasized
        self.followsGap = followsGap
        self.textStart = textStart
        self.fontSize = fontSize
    }
}

/// Reads pasted text.
public enum PlainTextReader {
    /// The lines of a text, split at every kind of line break.
    public static func lines(of text: String) -> [String] {
        var lines: [String] = []
        var current = String.UnicodeScalarView()
        var previousWasCarriageReturn = false
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\n":
                if !previousWasCarriageReturn { lines.append(String(current)); current = String.UnicodeScalarView() }
                previousWasCarriageReturn = false
                continue
            case "\r", "\u{2028}", "\u{2029}", "\u{85}", "\u{0B}", "\u{0C}":
                lines.append(String(current))
                current = String.UnicodeScalarView()
                previousWasCarriageReturn = scalar == "\r"
                continue
            default:
                previousWasCarriageReturn = false
                current.append(scalar)
            }
        }
        lines.append(String(current))
        return lines
    }
}

// MARK: - The builder

/// Normalises the lines, joins the ones that go on from the line before, and lays the blocks out over one canonical
/// text. What it leaves out is noise, each piece with its reason.
enum DocumentBuilder {

    private struct Pending {
        var cells: [String]
        var kind: SourceBlock.Kind
        var isEmphasized: Bool
        var followsGap: Bool
        var lineEnd: NormalizedLine.LineEnd
        var page: Int?
        var frame: Rect?
        var column: Int?
        var textStart: Double?
        var fontSize: Double?
        var lastCellX: Double?
        var lastCellBold: Bool
        var columnRight: Double?
    }

    static func build(lines: [RawLine], format: SourceFormat) -> (SourceDocument, [LeftOutText]) {
        var leftOut: [LeftOutText] = []
        let normalized = lines.map { LineNormalizer.normalize($0.text) }
        let chatter = chatterLines(normalized)

        var pending: [Pending] = []
        var gap = false
        for (index, line) in normalized.enumerated() {
            let raw = lines[index]
            if chatter.contains(index) {
                leftOut.append(LeftOutText(text: line.text, span: nil, reason: .chatter))
                gap = true
                continue
            }
            switch line.markup {
            case .rule:
                leftOut.append(LeftOutText(text: raw.text.trimmingSpaces().description, span: nil, reason: .markup))
                gap = true
                continue
            case .tableSeparator:
                leftOut.append(LeftOutText(text: raw.text.trimmingSpaces().description, span: nil, reason: .markup))
                if let last = pending.indices.last, pending[last].kind == .line { pending[last].kind = .tableHeader }
                continue
            default:
                break
            }
            if line.isEmpty {
                gap = true
                continue
            }
            let followsGap = gap || raw.followsGap
            gap = false
            if let last = pending.indices.last, continues(pending[last], with: line, raw: raw, followsGap: followsGap) {
                join(&pending[last], with: line, raw: raw)
                continue
            }
            let kind: SourceBlock.Kind
            switch line.markup {
            case .heading(let level): kind = .heading(level: level)
            case .listItem: kind = .listItem
            default: kind = .line
            }
            pending.append(Pending(
                cells: line.cells, kind: kind, isEmphasized: line.isBold || raw.isEmphasized, followsGap: followsGap,
                lineEnd: line.lineEnd, page: raw.page, frame: raw.frame, column: raw.column,
                textStart: raw.textStart, fontSize: raw.fontSize, lastCellX: raw.lastCellX, lastCellBold: raw.lastCellBold,
                columnRight: raw.columnRight
            ))
        }
        return (layOut(pending, format: format), leftOut)
    }

    // MARK: Continuation lines

    /// A line goes on from the block before when nothing separates them and it is not a block of its own: a word broken
    /// by a hyphen, a wrapped line that goes on in lower case after a list item or prose, or, in a PDF, a line
    /// indented under a list item's text.
    private static func continues(_ block: Pending, with line: NormalizedLine, raw: RawLine, followsGap: Bool) -> Bool {
        // In a PDF, a line the layout wrapped goes on in the next line that starts where its last cell starts, in the
        // same style
        // Only a table's cell or prose wraps: a list in a narrow column looks the same, line by line
        let isProse = (block.cells.last?.words.count ?? 0) >= 6
        if !followsGap, line.markup == .none, line.cells.count == 1, block.column == raw.column, block.cells.count >= 2 || isProse,
           let lastCellX = block.lastCellX, let frame = raw.frame, abs(frame.x - lastCellX) < 2,
           let blockFrame = block.frame, let right = block.columnRight, let firstWord = raw.firstWordWidth,
           blockFrame.maxX + 0.3 * (raw.fontSize ?? 10) + firstWord > right + 1,
           block.lastCellBold == raw.firstCellBold, block.kind == .line || block.kind == .listItem {
            return true
        }
        guard !followsGap, line.markup == .none, block.cells.count == 1, line.cells.count == 1,
              block.column == raw.column, block.kind == .line || block.kind == .listItem,
              let previous = block.cells.last, let next = line.cells.first else { return false }
        if previous.hasSuffix(":") { return false }
        // A line that opens with emphasis, or is built of parts between bars, is a line of its own
        let rawStart = raw.text.trimmingSpaces()
        if rawStart.hasPrefix("**") || rawStart.hasPrefix("__") || next.contains(" | ") { return false }
        // The next line goes on in lower case with a word, not with an address or a number
        let goesOn = next.split(separator: " ").first.map { token in
            token.first?.isLetter == true && token.allSatisfy { ($0.isLetter && $0.isLowercase) || "-'’,;.".contains($0) }
        } ?? false
        if block.lineEnd != .plain && goesOn { return true }
        // A bracket left open, as a period wrapped at its dash: "(2012 -" and "2015)"
        if previous.filter({ $0 == "(" }).count > previous.filter({ $0 == ")" }).count { return true }
        if goesOn && (block.kind == .listItem || previous.words.count >= 6) { return true }
        if block.kind == .listItem, let textStart = block.textStart, let frame = raw.frame,
           abs(frame.x - textStart) < 3, !line.isBold {
            return true
        }
        return false
    }

    private static func join(_ block: inout Pending, with line: NormalizedLine, raw: RawLine) {
        guard let previous = block.cells.last, let next = line.cells.first else { return }
        let joined: String
        switch block.lineEnd {
        case .softHyphen:
            // The soft hyphen is already gone: the word's two parts meet
            joined = previous + next
        case .hyphen:
            // A visible hyphen before a lower-case letter only broke the word; before a capital it is part of the word
            let brokeTheWord = next.startsInLowerCase && (previous.hasSuffix("-") || previous.hasSuffix("‐"))
            joined = brokeTheWord ? String(previous.dropLast()) + next : previous + next
        case .plain:
            joined = previous + " " + next
        }
        block.cells[block.cells.count - 1] = joined
        block.lineEnd = line.lineEnd
        // The block's frame ends where its last line ends, so a wrapped line is told from the line it wrapped
        if let frame = raw.frame, let old = block.frame {
            let united = old.union(frame)
            block.frame = Rect(x: united.x, y: united.y, width: frame.maxX - united.x, height: united.height)
        } else if let frame = raw.frame {
            block.frame = frame
        }
    }

    // MARK: A chat assistant's sentences

    /// The opening and closing sentences of a chat assistant's answer: among the first and last three lines, a line
    /// that opens as such a sentence does in the six languages, and that introduces or offers something.
    private static func chatterLines(_ lines: [NormalizedLine]) -> Set<Int> {
        let content = lines.indices.filter { !lines[$0].isEmpty && lines[$0].markup != .rule && lines[$0].markup != .tableSeparator }
        var found = Set<Int>()
        for index in content.prefix(3) {
            let line = lines[index]
            if case .heading = line.markup { break }
            let text = line.text
            let folded = String(text.folded.drop { !$0.isLetter })
            let introduces = text.hasSuffix(":") || text.hasSuffix("!") || documentWords.contains { folded.contains($0) }
            guard openingPhrases.contains(where: { folded.hasPrefix($0) }), introduces, text.words.count >= 3 else { break }
            found.insert(index)
        }
        for index in content.suffix(3).reversed() {
            let folded = String(lines[index].text.folded.drop { !$0.isLetter })
            guard closingPhrases.contains(where: { folded.hasPrefix($0) }), lines[index].text.words.count >= 4 else { break }
            found.insert(index)
        }
        return found
    }

    private static let documentWords = ["cv", "curriculum", "lebenslauf", "resume", "currículo".folded, "version", "versione"]

    private static let openingPhrases = [
        "sure", "certainly", "of course", "absolutely", "here's", "here is", "here are", "below is", "great", "okay",
        "ecco", "certo", "certamente", "ok", "va bene", "perfetto", "di seguito", "qui sotto", "ho preparato", "ho riscritto",
        "hier ist", "hier sind", "gerne", "natürlich", "klar", "sicher", "nachfolgend",
        "aquí tienes", "aquí está", "claro", "por supuesto", "a continuación",
        "voici", "bien sûr", "certainement", "ci-dessous", "avec plaisir",
        "aqui está", "aqui estão", "segue", "com certeza", "abaixo",
    ].map(\.folded)

    private static let closingPhrases = [
        "let me know", "if you'd like", "if you want", "would you like", "i can also", "hope this", "feel free",
        "fammi sapere", "se vuoi", "se desideri", "posso anche", "spero", "vuoi che",
        "lass mich wissen", "sag mir", "wenn du", "möchtest du", "ich kann", "ich hoffe", "falls du",
        "avísame", "dime si", "si quieres", "si deseas", "puedo", "espero", "¿quieres", "quieres que",
        "dis-moi", "n'hésite", "si tu veux", "si vous souhaitez", "je peux", "j'espère", "souhaites-tu",
        "diz-me", "avisa-me", "se quiser", "se quiseres", "posso também", "queres que", "quer que",
    ].map(\.folded)

    // MARK: Layout

    private static func layOut(_ pending: [Pending], format: SourceFormat) -> SourceDocument {
        var text = String.UnicodeScalarView()
        var offset = 0
        var blocks: [SourceBlock] = []
        for (index, block) in pending.enumerated() {
            if index > 0 {
                text.append("\n")
                offset += 1
            }
            let start = offset
            var cells: [SourceSpan] = []
            for (cellIndex, cell) in block.cells.enumerated() {
                if cellIndex > 0 {
                    text.append("\t")
                    offset += 1
                }
                let scalars = cell.unicodeScalars
                text.append(contentsOf: scalars)
                cells.append(SourceSpan(offset, offset + scalars.count))
                offset += scalars.count
            }
            blocks.append(SourceBlock(
                index: index, span: SourceSpan(start, offset), cells: cells, kind: block.kind, isEmphasized: block.isEmphasized,
                followsGap: block.followsGap, page: block.page, frame: block.frame, column: block.column, fontSize: block.fontSize
            ))
        }
        return SourceDocument(format: format, text: String(text), blocks: blocks)
    }
}
