/// The text a heading shows once its inline Markdown is rendered: code spans keep their content, links keep their
/// text, images and HTML tags disappear, and emphasis markers are dropped. It covers the inline syntax headings use,
/// not the whole of CommonMark.
enum InlineText {
    static func plain(_ markdown: String) -> String {
        var renderer = Renderer(characters: Array(markdown))
        return renderer.render(0..<renderer.characters.count)
    }

    private struct Renderer {
        let characters: [Character]

        mutating func render(_ range: Range<Int>) -> String {
            var text = ""
            var index = range.lowerBound
            while index < range.upperBound {
                let character = characters[index]
                switch character {
                case "\\" where index + 1 < range.upperBound && Self.isASCIIPunctuation(characters[index + 1]):
                    text.append(characters[index + 1])
                    index += 2
                case "`":
                    index = appendCodeSpan(at: index, in: range, to: &text)
                case "!" where index + 1 < range.upperBound && characters[index + 1] == "[":
                    if let link = link(at: index + 1, in: range) {
                        index = link.end
                    } else {
                        index += 1
                    }
                case "[":
                    if let link = link(at: index, in: range) {
                        text += render(link.label)
                        index = link.end
                    } else {
                        index += 1
                    }
                case "<":
                    index = appendAngleBracket(at: index, in: range, to: &text)
                case "&":
                    index = appendEntity(at: index, in: range, to: &text)
                case "_":
                    let run = runLength(of: "_", at: index, in: range)
                    if !isEmphasisDelimiter(runStart: index, runEnd: index + run, in: range) {
                        text += String(repeating: "_", count: run)
                    }
                    index += run
                default:
                    text.append(character)
                    index += 1
                }
            }
            return text
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

        private func appendEntity(at start: Int, in range: Range<Int>, to text: inout String) -> Int {
            guard let semicolon = characters[start..<min(range.upperBound, start + 12)].firstIndex(of: ";") else {
                text.append("&")
                return start + 1
            }
            let name = String(characters[(start + 1)..<semicolon])
            let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}"]
            if let value = named[name] {
                text += value
            } else if name.hasPrefix("#"), let scalar = Self.scalar(fromNumericEntity: name.dropFirst()) {
                text.unicodeScalars.append(scalar)
            } else {
                text.append("&")
                return start + 1
            }
            return semicolon + 1
        }

        private static func scalar(fromNumericEntity digits: Substring) -> Unicode.Scalar? {
            let value: UInt32?
            if let first = digits.first, first == "x" || first == "X" {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits)
            }
            return value.flatMap(Unicode.Scalar.init)
        }

        // MARK: Emphasis

        /// Whether a run of underscores opens or closes emphasis (CommonMark's flanking rules for `_`), rather than
        /// being a letter of a word such as `snake_case`.
        private func isEmphasisDelimiter(runStart: Int, runEnd: Int, in range: Range<Int>) -> Bool {
            let before = runStart > range.lowerBound ? characters[runStart - 1] : nil
            let after = runEnd < range.upperBound ? characters[runEnd] : nil
            let beforeIsSpace = before?.isWhitespace ?? true
            let afterIsSpace = after?.isWhitespace ?? true
            let beforeIsPunctuation = before.map { $0.isPunctuation || $0.isSymbol } ?? false
            let afterIsPunctuation = after.map { $0.isPunctuation || $0.isSymbol } ?? false
            let leftFlanking = !afterIsSpace && (!afterIsPunctuation || beforeIsSpace || beforeIsPunctuation)
            let rightFlanking = !beforeIsSpace && (!beforeIsPunctuation || afterIsSpace || afterIsPunctuation)
            let opens = leftFlanking && (!rightFlanking || beforeIsPunctuation)
            let closes = rightFlanking && (!leftFlanking || afterIsPunctuation)
            return opens || closes
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
