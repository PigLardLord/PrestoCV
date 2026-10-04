/// What the checks need from a Markdown file: its links and code spans with their lines, and its headings. Fenced
/// code is skipped, and so is the inside of code spans, because neither holds links. It reads CommonMark's inline
/// links, images and link definitions, and ATX headings.
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
        let level: Int
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
        for (offset, line) in Self.lines(of: text).enumerated() {
            let number = offset + 1
            if let open = fence {
                if open.isClosed(by: line) { fence = nil }
                continue
            }
            if let opening = Fence(opening: line) {
                fence = opening
                continue
            }
            proseLines.append(Line(number: number, text: line))
            if let heading = Self.heading(in: line, number: number) { headings.append(heading) }
            let inline = InlineScan(line: line)
            codeSpans += inline.codeSpans.map { CodeSpan(line: number, text: $0) }
            if let destination = Self.definitionDestination(in: line) {
                links.append(Link(line: number, destination: destination))
            }
            links += inline.destinations.map { Link(line: number, destination: $0) }
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
        return Heading(line: number, level: level, text: String(text))
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
        return InlineScan.destination(in: scalars, from: index, terminatedByParenthesis: false)?.text
    }
}

/// One line of inline Markdown: the contents of its code spans, and the destinations of its links.
private struct InlineScan {
    private(set) var codeSpans: [String] = []
    private(set) var destinations: [String] = []

    init(line: String) {
        let scalars = Array(line.unicodeScalars)
        let visible = mask(codeSpansOf: scalars)
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
    }

    /// The line with every code span, delimiters included, replaced by spaces; the spans are recorded.
    private mutating func mask(codeSpansOf scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var visible = scalars
        var index = 0
        while index < scalars.count {
            if scalars[index] == "\\" {
                index += 2
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
        return visible
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
