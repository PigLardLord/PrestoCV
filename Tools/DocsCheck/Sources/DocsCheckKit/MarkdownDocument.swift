/// What the checks need from a Markdown file: its links and code spans with their lines, its headings, and the
/// anchors its HTML defines. Fenced code, HTML comments and the inside of code spans are skipped, because none of
/// them holds a link. It reads CommonMark's inline links, images and link definitions, and ATX headings. Indented
/// code is read like any other text, since reading more can only add findings.
struct MarkdownDocument: Sendable {
    struct Link: Hashable, Sendable {
        let line: Int
        let destination: String
    }

    struct CodeSpan: Hashable, Sendable {
        let line: Int
        let text: String
    }

    struct Heading: Hashable, Sendable {
        let line: Int
        let text: String
    }

    struct Line: Hashable, Sendable {
        let number: Int
        let text: String
    }

    /// The lines that are not inside a fenced code block, fences themselves excluded.
    private(set) var proseLines: [Line] = []
    private(set) var links: [Link] = []
    private(set) var codeSpans: [CodeSpan] = []
    private(set) var headings: [Heading] = []
    /// The `id` and `name` attributes of HTML tags, in document order. A link may point at any of them.
    private(set) var explicitAnchors: [String] = []

    /// Headings longer than this many characters are reported, not read.
    static let maximumHeadingLength = 1_000

    /// A heading that is not read, because reading it could take unbounded time or stack.
    struct Problem: Hashable, Sendable {
        enum Reason: Hashable, Sendable {
            case tooLong
            case tooNested
        }

        let line: Int
        let reason: Reason
    }

    private(set) var problems: [Problem] = []

    /// The anchor of every heading that is read, in document order, as GitHub numbers them. A heading that is not
    /// read (see `problems`) has none and does not count in the numbering.
    private(set) var anchors: [String] = []

    init(text: String) {
        var fence: Fence?
        var inComment = false
        let lines = Self.lines(of: text)
        let lookahead = CommentLookahead(lines: lines)
        for (offset, rawLine) in lines.enumerated() {
            let number = offset + 1
            if let open = fence {
                if open.isClosed(by: rawLine) { fence = nil }
                continue
            }
            if !inComment, let opening = Fence(opening: rawLine) {
                fence = opening
                continue
            }
            var inline = InlineScan(line: rawLine, startsInComment: inComment, midLineOpenerMaySpan: false)
            if inline.unclosedMidLineOpener, lookahead.closes(after: offset) {
                inline = InlineScan(line: rawLine, startsInComment: inComment, midLineOpenerMaySpan: true)
            }
            inComment = inline.endsInComment
            let line = inline.uncommented
            proseLines.append(Line(number: number, text: line))
            if let heading = Self.heading(in: line, number: number) { headings.append(heading) }
            codeSpans += inline.codeSpans.map { CodeSpan(line: number, text: $0) }
            if let destination = Self.definitionDestination(in: line) {
                links.append(Link(line: number, destination: destination))
            }
            links += inline.destinations.map { Link(line: number, destination: $0) }
            explicitAnchors += inline.explicitAnchors
        }
        var slugger = HeadingSlugger()
        for heading in headings {
            guard heading.text.unicodeScalars.count <= Self.maximumHeadingLength else {
                problems.append(Problem(line: heading.line, reason: .tooLong))
                continue
            }
            guard let slug = slugger.slug(forHeading: heading.text) else {
                problems.append(Problem(line: heading.line, reason: .tooNested))
                continue
            }
            anchors.append(slug)
        }
    }

    // MARK: Lines

    private static func lines(of text: String) -> [String] {
        text.utf8.split(separator: 0x0A, omittingEmptySubsequences: false).map { bytes in
            let trimmed = bytes.last == 0x0D ? bytes.dropLast() : bytes
            return String(decoding: trimmed, as: UTF8.self)
        }
    }

    /// Whether a comment opened in the middle of a line is closed by a later line before the paragraph ends, as it
    /// must be to belong to its paragraph. The answer for every line is computed once, in a backward pass, so that
    /// asking is a lookup and a document of many such lines is read in linear time.
    private struct CommentLookahead {
        private var nextParagraphEnd: [Int]
        private var nextCloser: [Int]

        init(lines: [String]) {
            nextParagraphEnd = [Int](repeating: Int.max, count: lines.count)
            nextCloser = nextParagraphEnd
            var paragraphEnd = Int.max
            var closer = Int.max
            for index in lines.indices.reversed() {
                if MarkdownDocument.endsParagraph(lines[index]) { paragraphEnd = index }
                if lines[index].contains("-->") { closer = index }
                nextParagraphEnd[index] = paragraphEnd
                nextCloser[index] = closer
            }
        }

