// MARK: - A piece of the text with its span

/// A piece of the canonical text and its span, cut and trimmed without losing where it is.
///
/// A line of the text can be a hundred thousand characters long, and a reader cuts it at every match: a cut costs what it
/// cuts, and finding where it cuts costs no more than finding the place (R8). The span counts scalars, the string
/// counts UTF-16 units from its start in constant time, and the two differ by the scalars of two units, which the piece
/// knows by their places.
struct Piece: Equatable {
    let text: String
    let span: SourceSpan
    /// The places, in UTF-16 units from the start of the text, of the scalars that take two units, in order.
    private let twoUnitScalars: [Int]

    init(text: String, span: SourceSpan) {
        self.init(text: text, span: span, twoUnitScalars: Piece.twoUnitScalars(in: text))
    }

    private init(text: String, span: SourceSpan, twoUnitScalars: [Int]) {
        self.text = text
        self.span = span
        self.twoUnitScalars = twoUnitScalars
    }

    init(cell: Int, of block: SourceBlock, in document: SourceDocument) {
        let span = block.cells.indices.contains(cell) ? block.cells[cell] : SourceSpan(block.span.lowerBound, block.span.lowerBound)
        self.init(text: document.text(of: span), span: span)
    }

    static func == (lhs: Piece, rhs: Piece) -> Bool { lhs.text == rhs.text && lhs.span == rhs.span }

    /// The pieces of every cell of a block.
    static func cells(of block: SourceBlock, in document: SourceDocument) -> [Piece] {
        block.cells.indices.map { Piece(cell: $0, of: block, in: document) }.filter { !$0.isEmpty }
    }

    var isEmpty: Bool { text.isEmpty }

    private static func twoUnitScalars(in text: String) -> [Int] {
        var places: [Int] = []
        var unit = 0
        for scalar in text.unicodeScalars {
            if scalar.value > 0xFFFF {
                places.append(unit)
                unit += 2
            } else {
                unit += 1
            }
        }
        return places
    }

    /// The part of the piece in a range of its text.
    func sub(_ range: Range<String.Index>) -> Piece {
        let units = text.utf16
        let lowerUnit = units.distance(from: units.startIndex, to: range.lowerBound)
        let upperUnit = units.distance(from: units.startIndex, to: range.upperBound)
        let before = countOfTwoUnitScalars(below: lowerUnit)
        let through = countOfTwoUnitScalars(below: upperUnit)
        return Piece(
            text: String(text[range]),
            span: SourceSpan(span.lowerBound + lowerUnit - before, span.lowerBound + upperUnit - through),
            twoUnitScalars: twoUnitScalars[before..<through].map { $0 - lowerUnit }
        )
    }

    /// The range of the text that a span of the same text covers, cut to the piece. The span counts scalars from the
    /// start of the piece and the text counts units, so the place is found as `sub` finds it, by the scalars of two
    /// units before it: counting scalars from the start of the text for each span is the square of the text (R8).
    func range(of other: SourceSpan) -> Range<String.Index> {
        let lower = index(ofScalar: other.lowerBound - span.lowerBound)
        let upper = index(ofScalar: other.upperBound - span.lowerBound)
        return lower..<max(lower, upper)
    }

    /// The place of the scalar at an offset from the start of the piece, the offset cut to 0...count of scalars.
    private func index(ofScalar offset: Int) -> String.Index {
        let scalar = max(0, min(offset, span.count))
        // The j-th scalar of two units is the scalar number twoUnitScalars[j] - j, and these numbers only grow
        var low = 0
        var high = twoUnitScalars.count
        while low < high {
            let middle = (low + high) / 2
            if twoUnitScalars[middle] - middle < scalar { low = middle + 1 } else { high = middle }
        }
        let units = text.utf16
        return units.index(units.startIndex, offsetBy: scalar + low, limitedBy: units.endIndex) ?? units.endIndex
    }

    /// How many scalars of two units start before the unit.
    private func countOfTwoUnitScalars(below unit: Int) -> Int {
        var low = 0
        var high = twoUnitScalars.count
        while low < high {
            let middle = (low + high) / 2
            if twoUnitScalars[middle] < unit { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// Without the characters of the set at both ends, nor a bracket at either end that the piece does not close or
    /// open. The brackets are counted once and the ends move inward in one pass: a piece of a hundred thousand brackets
    /// is trimmed in one read, not one read for each bracket it takes off.
    func trimmed() -> Piece {
        var start = text.startIndex
        var end = text.endIndex
        var opens = 0
        var closes = 0
        for character in text {
            if Piece.isOpening(character) { opens += 1 } else if Piece.isClosing(character) { closes += 1 }
        }
        while true {
            while start < end, Piece.isTrimmable(text[start]) { start = text.index(after: start) }
            guard start < end else { return sub(end..<end) }
            while end > start, Piece.isTrimmable(text[text.index(before: end)]) { end = text.index(before: end) }
            let first = text[start]
            let last = text[text.index(before: end)]
            if Piece.isOpening(last) {
                end = text.index(before: end)
                opens -= 1
            } else if Piece.isClosing(first) {
                start = text.index(after: start)
                closes -= 1
            } else if Piece.isOpening(first), opens > closes {
                start = text.index(after: start)
                opens -= 1
            } else if Piece.isClosing(last), closes > opens {
                end = text.index(before: end)
                closes -= 1
            } else if first == "(", last == ")", opens == 1, closes == 1 {
                start = text.index(after: start)
                end = text.index(before: end)
                opens = 0
                closes = 0
            } else {
                return sub(start..<end)
            }
        }
    }

    private static func isOpening(_ character: Character) -> Bool { character == "(" || character == "[" }

    private static func isClosing(_ character: Character) -> Bool { character == ")" || character == "]" }

    /// White space, separators, the symbols and emoji used as icons, and an unmatched bracket at either end.
    static func isTrimmable(_ character: Character) -> Bool {
        if character.isWhitespace { return true }
        if " ,;:|·‧•–—-/*_~>".contains(character) { return true }
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
    /// between whole words, and none splits inside a pair of brackets: "Course (Pro, Advanced)" is one piece.
    func split(by separators: [String]) -> [Piece] {
        var pieces: [Piece] = []
        var start = text.startIndex
        var index = text.startIndex
        var bracketed = bracketedRanges()[...]
        while index < text.endIndex {
            if let range = bracketed.first, range.lowerBound == index {
                index = range.upperBound
                bracketed = bracketed.dropFirst()
            } else if let separator = separators.first(where: { matches($0, at: index) }) {
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

    /// The outermost ranges of the text between a bracket and the one that closes it, brackets included, in order: "("
    /// with ")" and "[" with "]". A bracket that is never closed, or never opened, bounds nothing.
    func bracketedRanges() -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var open: [(character: Character, index: String.Index)] = []
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "(" || character == "[" {
                open.append((character, index))
            } else if character == ")" || character == "]", let last = open.last, last.character == (character == ")" ? "(" : "[") {
                open.removeLast()
                let range = last.index..<text.index(after: index)
                // A pair closes after the pairs it holds: they are inside it, and give way to it
                while let inner = ranges.last, range.contains(inner.lowerBound) { ranges.removeLast() }
                ranges.append(range)
            }
            index = text.index(after: index)
        }
        return ranges
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
