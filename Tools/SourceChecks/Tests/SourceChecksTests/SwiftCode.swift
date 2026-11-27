import Foundation

/// A Swift source as the checks that look for a word in its code read it: without the comments, and without losing a
/// character of code to them.
///
/// Both views keep the line breaks and the column of every character, so a line has the number it has in the file.
/// - `code` turns the comments into spaces and keeps the text of the string literals: a word in a string is a mention
///   that a check has to see (it can be a key path or a selector), and a `//` in a string is not a comment, so the code
///   after it is not hidden.
/// - `skeleton` turns the text of the string literals into spaces as well, and the `\(` and `)` that open and close an
///   interpolation, so that the braces and the parentheses of the code are the only ones left to match.
///
/// A comment that is not closed, or a string that is not, makes the rest of the file one: the compiler refuses such a
/// source. A regular expression literal is read as code, so a `//` in one starts a comment.
struct SwiftCode {
    let code: [String]
    let skeleton: [String]

    init(_ source: String) {
        code = Self.blanked(source, strings: false)
        skeleton = Self.blanked(source, strings: true)
    }

    // MARK: Members

    /// The lines of a declaration: from the first one that opens with `header` (`private` may come before it), within
    /// `scope` when it is given, to the one that closes its braces. A declaration whose first line holds no brace, such as a
    /// stored property, is that line; so is one whose signature runs over several lines, which makes the range too small
    /// and never too big: a check that allows the code of a member only in its range is stricter, not blinder.
    func member(startingWith header: String, within scope: Range<Int>? = nil) -> Range<Int>? {
        let lines = scope ?? skeleton.indices
        guard let start = lines.first(where: { index in
            let text = skeleton[index].drop { $0 == " " }
            return text.hasPrefix(header) || text.hasPrefix("private " + header)
        }) else { return nil }
        var depth = 0
        for index in start..<skeleton.count {
            for character in skeleton[index] {
                if character == "{" { depth += 1 }
                if character == "}" { depth -= 1 }
            }
            if depth <= 0 { return start..<(index + 1) }
        }
        return nil
    }

    /// The lines of the code where `pattern` starts. The pattern may run over several lines (`\s` takes a line break), so a
    /// call split after its parenthesis is found on the line of its name.
    func lines(matching pattern: NSRegularExpression) -> [Int] {
        Self.lines(of: code, matching: pattern)
    }

    /// The lines of the skeleton where `pattern` starts: as `lines(matching:)`, without the text of the strings, so a
    /// declaration quoted in a string is not found, and one inside an interpolation is.
    func skeletonLines(matching pattern: NSRegularExpression) -> [Int] {
        Self.lines(of: skeleton, matching: pattern)
    }

    private static func lines(of view: [String], matching pattern: NSRegularExpression) -> [Int] {
        let text = view.joined(separator: "\n")
        let found = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            text.utf16.prefix(match.range.location).filter { $0 == 10 }.count
        }
        return Array(Set(found)).sorted()
    }

    // MARK: Blanking

    /// A string literal being read: what ends it (the quotes, and the `#` of a raw string), what starts an escape in it, and
    /// the depth of the parentheses of the interpolation being read in it, or nil while reading its text
    private struct Literal {
        let closer: [Unicode.Scalar]
        let escape: [Unicode.Scalar]
        var interpolation: Int?
    }

    /// The lines of the source, an empty one included, with its comments, and its strings if `blankStrings`, turned into spaces
    private static func blanked(_ source: String, strings blankStrings: Bool) -> [String] {
        let text = Array(source.unicodeScalars)
        var result = text
        var literals: [Literal] = []

        func has(_ prefix: [Unicode.Scalar], at index: Int) -> Bool {
            index + prefix.count <= text.count && Array(text[index..<index + prefix.count]) == prefix
        }
        func clear(_ range: Range<Int>) {
            for index in range where index < text.count && text[index] != "\n" && text[index] != "\r" { result[index] = " " }
        }
        func clearString(_ range: Range<Int>) {
            if blankStrings { clear(range) }
        }

        var index = 0
        while index < text.count {
            if let literal = literals.last, literal.interpolation == nil {
                // In the text of a string
                if has(literal.escape + ["("], at: index) {
                    clearString(index..<index + literal.escape.count + 1)
                    literals[literals.count - 1].interpolation = 1
                    index += literal.escape.count + 1
                } else if has(literal.escape, at: index) {
                    clearString(index..<index + literal.escape.count + 1)
                    index += literal.escape.count + 1
                } else if has(literal.closer, at: index) {
                    literals.removeLast()
                    index += literal.closer.count
                } else {
                    clearString(index..<index + 1)
                    index += 1
                }
            } else if has(["/", "/"], at: index) {
                let end = text[index...].firstIndex { $0 == "\n" || $0 == "\r" } ?? text.count
                clear(index..<end)
                index = end
            } else if has(["/", "*"], at: index) {
                // Comments nest
                var depth = 1
                var end = index + 2
                while end < text.count && depth > 0 {
                    if has(["/", "*"], at: end) {
                        depth += 1
                        end += 2
                    } else if has(["*", "/"], at: end) {
                        depth -= 1
                        end += 2
                    } else {
                        end += 1
                    }
                }
                clear(index..<min(end, text.count))
                index = end
            } else if text[index] == "\"" || text[index] == "#" {
                var quote = index
                while quote < text.count && text[quote] == "#" { quote += 1 }
                if quote < text.count && text[quote] == "\"" {
                    let hashes = [Unicode.Scalar](text[index..<quote])
                    let quotes: [Unicode.Scalar] = has(["\"", "\"", "\""], at: quote) ? ["\"", "\"", "\""] : ["\""]
                    literals.append(Literal(closer: quotes + hashes, escape: ["\\"] + hashes, interpolation: nil))
                    index = quote + quotes.count
                } else {
                    index = quote
                }
            } else {
                if let depth = literals.last?.interpolation {
                    if text[index] == "(" {
                        literals[literals.count - 1].interpolation = depth + 1
                    } else if text[index] == ")" {
                        if depth == 1 {
                            clearString(index..<index + 1)
                            literals[literals.count - 1].interpolation = nil
                        } else {
                            literals[literals.count - 1].interpolation = depth - 1
                        }
                    }
                }
                index += 1
            }
        }
        return String(String.UnicodeScalarView(result)).split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
    }
}