        /// Whether a line after `offset` holds `-->` before the first line after it that ends the paragraph.
        func closes(after offset: Int) -> Bool {
            let next = offset + 1
            return next < nextCloser.count && nextCloser[next] < nextParagraphEnd[next]
        }
    }

    /// A line that ends the paragraph before it: a blank line, a fence, an ATX heading, or a line that starts a
    /// comment of its own.
    fileprivate static func endsParagraph(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" } || Fence(opening: line) != nil || heading(in: line, number: 0) != nil || startsComment(line)
    }

    /// Whether a line starts, after at most three spaces, with `<!--`.
    private static func startsComment(_ line: String) -> Bool {
        let indentation = line.prefix { $0 == " " }.count
        return indentation <= 3 && line.dropFirst(indentation).hasPrefix("<!--")
    }

    // MARK: Fences

    private struct Fence {
        let marker: Character
        let length: Int

        /// A line of three or more backticks or tildes, with an info string that has no backtick if the marker is one.
        init?(opening line: String) {
            let stripped = line.drop { $0 == " " || $0 == "\t" }
            guard let marker = stripped.first, marker == "`" || marker == "~" else { return nil }
            let length = stripped.prefix { $0 == marker }.count
            guard length >= 3 else { return nil }
            if marker == "`", stripped.dropFirst(length).contains("`") { return nil }
            self.marker = marker
            self.length = length
        }

        func isClosed(by line: String) -> Bool {
            let stripped = line.drop { $0 == " " || $0 == "\t" }
            let run = stripped.prefix { $0 == marker }.count
            return run >= length && stripped.dropFirst(run).allSatisfy { $0 == " " || $0 == "\t" }
        }
    }

    // MARK: Headings

    private static func heading(in line: String, number: Int) -> Heading? {
        let indentation = line.prefix { $0 == " " }.count
        guard indentation <= 3 else { return nil }
        let rest = line.dropFirst(indentation)
        let level = rest.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let content = rest.dropFirst(level)
        guard content.isEmpty || content.first == " " || content.first == "\t" else { return nil }
        var text = content.drop { $0 == " " || $0 == "\t" }
        while let last = text.last, last == " " || last == "\t" { text = text.dropLast() }
        let closing = text.reversed().prefix { $0 == "#" }.count
        if closing > 0 {
            let before = text.dropLast(closing)
            if before.isEmpty || before.last == " " || before.last == "\t" {
                text = before
                while let last = text.last, last == " " || last == "\t" { text = text.dropLast() }
            }
        }
        return Heading(line: number, text: String(text))
    }

    // MARK: Link definitions

    /// The destination of a `[label]: destination` line, which is not a footnote definition.
    private static func definitionDestination(in line: String) -> String? {
        let scalars = Array(line.unicodeScalars)
        var index = 0
        while index < scalars.count, scalars[index] == " " { index += 1 }
        guard index <= 3, index < scalars.count, scalars[index] == "[", index + 1 < scalars.count, scalars[index + 1] != "^" else { return nil }
        index += 1
        while index < scalars.count, scalars[index] != "]" {
            if scalars[index] == "\\" { index += 1 }
            index += 1
        }
        guard index + 1 < scalars.count, scalars[index + 1] == ":" else { return nil }
        index += 2
        while index < scalars.count, scalars[index] == " " || scalars[index] == "\t" { index += 1 }
        guard let destination = InlineScan.destination(in: scalars, from: index, terminatedByParenthesis: false) else { return nil }
        // After the destination comes the end of the line or a title; anything else makes the line prose.
        var after = destination.end
        while after < scalars.count, scalars[after] == " " || scalars[after] == "\t" { after += 1 }
        guard after == scalars.count || (after > destination.end && ["\"", "'", "("].contains(scalars[after])) else { return nil }
        return destination.text
    }
}

/// One line of inline Markdown: the contents of its code spans, the destinations of its links, the anchors its HTML
/// tags define, and the line without its HTML comments. A comment may begin on an earlier line or end on a later one.
private struct InlineScan {
    private(set) var codeSpans: [String] = []
    private(set) var destinations: [String] = []
    private(set) var explicitAnchors: [String] = []
    private(set) var uncommented = ""
    private(set) var endsInComment = false
    /// A `<!--` in the middle of the line, with no `-->` after it on the line, was read as text.
    private(set) var unclosedMidLineOpener = false

