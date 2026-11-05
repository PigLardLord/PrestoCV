import Foundation

// MARK: - Markdown Text

/// Reads Markdown the way the document checks need it: which paths are Markdown files, which lines are code or comments, which
/// text is prose, what the blocks of a document are and which files its links point at. Everything here is a function of the
/// text, so it is tested without git and without files (`MarkdownTextTests`).
///
/// It is not a Markdown parser. It follows CommonMark where a check would otherwise be wrong: a fence has at most three
/// spaces of indent and is closed only by a fence at least as long, an unclosed fence or comment runs to the end of the file,
/// a heading needs a space after its hashes, and any line ending (line feed, carriage return, or both) ends a line.
enum MarkdownText {

    // MARK: - Files

    private static let extensions: Set<String> = ["md", "markdown", "mdx", "mkd"]

    /// Whether a path is a Markdown file, by its extension in any case: `README.md`, `docs/X.MD`, `notes.markdown`. A folder
    /// called `md`, a file `a.mdc` and `a.md/b.txt` are not.
    static func isMarkdown(_ path: String) -> Bool {
        guard let name = path.split(separator: "/").last, let dot = name.lastIndex(of: ".") else { return false }
        return extensions.contains(name[name.index(after: dot)...].lowercased())
    }

    // MARK: - Lines

    /// The lines of `text`, ending at a line feed, a carriage return or both, with the empty lines kept. A carriage return
    /// followed by a line feed is one `Character` in Swift, so splitting at `"\n"` would not split a file with Windows line
    /// endings.
    static func lines(of text: String) -> [Substring] {
        text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
    }

    /// The level of an ATX heading (`# Title` is 1, `###### Title` is 6), or nil when the line is not one: it has at most
    /// three spaces of indent, one to six hashes, and a space (or the end of the line) after them.
    static func headingLevel(of line: some StringProtocol) -> Int? {
        var rest = Substring(line)
        let indent = rest.prefix { $0 == " " }.count
        guard indent <= 3 else { return nil }
        rest = rest.dropFirst(indent)
        let level = rest.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        guard let next = rest.dropFirst(level).first else { return level }
        return next.isWhitespace ? level : nil
    }

    // MARK: - Code and comments

    /// Follows the fences of fenced code from line to line.
    private struct Fence {
        private var open: (character: Character, length: Int)?

        /// Whether `line` is in fenced code, the lines of the two fences included. A fence is three or more backticks or
        /// tildes after at most three spaces of indent (a tab reaches the fourth column, so it is too much); one of backticks
        /// has no backtick in its info string. It is closed by a fence of the same character, at least as long, with nothing
        /// after it, and a fence never closed runs to the end of the file. A fence indented four or more inside a list item
        /// is read as text: the strict side, since its lines are then judged.
        mutating func contains(_ line: Substring) -> Bool {
            let marker = Self.marker(of: line)
            if let open {
                if let marker, marker.character == open.character, marker.length >= open.length, marker.info.allSatisfy({ $0.isWhitespace }) {
                    self.open = nil
                }
                return true
            }
            guard let marker, !(marker.character == "`" && marker.info.contains("`")) else { return false }
            open = (marker.character, marker.length)
            return true
        }

        private static func marker(of line: Substring) -> (character: Character, length: Int, info: Substring)? {
            let indent = line.prefix { $0 == " " || $0 == "\t" }
            guard indent.count <= 3, !indent.contains("\t") else { return nil }
            let trimmed = line.dropFirst(indent.count)
            guard let character = trimmed.first, character == "`" || character == "~" else { return nil }
            let length = trimmed.prefix { $0 == character }.count
            guard length >= 3 else { return nil }
            return (character, length, trimmed.dropFirst(length))
        }
    }

    /// For each line, whether it is in fenced code (the lines of the fences included).
    static func fencedLines(in lines: [Substring]) -> [Bool] {
        var fence = Fence()
        return lines.map { fence.contains($0) }
    }

