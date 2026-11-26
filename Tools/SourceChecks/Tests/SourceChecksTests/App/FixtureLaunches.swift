import Foundation

/// The launches of one file of the UI tests over a folder of the fixture, read launch by launch from its code.
///
/// A launch is a statement that adds to `launchArguments` (`+=`, `=`, `append`, `insert`): from that word to the end of its
/// expression, which may run over several lines. An argument of a fixture folder (`-PrestoCVNextEmptyStorage`,
/// `-PrestoCVNextStorage`) is read where it is written:
/// - in a launch, which then passes `-PrestoCVNextReadyDesigns` as well;
/// - in a value of the file (`let storage = [...]`, or a parameter's default), which a launch of the file uses by its name;
///   every launch that names the value passes the argument;
/// - anywhere else, such as a function that returns it or a value no launch of the file names, it is a launch the check
///   cannot read, and the check fails, so a launch assembled out of its sight is never taken as one that passes.
///
/// It reads the code without its comments (`SwiftCode`), so an argument in a comment neither launches nor passes.
struct FixtureLaunches {
    static let readyDesigns = "-PrestoCVNextReadyDesigns"
    static let storageArguments = ["-PrestoCVNextEmptyStorage", "-PrestoCVNextStorage"]

    private let code: [Unicode.Scalar]
    private let skeleton: [Unicode.Scalar]
    /// The launches of the file, as ranges of its code
    private let launches: [Range<Int>]

    init(_ source: String) {
        let swift = SwiftCode(source)
        code = Array(swift.code.joined(separator: "\n").unicodeScalars)
        skeleton = Array(swift.skeleton.joined(separator: "\n").unicodeScalars)
        launches = Self.launches(in: skeleton)
    }

    // MARK: - The rule

    /// What breaks the rule, one line of the file each
    func problems() -> [String] {
        var problems: [String] = []
        for launch in launches where holdsFolder(launch) && !passes(launch) {
            problems.append("line \(line(of: launch.lowerBound)): a launch over a folder without \(Self.readyDesigns)")
        }
        for folder in folders() where !launches.contains(where: { $0.contains(folder) }) {
            if let problem = problem(ofValueAt: folder) { problems.append("line \(line(of: folder)): \(problem)") }
        }
        return problems
    }

    /// What is wrong with a folder written outside the launches, or nil when every launch that uses it passes the argument
    private func problem(ofValueAt folder: Int) -> String? {
        guard let name = value(holding: folder) else {
            return "a folder the check cannot tie to a launch of this file"
        }
        let using = launches.filter { names(name, $0) }
        if using.isEmpty {
            return "a folder in `\(name)`, which no launch of this file names"
        }
        if using.contains(where: { !passes($0) }) {
            return "a folder in `\(name)`, which a launch of this file uses without \(Self.readyDesigns)"
        }
        return nil
    }

    // MARK: - Reading the code

    private func holdsFolder(_ launch: Range<Int>) -> Bool {
        folders().contains { launch.contains($0) }
    }

    private func passes(_ launch: Range<Int>) -> Bool {
        Self.positions(of: Self.literal(Self.readyDesigns), in: code).contains { launch.contains($0) }
    }

    /// Where the arguments of a fixture folder are written, as positions of their opening quote
    private func folders() -> [Int] {
        Self.storageArguments.flatMap { Self.positions(of: Self.literal($0), in: code) }.sorted()
    }

    /// The name of the value whose expression holds the literal at `position`: the literal, or the array literals around
    /// it, is the right-hand side of `name =` or `name: Type =`.
    private func value(holding position: Int) -> String? {
        var start = position
        while let opener = innermostOpener(before: start), skeleton[opener] == "[" { start = opener }
        let prefix = String(String.UnicodeScalarView(skeleton[max(0, start - 160)..<start]))
        let range = NSRange(prefix.startIndex..., in: prefix)
        guard let match = Self.binding.firstMatch(in: prefix, range: range),
            let name = Range(match.range(at: 1), in: prefix)
        else { return nil }
        return String(prefix[name])
    }