    /// A comment that closes on its line is a comment. One that does not spans lines if its line starts with it
    /// (after at most three spaces, an HTML block), or, with `midLineOpenerMaySpan`, if it opens in the middle of
    /// a line. Otherwise it is text.
    init(line: String, startsInComment: Bool, midLineOpenerMaySpan: Bool) {
        let scalars = Array(line.unicodeScalars)
        endsInComment = startsInComment
        let (uncommentedScalars, visible) = mask(scalars, midLineOpenerMaySpan: midLineOpenerMaySpan)
        uncommented = Self.string(uncommentedScalars)
        var index = 0
        while index < visible.count {
            if visible[index] == "\\" {
                index += 2
            } else if visible[index] == "]", index + 1 < visible.count, visible[index + 1] == "(" {
                if let destination = Self.destination(in: visible, from: index + 2, terminatedByParenthesis: true) {
                    destinations.append(destination.text)
                    index = destination.end
                } else {
                    index += 2
                }
            } else {
                index += 1
            }
        }
        explicitAnchors = Self.anchors(inTagsOf: visible)
    }

    /// The line without its HTML comments, and the line with every comment and every code span replaced by spaces,
    /// so that positions stay the same. Code spans are recorded. Whichever of a code span and a comment starts
    /// first wins, as in CommonMark.
    private mutating func mask(_ scalars: [Unicode.Scalar], midLineOpenerMaySpan: Bool) -> (uncommented: [Unicode.Scalar], visible: [Unicode.Scalar]) {
        var inComment = [Bool](repeating: false, count: scalars.count)
        var visible = scalars
        func blank(_ range: Range<Int>) {
            for position in range { inComment[position] = true; visible[position] = " " }
        }
        var commentStart = 0
        var noCloserLeft = false
        var index = 0
        while index < scalars.count {
            if endsInComment {
                if let end = Self.find(Self.commentClosing, in: scalars, from: index) {
                    blank(commentStart..<(end + 3))
                    index = end + 3
                    endsInComment = false
                } else {
                    index = scalars.count
                }
                continue
            }
            if scalars[index] == "\\" {
                index += 2
                continue
            }
            if Self.hasPrefix(Self.commentOpening, in: scalars, at: index) {
                // Once a search finds no `-->`, none from a later position will, so the rest of the line is not searched again.
                let end = noCloserLeft ? nil : Self.find(Self.commentClosing, in: scalars, from: index + 4)
                if end == nil { noCloserLeft = true }
                if let end {
                    blank(index..<(end + 3))
                    index = end + 3
                } else if midLineOpenerMaySpan || Self.startsLine(scalars, at: index) {
                    commentStart = index
                    endsInComment = true
                    index = scalars.count
                } else {
                    unclosedMidLineOpener = true
                    index += 4
                }
                continue
            }
            guard scalars[index] == "`" else {
                index += 1
                continue
            }
            let opening = Self.run(of: "`", in: scalars, at: index)
            var scan = index + opening
            var closed = false
            while scan < scalars.count {
                guard scalars[scan] == "`" else {
                    scan += 1
                    continue
                }
                let closing = Self.run(of: "`", in: scalars, at: scan)
                if closing == opening {
                    var content = Array(scalars[(index + opening)..<scan])
                    if content.count > 1, content.first == " ", content.last == " ", content.contains(where: { $0 != " " }) {
                        content = Array(content.dropFirst().dropLast())
                    }
                    codeSpans.append(Self.string(content))
                    for position in index..<(scan + closing) { visible[position] = " " }
                    index = scan + closing
                    closed = true
                    break
                }
                scan += closing
            }
            if !closed { index += opening }
        }
        if endsInComment { blank(commentStart..<scalars.count) }
        let uncommented = scalars.indices.filter { !inComment[$0] }.map { scalars[$0] }
        return (uncommented, visible)
    }

    /// Whether only spaces, at most three, come before `index`.
    private static func startsLine(_ scalars: [Unicode.Scalar], at index: Int) -> Bool {
        index <= 3 && scalars[..<index].allSatisfy { $0 == " " }
    }

    private static let commentOpening: [Unicode.Scalar] = ["<", "!", "-", "-"]
    private static let commentClosing: [Unicode.Scalar] = ["-", "-", ">"]

    private static func hasPrefix(_ wanted: [Unicode.Scalar], in scalars: [Unicode.Scalar], at index: Int) -> Bool {
        index + wanted.count <= scalars.count && scalars[index..<(index + wanted.count)].elementsEqual(wanted)
    }

    private static func find(_ needle: [Unicode.Scalar], in scalars: [Unicode.Scalar], from start: Int) -> Int? {
        var index = start
        while index < scalars.count {
            if hasPrefix(needle, in: scalars, at: index) { return index }
            index += 1
        }
        return nil
    }

    // MARK: Explicit anchors