    /// `markdown` without fenced code and without HTML comments. A fenced line becomes an empty line, so the paragraphs on
    /// either side of a fence stay apart; a comment becomes a space, and the lines inside a comment that spans several lines
    /// are dropped. A fence inside a comment and a comment inside a fence are text, as in a renderer: whichever opens first
    /// wins. A comment opener inside an inline code span is text too.
    static func withoutFencesAndComments(_ markdown: String) -> String {
        var fence = Fence()
        var inComment = false
        var visible: [String] = []
        for line in lines(of: markdown) {
            if !inComment, fence.contains(line) {
                visible.append("")
                continue
            }
            let startedInComment = inComment
            var kept = ""
            var rest = line
            while !rest.isEmpty {
                if inComment {
                    guard let end = rest.range(of: "-->") else { break }
                    rest = rest[end.upperBound...]
                    inComment = false
                } else if let start = commentStart(in: rest) {
                    kept += String(rest[..<start.lowerBound]) + " "
                    rest = rest[start.upperBound...]
                    inComment = true
                } else {
                    kept += String(rest)
                    break
                }
            }
            if !(startedInComment && inComment) { visible.append(kept) }
        }
        return visible.joined(separator: "\n")
    }

    /// The first `<!--` of `text` that is not inside an inline code span: `` `<!--` `` is text, as in a renderer.
    private static func commentStart(in text: Substring) -> Range<Substring.Index>? {
        let spans = text.ranges(of: /`[^`]*`/)
        var from = text.startIndex
        while let start = text[from...].range(of: "<!--") {
            if !spans.contains(where: { $0.contains(start.lowerBound) }) { return start }
            from = start.upperBound
        }
        return nil
    }

    /// The inline code spans of `markdown`, outside fenced code and comments, without their backticks. A span needs both of
    /// its backticks on one line.
    static func codeSpans(in markdown: String) -> [String] {
        withoutFencesAndComments(markdown).matches(of: /`([^`\n]+)`/).map { String($0.output.1) }
    }

    // MARK: - Prose

    /// The prose of `markdown`: the text a reader reads. Fenced code, comments, inline code, reference definitions, link
    /// targets, web addresses and HTML tags are not prose; the words of a link are.
    static func prose(_ markdown: String) -> String {
        var prose = withoutFencesAndComments(markdown)
        prose = prose.replacingOccurrences(of: #"`[^`\n]*`"#, with: " ", options: .regularExpression)
        prose = withoutReferenceDefinitions(prose)
        for (pattern, replacement) in [(#"\]\([^)\n]*\)"#, "]"), (#"</?[A-Za-z][^>\n]*>"#, " "), (#"https?://\S+"#, " ")] {
            prose = prose.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return prose
    }

    // MARK: - Blocks

    /// A heading, a table row, a list item or a paragraph of a document, with its text on one line.
    struct Block: Equatable, Sendable {
        enum Kind: Sendable {
            case heading, tableRow, listItem, paragraph
        }

        let kind: Kind
        var text: String
    }

    /// The blocks of `markdown`, in the order they are written, read from its prose. The lines of a paragraph or a list item
    /// are joined with a space; the markers of a quote are dropped; a heading, a list marker or a table row ends the block
    /// before it; the separator row of a table is not a block.
    static func blocks(in markdown: String) -> [Block] {
        var blocks: [Block] = []
        var open: Block?
        func close() {
            if let block = open { blocks.append(block) }
            open = nil
        }

        for raw in lines(of: prose(markdown)) {
            var line = collapsed(raw)
            while line.hasPrefix(">") { line = collapsed(line.dropFirst()) }
            if line.isEmpty {
                close()
            } else if headingLevel(of: line) != nil {
                close()
                blocks.append(Block(kind: .heading, text: line))
            } else if line.hasPrefix("|") {
                close()
                if !isTableSeparator(line) { blocks.append(Block(kind: .tableRow, text: line)) }
            } else if line.prefixMatch(of: /([-*+]|\d{1,9}[.)])( |$)/) != nil {
                close()
                open = Block(kind: .listItem, text: line)
            } else if var block = open {
                block.text += " " + line
                open = block
            } else {
                open = Block(kind: .paragraph, text: line)
            }
        }
        close()
        return blocks
    }

    /// Whether a line is the separator row of a table: bars, dashes, colons and spaces, with at least one dash.
    static func isTableSeparator(_ row: String) -> Bool {
        row.contains("-") && row.allSatisfy { "|-: \t".contains($0) }
    }

    /// `text` without the leading and trailing space, and with every run of white space reduced to one space.
    private static func collapsed(_ text: some StringProtocol) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    // MARK: - Links

    /// The files that the links of `markdown` point at, as the text writes them: without a leading `./`, an `<...>` wrapper, a
    /// fragment or a title, and with a trailing `/` kept. A web address, a `mailto:` link and a link to a heading of the same
    /// page are not files. Links in comments, code spans and fences are not links. A reference definition (`[label]: file`)
    /// links its file once the text uses its label, as `[text][label]`, `[label][]` or `[label]`, in any case.
    static func relativeLinkTargets(in markdown: String) -> [String] {
        let visible = withoutFencesAndComments(markdown).replacingOccurrences(of: #"`[^`\n]*`"#, with: " ", options: .regularExpression)
        let definitions = lines(of: visible).compactMap(referenceDefinition)
        let text = withoutReferenceDefinitions(visible)

        var targets = text.matches(of: /\]\(([^)\n]*)\)/).compactMap { fileTarget(String($0.output.1)) }
        let used = usedLabels(in: text)
        targets += definitions.filter { used.contains($0.label) }.compactMap { fileTarget($0.target) }
        return targets
    }

    /// The file a raw link target names, or nil when it names none.
    private static func fileTarget(_ raw: String) -> String? {
        var target = raw.trimmingCharacters(in: .whitespaces)
        if target.hasPrefix("<"), let close = target.firstIndex(of: ">") {
            target = String(target[target.index(after: target.startIndex)..<close])
        } else {
            target = String(target.prefix { !$0.isWhitespace })
        }
        target = String(target.prefix { $0 != "#" && $0 != "?" })
        while target.hasPrefix("./") { target.removeFirst(2) }
        guard !target.isEmpty, !target.hasPrefix("//"), target.prefixMatch(of: /[A-Za-z][A-Za-z0-9+.\-]*:/) == nil else { return nil }
        return target
    }

    /// The label and the target of a reference definition line (`[label]: target`).
    private static func referenceDefinition(_ line: Substring) -> (label: String, target: String)? {
        guard let match = line.prefixMatch(of: /[ ]{0,3}\[([^\]\n]+)\]:[ \t]*(\S+)/) else { return nil }
        return (normalized(match.output.1), String(match.output.2))
    }

    /// `text` with its reference definition lines emptied.
    private static func withoutReferenceDefinitions(_ text: String) -> String {
        lines(of: text).map { referenceDefinition($0) == nil ? String($0) : "" }.joined(separator: "\n")
    }

    /// The labels a text uses: `[text][label]`, `[label][]` and `[label]` not followed by a target, a label or a colon.
    private static func usedLabels(in text: String) -> Set<String> {
        var used = Set<String>()
        for match in text.matches(of: /\[([^\]\n]*)\]\[([^\]\n]*)\]/) {
            used.insert(normalized(match.output.2.isEmpty ? match.output.1 : match.output.2))
        }
        for match in text.matches(of: /\[([^\]\n]+)\](?![\[(:])/) {
            used.insert(normalized(match.output.1))
        }
        return used
    }

    private static func normalized(_ label: Substring) -> String {
        collapsed(label).lowercased()
    }
}
