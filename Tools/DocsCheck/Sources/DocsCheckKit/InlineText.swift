/// The text a heading shows once its inline Markdown is rendered: code spans keep their content, links keep their
/// text, images and HTML tags disappear, and emphasis markers are dropped. It covers the inline syntax headings use,
/// not the whole of CommonMark.
enum InlineText {
    static func plain(_ markdown: String) -> String {
        var renderer = Renderer(characters: Array(markdown))
        return Emphasis.text(of: renderer.render(0..<renderer.characters.count))
    }

    /// Rendered text, with each run of underscores kept apart: whether it is emphasis depends on its other end.
    private enum Piece {
        case text(String)
        case underscores(count: Int, canOpen: Bool, canClose: Bool)
    }

    /// Drops the underscores that open or close emphasis, and keeps the others, as CommonMark does: a run closes
    /// the nearest open run it may close, and what is left over stays in the text, so `_config.yml` keeps its
    /// underscore. A run that can both open and close does not match when the two lengths add up to a multiple of
    /// three, unless both are multiples of three (the rule of three).
    private enum Emphasis {
        static func text(of pieces: [Piece]) -> String {
            var remaining = pieces.map { piece -> Int in
                if case .underscores(let count, _, _) = piece { return count }
                return 0
            }
            var open: [Int] = []
            for (index, piece) in pieces.enumerated() {
                guard case .underscores(_, let canOpen, let canClose) = piece else { continue }
                while canClose, remaining[index] > 0, let position = opener(for: index, in: pieces, among: open) {
                    let opener = open[position]
                    let used = min(remaining[index], remaining[opener])
                    remaining[index] -= used
                    remaining[opener] -= used
                    open.removeSubrange((remaining[opener] == 0 ? position : position + 1)...)
                }
                if canOpen, remaining[index] > 0 { open.append(index) }
            }
            var text = ""
            for (index, piece) in pieces.enumerated() {
                switch piece {
                case .text(let string): text += string
                case .underscores: text += String(repeating: "_", count: remaining[index])
                }
            }
            return text
        }

        /// The position in `open` of the nearest opener that the run at `closer` may close.
        private static func opener(for closer: Int, in pieces: [Piece], among open: [Int]) -> Int? {
            guard case .underscores(let closerCount, let closerCanOpen, _) = pieces[closer] else { return nil }
            for position in open.indices.reversed() {
                guard case .underscores(let openerCount, _, let openerCanClose) = pieces[open[position]] else { continue }
                let sum = openerCount + closerCount
                if (closerCanOpen || openerCanClose) && sum % 3 == 0 && !(openerCount % 3 == 0 && closerCount % 3 == 0) { continue }
                return position
            }
            return nil
        }
    }

    private struct Renderer {
        let characters: [Character]

        mutating func render(_ range: Range<Int>) -> [Piece] {
            var pieces: [Piece] = []
            func append(_ string: String) {
                if case .text(let last)? = pieces.last {
                    pieces[pieces.count - 1] = .text(last + string)
                } else {
                    pieces.append(.text(string))
                }
            }
            var index = range.lowerBound
            while index < range.upperBound {
                let character = characters[index]
                switch character {
                case "\\" where index + 1 < range.upperBound && Self.isASCIIPunctuation(characters[index + 1]):
                    append(String(characters[index + 1]))
                    index += 2
                case "`":
                    var text = ""
                    index = appendCodeSpan(at: index, in: range, to: &text)
                    append(text)
                case "!" where index + 1 < range.upperBound && characters[index + 1] == "[":
                    if let link = link(at: index + 1, in: range) {
                        index = link.end
                    } else {
                        index += 1
                    }
                case "[":
                    if let link = link(at: index, in: range) {
                        for piece in render(link.label) {
                            if case .text(let string) = piece { append(string) } else { pieces.append(piece) }
                        }
                        index = link.end
                    } else {
                        index += 1
                    }
                case "<":
                    var text = ""
                    index = appendAngleBracket(at: index, in: range, to: &text)
                    append(text)
                case "&":
                    var text = ""
                    index = appendEntity(at: index, in: range, to: &text)
                    append(text)
                case "_":
                    let run = runLength(of: "_", at: index, in: range)
                    let flanking = flanking(runStart: index, runEnd: index + run, in: range)
                    pieces.append(.underscores(count: run, canOpen: flanking.canOpen, canClose: flanking.canClose))
                    index += run
                default:
                    append(String(character))
                    index += 1
                }
            }
            return pieces
        }

        // MARK: Code spans

        private func appendCodeSpan(at start: Int, in range: Range<Int>, to text: inout String) -> Int {
            let opening = runLength(of: "`", at: start, in: range)
            var scan = start + opening
            while scan < range.upperBound {
                guard characters[scan] == "`" else { scan += 1; continue }
                let closing = runLength(of: "`", at: scan, in: range)
                if closing == opening {
                    var content = String(characters[(start + opening)..<scan])
                    if content.count > 1, content.hasPrefix(" "), content.hasSuffix(" "), content.contains(where: { $0 != " " }) {
                        content = String(content.dropFirst().dropLast())
                    }
                    text += content
                    return scan + closing
                }
                scan += closing
            }
            return start + opening
        }

        // MARK: Links

        private struct Link {
            let label: Range<Int>
            let end: Int
        }

