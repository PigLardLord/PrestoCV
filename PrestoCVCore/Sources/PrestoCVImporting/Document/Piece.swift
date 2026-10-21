// MARK: - A piece of the text with its span

/// A piece of the canonical text and its span, cut and trimmed without losing where it is.
struct Piece: Equatable {
    let text: String
    let span: SourceSpan

    init(text: String, span: SourceSpan) {
        self.text = text
        self.span = span
    }

    init(cell: Int, of block: SourceBlock, in document: SourceDocument) {
        let span = block.cells.indices.contains(cell) ? block.cells[cell] : SourceSpan(block.span.lowerBound, block.span.lowerBound)
        self.init(text: document.text(of: span), span: span)
    }

    /// The pieces of every cell of a block.
    static func cells(of block: SourceBlock, in document: SourceDocument) -> [Piece] {
        block.cells.indices.map { Piece(cell: $0, of: block, in: document) }.filter { !$0.isEmpty }
    }

    var isEmpty: Bool { text.isEmpty }

    /// The part of the piece in a range of its text.
    func sub(_ range: Range<String.Index>) -> Piece {
        let scalars = text.unicodeScalars
        let lower = scalars.distance(from: scalars.startIndex, to: range.lowerBound)
        let upper = scalars.distance(from: scalars.startIndex, to: range.upperBound)
        return Piece(text: String(text[range]), span: SourceSpan(span.lowerBound + lower, span.lowerBound + upper))
    }

    /// Without the characters of the set at both ends, nor a bracket at either end that the piece does not close or
    /// open.
    func trimmed() -> Piece {
        let characters = Piece.isTrimmable
        var piece = self
        while true {
            guard let start = piece.text.firstIndex(where: { !characters($0) }),
                  let last = piece.text.lastIndex(where: { !characters($0) }) else {
                return piece.sub(piece.text.endIndex..<piece.text.endIndex)
            }
            piece = piece.sub(start..<piece.text.index(after: last))
            let opens = piece.text.filter { $0 == "(" || $0 == "[" }.count
            let closes = piece.text.filter { $0 == ")" || $0 == "]" }.count
            if let lastCharacter = piece.text.last, lastCharacter == "(" || lastCharacter == "[" {
                piece = piece.sub(piece.text.startIndex..<piece.text.index(before: piece.text.endIndex))
            } else if let first = piece.text.first, first == ")" || first == "]" {
                piece = piece.sub(piece.text.index(after: piece.text.startIndex)..<piece.text.endIndex)
            } else if let first = piece.text.first, first == "(" || first == "[", opens > closes {
                piece = piece.sub(piece.text.index(after: piece.text.startIndex)..<piece.text.endIndex)
            } else if let lastCharacter = piece.text.last, lastCharacter == ")" || lastCharacter == "]", closes > opens {
                piece = piece.sub(piece.text.startIndex..<piece.text.index(before: piece.text.endIndex))
            } else if piece.text.first == "(" && piece.text.last == ")" && opens == 1 && closes == 1 {
                piece = piece.sub(piece.text.index(after: piece.text.startIndex)..<piece.text.index(before: piece.text.endIndex))
            } else {
                return piece
            }
        }
    }

    /// White space, separators, the symbols and emoji used as icons, and an unmatched bracket at either end.
    static func isTrimmable(_ character: Character) -> Bool {
        if character.isWhitespace { return true }
        if " ,;:|·•–—-/*_~>".contains(character) { return true }
        return isIcon(character)
    }

    /// A symbol or emoji used as an icon: "📞", "✉", "★", "●".
    static func isIcon(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        if character.unicodeScalars.count > 1, scalar.properties.isEmoji { return true }
        if scalar.properties.generalCategory == .otherSymbol { return true }
        if scalar.properties.generalCategory == .mathSymbol { return !"+=<>".contains(character) }
        return scalar.properties.isEmojiPresentation
    }

    /// The pieces between the separators, trimmed, without the empty ones. A separator of letters only splits
    /// between whole words.
    func split(by separators: [String]) -> [Piece] {
        var pieces: [Piece] = []
        var start = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            if let separator = separators.first(where: { matches($0, at: index) }) {
                pieces.append(sub(start..<index))
                index = text.index(index, offsetBy: separator.count)
                start = index
            } else {
                index = text.index(after: index)
            }
        }
        pieces.append(sub(start..<text.endIndex))
        return pieces.map { $0.trimmed() }.filter { !$0.isEmpty }
    }

    private func matches(_ separator: String, at index: String.Index) -> Bool {
        guard text[index...].hasPrefix(separator) else { return false }
        guard separator.allSatisfy({ $0.isLetter || $0 == " " }) else { return true }
        let end = text.index(index, offsetBy: separator.count)
        let before = index == text.startIndex ? nil : text[text.index(before: index)]
        let after = end == text.endIndex ? nil : text[end]
        return !(before?.isLetter ?? false) && !(after?.isLetter ?? false)
    }

    /// The piece without the parts in the ranges, split there.
    func removing(_ ranges: [Range<String.Index>]) -> [Piece] {
        var pieces: [Piece] = []
        var start = text.startIndex
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) where range.lowerBound >= start {
            pieces.append(sub(start..<range.lowerBound))
            start = range.upperBound
        }
        pieces.append(sub(start..<text.endIndex))
        return pieces.map { $0.trimmed() }.filter { !$0.isEmpty }
    }

    /// The value of the piece as a quote.
    func quote(check: CheckReason? = nil) -> Sourced<String> {
        Sourced(value: text, spans: [span], check: check)
    }

    var words: [Substring] { text.words }
}

/// Strong separators between the parts of a line of a CV.
enum Separators {
    static let strong = [" | ", "|", " · ", "·", " • ", "•", " — ", "—", " – ", "\t", "; ", " ‧ ", " ∙ ", " ▪ ", " ⋅ "]
}