    private func names(_ name: String, _ launch: Range<Int>) -> Bool {
        let text = String(String.UnicodeScalarView(skeleton[launch]))
        let word = try! NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: name))\\b")
        return word.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func innermostOpener(before position: Int) -> Int? {
        var depth = 0
        var index = position - 1
        while index >= 0 {
            switch skeleton[index] {
            case ")", "]", "}": depth += 1
            case "(", "[", "{":
                if depth == 0 { return index }
                depth -= 1
            default: break
            }
            index -= 1
        }
        return nil
    }

    private func line(of position: Int) -> Int {
        code[..<position].filter { $0 == "\n" }.count + 1
    }

    /// `name =` or `name: Type =` at the end of the text, and not `==`, `!=`, `<=`, `>=` or a compound assignment
    private static let binding = try! NSRegularExpression(
        pattern: #"([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=,(){}]*)?(?<![=!<>+\-*/])=\s*$"#)

    // MARK: - The launches

    private static func launches(in skeleton: [Unicode.Scalar]) -> [Range<Int>] {
        positions(of: "launchArguments", in: skeleton).compactMap { start in
            if start > 0, isIdentifier(skeleton[start - 1]) { return nil }
            guard let body = operatorEnd(in: skeleton, after: start + "launchArguments".unicodeScalars.count) else {
                return nil
            }
            return start..<expressionEnd(in: skeleton, from: body)
        }
    }

    /// The end of `+=`, `=`, `.append(` or `.insert(` right after `launchArguments`, or nil for a read of the arguments
    private static func operatorEnd(in text: [Unicode.Scalar], after index: Int) -> Int? {
        var index = index
        while index < text.count, text[index] == " " { index += 1 }
        for mutation in ["+=", ".append(", ".insert("] where matches(mutation, in: text, at: index) {
            return index + mutation.unicodeScalars.count
        }
        if matches("=", in: text, at: index), !matches("==", in: text, at: index) { return index + 1 }
        return nil
    }

    /// The end of the expression that starts at `index`: a line break outside brackets ends it, unless the line ends with
    /// an operator or a comma or the next one starts with one; a `;` or a closing bracket of the code around it ends it too.
    private static func expressionEnd(in text: [Unicode.Scalar], from index: Int) -> Int {
        var depth = 0
        var index = index
        while index < text.count {
            switch text[index] {
            case "(", "[", "{": depth += 1
            case ")", "]", "}":
                depth -= 1
                if depth < 0 { return index }
            case ";" where depth == 0: return index
            case "\n" where depth == 0:
                let before = text[..<index].last { $0 != " " }
                let after = text[(index + 1)...].first { $0 != " " && $0 != "\n" }
                let joins: Set<Unicode.Scalar> = ["+", ",", "=", "."]
                if !(before.map(joins.contains) ?? false) && !(after.map(joins.contains) ?? false) { return index }
            default: break
            }
            index += 1
        }
        return index
    }

    // MARK: - Text

    private static func literal(_ argument: String) -> String { "\"\(argument)\"" }

    private static func isIdentifier(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || CharacterSet.alphanumerics.contains(scalar)
    }

    private static func matches(_ needle: String, in text: [Unicode.Scalar], at index: Int) -> Bool {
        let needle = Array(needle.unicodeScalars)
        return index + needle.count <= text.count && Array(text[index..<index + needle.count]) == needle
    }

    private static func positions(of needle: String, in text: [Unicode.Scalar]) -> [Int] {
        let needle = Array(needle.unicodeScalars)
        guard let first = needle.first, needle.count <= text.count else { return [] }
        return (0...(text.count - needle.count)).filter { index in
            text[index] == first && Array(text[index..<index + needle.count]) == needle
        }
    }
}