        /// A link or image starting at the `[` at `start`: `[label](destination)`, `[label][reference]` or `[label]`.
        private func link(at start: Int, in range: Range<Int>) -> Link? {
            guard let close = matchingBracket(from: start, in: range) else { return nil }
            let label = (start + 1)..<close
            let next = close + 1
            guard next < range.upperBound else { return Link(label: label, end: next) }
            if characters[next] == "(", let end = matchingParenthesis(from: next, in: range) {
                return Link(label: label, end: end + 1)
            }
            if characters[next] == "[", let end = matchingBracket(from: next, in: range) {
                return Link(label: label, end: end + 1)
            }
            return Link(label: label, end: next)
        }

        private func matchingBracket(from start: Int, in range: Range<Int>) -> Int? {
            var depth = 0
            var index = start
            while index < range.upperBound {
                switch characters[index] {
                case "\\": index += 1
                case "`": index += runLength(of: "`", at: index, in: range) - 1
                case "[": depth += 1
                case "]":
                    depth -= 1
                    if depth == 0 { return index }
                default: break
                }
                index += 1
            }
            return nil
        }

        private func matchingParenthesis(from start: Int, in range: Range<Int>) -> Int? {
            var depth = 0
            var index = start
            while index < range.upperBound {
                switch characters[index] {
                case "\\": index += 1
                case "(": depth += 1
                case ")":
                    depth -= 1
                    if depth == 0 { return index }
                default: break
                }
                index += 1
            }
            return nil
        }

        // MARK: Angle brackets and entities

        /// An autolink contributes its address, an HTML tag nothing, and a lone `<` is literal text.
        private func appendAngleBracket(at start: Int, in range: Range<Int>, to text: inout String) -> Int {
            guard let close = characters[start..<range.upperBound].firstIndex(of: ">") else {
                text.append("<")
                return start + 1
            }
            let inside = String(characters[(start + 1)..<close])
            if Self.isAutolink(inside) {
                text += inside
            } else if !Self.isHTMLTag(inside) {
                text.append("<")
                return start + 1
            }
            return close + 1
        }

        private static func isAutolink(_ inside: String) -> Bool {
            guard let colon = inside.firstIndex(of: ":"), colon != inside.startIndex, !inside.contains(where: \.isWhitespace) else { return false }
            return inside[..<colon].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+.-".contains($0)) }
        }

        private static func isHTMLTag(_ inside: String) -> Bool {
            guard let first = inside.first else { return false }
            return first.isLetter || first == "/" || first == "!"
        }

        /// A character reference: the six named ones (`&amp; &lt; &gt; &quot; &apos; &nbsp;`) and numeric ones. A
        /// numeric reference to no character is U+FFFD, as in CommonMark. Anything else stays as written.
        private func appendEntity(at start: Int, in range: Range<Int>, to text: inout String) -> Int {
            guard let semicolon = characters[start..<min(range.upperBound, start + 12)].firstIndex(of: ";") else {
                text.append("&")
                return start + 1
            }
            let name = String(characters[(start + 1)..<semicolon])
            let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}"]
            if let value = named[name] {
                text += value
            } else if name.hasPrefix("#"), let scalar = Self.scalar(fromNumericReference: name.dropFirst()) {
                text.unicodeScalars.append(scalar)
            } else {
                text.append("&")
                return start + 1
            }
            return semicolon + 1
        }

        /// The character a numeric reference names (up to 7 decimal or 6 hexadecimal digits), or U+FFFD for a value
        /// that is not a scalar. Nil if the digits are not a numeric reference.
        private static func scalar(fromNumericReference digits: Substring) -> Unicode.Scalar? {
            let value: UInt32?
            if let first = digits.first, first == "x" || first == "X" {
                let hex = digits.dropFirst()
                value = (1...6).contains(hex.count) ? UInt32(hex, radix: 16) : nil
            } else {
                value = (1...7).contains(digits.count) ? UInt32(digits) : nil
            }
            guard let value else { return nil }
            return value == 0 ? "\u{FFFD}" : (Unicode.Scalar(value) ?? "\u{FFFD}")
        }

        // MARK: Emphasis

        /// Whether a run of underscores can open or close emphasis (CommonMark's flanking rules for `_`), as
        /// opposed to being a letter of a word such as `snake_case`.
        private func flanking(runStart: Int, runEnd: Int, in range: Range<Int>) -> (canOpen: Bool, canClose: Bool) {
            let before = runStart > range.lowerBound ? characters[runStart - 1] : nil
            let after = runEnd < range.upperBound ? characters[runEnd] : nil
            let beforeIsSpace = before?.isWhitespace ?? true
            let afterIsSpace = after?.isWhitespace ?? true
            let beforeIsPunctuation = before.map { $0.isPunctuation || $0.isSymbol } ?? false
            let afterIsPunctuation = after.map { $0.isPunctuation || $0.isSymbol } ?? false
            let leftFlanking = !afterIsSpace && (!afterIsPunctuation || beforeIsSpace || beforeIsPunctuation)
            let rightFlanking = !beforeIsSpace && (!beforeIsPunctuation || afterIsSpace || afterIsPunctuation)
            return (leftFlanking && (!rightFlanking || beforeIsPunctuation), rightFlanking && (!leftFlanking || afterIsPunctuation))
        }

        // MARK: Helpers

        private func runLength(of character: Character, at start: Int, in range: Range<Int>) -> Int {
            var end = start
            while end < range.upperBound, characters[end] == character { end += 1 }
            return end - start
        }

        private static func isASCIIPunctuation(_ character: Character) -> Bool {
            character.isASCII && (character.isPunctuation || character.isSymbol)
        }
    }
}