    /// The `id` and `name` attributes of the HTML tags that start and end on this line. Attribute names are matched
    /// whole and without regard to case; values are taken as written. The first tag that does not end within
    /// `maximumTagLength` scalars ends the scan of the line, so that a line of tags that never end is read once.
    private static func anchors(inTagsOf scalars: [Unicode.Scalar]) -> [String] {
        var anchors: [String] = []
        var index = 0
        while index < scalars.count {
            guard scalars[index] == "<", index + 1 < scalars.count, isASCIILetter(scalars[index + 1]) else {
                index += 1
                continue
            }
            guard let (found, end) = attributes(ofTagAt: index, in: scalars) else { break }
            anchors += found
            index = end
        }
        return anchors
    }

    /// A tag is read for at most this many scalars.
    static let maximumTagLength = 1_000

    /// The anchors of the tag that starts at `start` and the index after its `>`, or nil if the tag does not end on
    /// the line within `maximumTagLength` scalars.
    private static func attributes(ofTagAt start: Int, in scalars: [Unicode.Scalar]) -> ([String], Int)? {
        let limit = min(scalars.count, start + maximumTagLength)
        var index = start + 1
        while index < limit, isNameScalar(scalars[index]) { index += 1 }
        var anchors: [String] = []
        while index < limit {
            while index < limit, isSpace(scalars[index]) || scalars[index] == "/" { index += 1 }
            guard index < limit else { return nil }
            if scalars[index] == ">" { return (anchors, index + 1) }
            let nameStart = index
            while index < limit, !isSpace(scalars[index]), !"=>/".unicodeScalars.contains(scalars[index]) { index += 1 }
            guard index > nameStart else { return nil }
            let name = string(Array(scalars[nameStart..<index])).lowercased()
            while index < limit, isSpace(scalars[index]) { index += 1 }
            guard index < limit, scalars[index] == "=" else { continue }
            index += 1
            while index < limit, isSpace(scalars[index]) { index += 1 }
            guard index < limit else { return nil }
            var value: [Unicode.Scalar] = []
            if scalars[index] == "\"" || scalars[index] == "'" {
                let quote = scalars[index]
                index += 1
                while index < limit, scalars[index] != quote { value.append(scalars[index]); index += 1 }
                guard index < limit else { return nil }
                index += 1
            } else {
                while index < limit, !isSpace(scalars[index]), scalars[index] != ">" { value.append(scalars[index]); index += 1 }
            }
            if (name == "id" || name == "name"), !value.isEmpty { anchors.append(string(value)) }
        }
        return nil
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 0x41 && scalar.value <= 0x5A) || (scalar.value >= 0x61 && scalar.value <= 0x7A)
    }

    private static func isNameScalar(_ scalar: Unicode.Scalar) -> Bool {
        isASCIILetter(scalar) || (scalar.value >= 0x30 && scalar.value <= 0x39) || scalar == "-"
    }

    private static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t"
    }

    // MARK: Destinations

    /// The link destination starting at `start`: `<...>` or a run without whitespace. Inside a link, a `)` that does not
    /// match an earlier `(` ends it. Returns nil for an empty destination. `end` is where the destination stops, so a
    /// scan can continue after it instead of reading it again.
    static func destination(in scalars: [Unicode.Scalar], from start: Int, terminatedByParenthesis: Bool) -> (text: String, end: Int)? {
        var index = start
        while index < scalars.count, scalars[index] == " " || scalars[index] == "\t" { index += 1 }
        var result: [Unicode.Scalar] = []
        if index < scalars.count, scalars[index] == "<" {
            index += 1
            while index < scalars.count, scalars[index] != ">" { result.append(scalars[index]); index += 1 }
            if index < scalars.count { index += 1 }
        } else {
            var depth = 0
            while index < scalars.count {
                let scalar = scalars[index]
                if scalar == " " || scalar == "\t" { break }
                if scalar == "\\", index + 1 < scalars.count, Self.isASCIIPunctuation(scalars[index + 1]) {
                    result.append(scalars[index + 1])
                    index += 2
                    continue
                }
                if scalar == "(" { depth += 1 }
                if scalar == ")" {
                    if depth == 0, terminatedByParenthesis { break }
                    depth -= 1
                }
                result.append(scalar)
                index += 1
            }
        }
        return result.isEmpty ? nil : (string(result), index)
    }

    private static func run(of scalar: Unicode.Scalar, in scalars: [Unicode.Scalar], at start: Int) -> Int {
        var end = start
        while end < scalars.count, scalars[end] == scalar { end += 1 }
        return end - start
    }

    private static func string(_ scalars: [Unicode.Scalar]) -> String {
        var text = ""
        text.unicodeScalars.append(contentsOf: scalars)
        return text
    }

    private static func isASCIIPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x21...0x2F, 0x3A...0x40, 0x5B...0x60, 0x7B...0x7E: return true
        default: return false
        }
    }
}
