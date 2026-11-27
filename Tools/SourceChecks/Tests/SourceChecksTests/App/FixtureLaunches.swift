import Foundation

/// The launches of one file of the UI tests over a folder of the fixture, read launch by launch from its code.
///
/// A launch is a statement that adds to `launchArguments` (`+=`, `=`, `append`, `insert`): from that word to the end of its
/// expression, which may run over several lines. An argument of a fixture folder (`-PrestoCVNextEmptyStorage`,
/// `-PrestoCVNextStorage`) is read where it is written:
/// - in a launch, which then passes `-PrestoCVNextReadyDesigns` as well, on every run: as the whole argument it appends or
///   inserts, or as an element of its own in an array the launch adds as a whole, and not under a condition
///   (`ready ? […] : []`, `?? […]`), joined to another string (`… + "-PrestoCVNextReadyDesigns"`) or inside a call or a
///   bracket the check cannot read (`[…].filter { … }`);
/// - in a value of the file (`let storage = [...]`, or a parameter's default), which the check follows by its name, value
///   by value: into the launches that name it, into the values it goes into (`let copied = storage`, `all = storage + […]`,
///   `arguments.append(contentsOf: storage)`) and into the parameters it is passed to (`launch(storage: storage)`); every
///   launch it reaches passes the argument;
/// - anywhere else, such as a function that returns it, a value no launch of the file names, or a value used where the
///   check cannot follow it (`Self.extended(storage)`), it is a launch the check cannot read, and the check fails, so a
///   launch assembled out of its sight is never taken as one that passes.
///
/// It reads the code without its comments (`SwiftCode`), so an argument in a comment neither launches nor passes. It
/// follows names, not scopes: two values of one name in a file are read as one value.
struct FixtureLaunches {
    static let readyDesigns = "-PrestoCVNextReadyDesigns"
    static let storageArguments = ["-PrestoCVNextEmptyStorage", "-PrestoCVNextStorage"]

    private let code: [Unicode.Scalar]
    private let skeleton: [Unicode.Scalar]
    /// The launches of the file, as ranges of its code
    private let launches: [Range<Int>]
    /// The values of the file that receive an expression
    private let mutations: [Mutation]
    /// The names the parameters of the file's functions take inside them, by their labels
    private let parameters: [String: [String]]

    init(_ source: String) {
        let swift = SwiftCode(source)
        code = Array(swift.code.joined(separator: "\n").unicodeScalars)
        skeleton = Array(swift.skeleton.joined(separator: "\n").unicodeScalars)
        launches = Self.launches(in: skeleton)
        mutations = Self.mutations(in: skeleton)
        parameters = Self.parameters(in: skeleton)
    }

    // MARK: - The rule

    /// What breaks the rule, one line of the file each, in the order of the lines
    func problems() -> [String] {
        var problems: Set<Problem> = []
        for launch in launches where holdsFolder(launch) && !passes(launch) {
            problems.insert(Problem(line: line(of: launch.lowerBound), text: "a launch over a folder \(lack(in: launch))"))
        }
        for folder in folders() where !launches.contains(where: { $0.contains(folder) }) {
            problems.formUnion(self.problems(ofValueAt: folder))
        }
        return problems.sorted().map { "line \($0.line): \($0.text)" }
    }

    /// What is wrong with a folder written outside the launches: nothing when every launch its value reaches passes the
    /// argument and the check follows the value wherever it goes
    private func problems(ofValueAt folder: Int) -> [Problem] {
        let folderLine = line(of: folder)
        guard let seed = value(holding: folder) else {
            return [Problem(line: folderLine, text: "a folder the check cannot tie to a launch of this file")]
        }
        var problems: [Problem] = []
        var reachesALaunch = false
        var names = [seed]
        var followed: Set<String> = [seed]
        while let name = names.popLast() {
            for position in occurrences(of: name) {
                switch use(of: name, at: position) {
                case .launch(let launch):
                    reachesALaunch = true
                    if !passes(launch) {
                        let through = name == seed ? "" : " through `\(name)`"
                        problems.append(Problem(
                            line: folderLine,
                            text: "a folder in `\(seed)`, which a launch of this file uses\(through) \(lack(in: launch))"))
                    }
                case .into(let values):
                    names += values.filter { followed.insert($0).inserted }
                case .declared:
                    break
                case .unknown:
                    problems.append(Problem(
                        line: line(of: position), text: "a folder in `\(name)` goes where the check cannot follow it"))
                }
            }
        }
        if !reachesALaunch && problems.isEmpty {
            return [Problem(line: folderLine, text: "a folder in `\(seed)`, which no launch of this file names")]
        }
        return problems
    }

    private struct Problem: Hashable, Comparable {
        let line: Int
        let text: String

        static func < (lhs: Problem, rhs: Problem) -> Bool {
            (lhs.line, lhs.text) < (rhs.line, rhs.text)
        }
    }

    // MARK: - Following a value

    /// What a value does where its name is written
    private enum Use {
        /// It is part of a launch
        case launch(Range<Int>)
        /// It gets its name, or it receives something, which takes nothing out of it
        case declared
        /// It goes into other values or parameters of the file, by their names
        case into([String])
        /// It goes where the check cannot follow it
        case unknown
    }

    /// The use of the value `name` written at `position`
    private func use(of name: String, at position: Int) -> Use {
        if let launch = launches.first(where: { $0.contains(position) }) { return .launch(launch) }
        let receiving = mutations.filter { mutation in
            mutation.value.contains(position)
                && openers(from: mutation.value.lowerBound, to: position).allSatisfy { skeleton[$0] == "[" }
        }
        if !receiving.isEmpty { return .into(receiving.map(\.target)) }
        let end = position + name.unicodeScalars.count
        if Self.matches(":", in: skeleton, at: end), !Self.matches("::", in: skeleton, at: end), namesSomething(at: position) {
            return .declared
        }
        if Self.operatorEnd(in: skeleton, after: end) != nil { return .declared }
        if let label = label(ofArgumentAt: position, endingAt: end), let names = parameters[label] { return .into(names) }
        return .unknown
    }

    /// Whether the name at `position`, followed by a colon, names something there: a binding (`let storage: [String]`), a
    /// parameter (`func launch(with storage: [String])`) or an argument's label (`launch(storage: storage)`). Before a
    /// colon a name can also be a dictionary key or a branch of a condition, which are uses.
    private func namesSomething(at position: Int) -> Bool {
        guard let before = previousNonBlank(before: position) else { return false }
        guard Self.isIdentifier(skeleton[before]) else { return startsAnItem(at: position) }
        var start = before
        while start > 0, Self.isIdentifier(skeleton[start - 1]) { start -= 1 }
        let word = String(String.UnicodeScalarView(skeleton[start...before]))
        return word == "let" || word == "var" || startsAnItem(at: start)
    }

    /// Whether `position` starts an item of a list in parentheses, a parameter or an argument
    private func startsAnItem(at position: Int) -> Bool {
        guard let opener = innermostOpener(before: position), skeleton[opener] == "(",
            let before = previousNonBlank(before: position)
        else { return false }
        return skeleton[before] == "(" || skeleton[before] == ","
    }

    /// The label of the call argument `label: name` whose name is at `position`, as in `launch(storage: storage)`
    private func label(ofArgumentAt position: Int, endingAt end: Int) -> String? {
        guard let opener = innermostOpener(before: position), skeleton[opener] == "(",
            let after = nextNonBlank(from: end), skeleton[after] == "," || skeleton[after] == ")",
            let colon = previousNonBlank(before: position), skeleton[colon] == ":"
        else { return nil }
        var start = colon
        while start > 0, Self.isIdentifier(skeleton[start - 1]) { start -= 1 }
        guard start < colon, let before = previousNonBlank(before: start), skeleton[before] == "(" || skeleton[before] == ","
        else { return nil }
        return String(String.UnicodeScalarView(skeleton[start..<colon]))
    }

    /// Where `name` is written in the code as a whole word
    private func occurrences(of name: String) -> [Int] {
        let count = name.unicodeScalars.count
        return Self.positions(of: name, in: skeleton).filter { start in
            (start == 0 || !Self.isIdentifier(skeleton[start - 1]))
                && (start + count == skeleton.count || !Self.isIdentifier(skeleton[start + count]))
        }
    }

    /// The brackets opened from `start` on and still open at `end`, the innermost last
    private func openers(from start: Int, to end: Int) -> [Int] {
        var open: [Int] = []
        for index in start..<end {
            switch skeleton[index] {
            case "(", "[", "{": open.append(index)
            case ")", "]", "}": _ = open.popLast()
            default: break
            }
        }
        return open
    }

    // MARK: - Reading the code

    private func holdsFolder(_ launch: Range<Int>) -> Bool {
        folders().contains { launch.contains($0) }
    }

    /// Whether the launch passes the argument on every run (see the type's documentation)
    private func passes(_ launch: Range<Int>) -> Bool {
        mentions(of: launch).contains { isUnconditional($0, in: launch) }
    }

    /// How a launch that does not pass the argument on every run fails it: it leaves it out, or it writes it where the
    /// check cannot tell it is always passed
    private func lack(in launch: Range<Int>) -> String {
        mentions(of: launch).isEmpty
            ? "without \(Self.readyDesigns)"
            : "with \(Self.readyDesigns) where the check cannot tell it is passed on every run"
    }

    /// Where the launch writes the argument, wherever that is in its expression
    private func mentions(of launch: Range<Int>) -> [Int] {
        Self.positions(of: Self.literal(Self.readyDesigns), in: code).filter { launch.contains($0) }
    }

    /// Whether the argument written at `literal` is passed on every run of the launch: the launch's expression has no
    /// condition outside brackets, and the argument is the whole of it, or an element of its own in an array that is one
    /// of its operands. A string is never an operand of `+`, which would join it to another string into one argument
    private func isUnconditional(_ literal: Int, in launch: Range<Int>) -> Bool {
        let word = launch.lowerBound + "launchArguments".unicodeScalars.count
        guard let start = Self.operatorEnd(in: skeleton, after: word) else { return false }
        let body = start..<launch.upperBound
        guard !body.contains(where: { skeleton[$0] == "?" && openers(from: start, to: $0).isEmpty }) else { return false }
        let end = literal + Self.literal(Self.readyDesigns).unicodeScalars.count
        let open = openers(from: start, to: literal)
        if open.isEmpty { return isWhole(from: literal, to: end, of: body) }
        guard open.count == 1, skeleton[open[0]] == "[", let close = Self.closer(of: open[0], in: skeleton),
            let before = previousNonBlank(before: literal), let after = nextNonBlank(from: end)
        else { return false }
        return (skeleton[before] == "[" || skeleton[before] == ",") && (skeleton[after] == "," || skeleton[after] == "]")
            && isOperand(from: open[0], to: close + 1, of: body)
    }

    /// Whether the text from `start` to `end` is the whole of the launch's expression `body`
    private func isWhole(from start: Int, to end: Int, of body: Range<Int>) -> Bool {
        let opens = previousNonBlank(before: start).map { $0 < body.lowerBound } ?? true
        let closes = nextNonBlank(from: end).map { $0 >= body.upperBound } ?? true
        return opens && closes
    }

    /// Whether the text from `start` to `end` is an operand of its own in the launch's expression `body`: the whole of it,
    /// one of the operands that `+` adds together, or what `contentsOf:` adds
    private func isOperand(from start: Int, to end: Int, of body: Range<Int>) -> Bool {
        let opens = previousNonBlank(before: start).map { before in
            before < body.lowerBound || skeleton[before] == "+" || isContentsLabel(endingAt: before, in: body)
        } ?? true
        let closes = nextNonBlank(from: end).map { $0 >= body.upperBound || skeleton[$0] == "+" } ?? true
        return opens && closes
    }

    /// Whether the colon at `colon` ends the label `contentsOf:` that opens the launch's expression `body`
    private func isContentsLabel(endingAt colon: Int, in body: Range<Int>) -> Bool {
        let label = Array("contentsOf".unicodeScalars)
        let start = colon - label.count
        guard skeleton[colon] == ":", start >= body.lowerBound, Array(skeleton[start..<colon]) == label else { return false }
        return previousNonBlank(before: start).map { $0 < body.lowerBound } ?? true
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

    private func nextNonBlank(from index: Int) -> Int? {
        skeleton[index...].firstIndex { !Self.isBlank($0) }
    }

    private func previousNonBlank(before index: Int) -> Int? {
        skeleton[..<index].lastIndex { !Self.isBlank($0) }
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

    /// The end of `+=`, `=`, `.append(` or `.insert(` right after `launchArguments` or a value, or nil for a read of it
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
    /// an operator or the next one starts with one; a `;`, a `,` or a closing bracket of the code around it ends it too, so
    /// a parameter's default or one of several bindings ends where the next one starts.
    private static func expressionEnd(in text: [Unicode.Scalar], from index: Int) -> Int {
        var depth = 0
        var index = index
        while index < text.count {
            switch text[index] {
            case "(", "[", "{": depth += 1
            case ")", "]", "}":
                depth -= 1
                if depth < 0 { return index }
            case ";" where depth == 0, "," where depth == 0: return index
            case "\n" where depth == 0:
                let before = text[..<index].last { $0 != " " }
                let after = text[(index + 1)...].first { $0 != " " && $0 != "\n" }
                let joins: Set<Unicode.Scalar> = ["+", "=", "."]
                if !(before.map(joins.contains) ?? false) && !(after.map(joins.contains) ?? false) { return index }
            default: break
            }
            index += 1
        }
        return index
    }

    // MARK: - The values and the parameters

    /// A value of the file and the expression it receives
    private struct Mutation {
        let target: String
        let value: Range<Int>
    }

    /// `name = …`, `name: Type = …`, `name += …`, `name.append(…)` and `name.insert(…)`, except for `launchArguments`
    private static func mutations(in skeleton: [Unicode.Scalar]) -> [Mutation] {
        identifiers(in: skeleton).compactMap { word in
            let target = String(String.UnicodeScalarView(skeleton[word]))
            guard target != "launchArguments",
                let body = operatorEnd(in: skeleton, after: word.upperBound)
                    ?? typedBindingEnd(in: skeleton, after: word.upperBound)
            else { return nil }
            return Mutation(target: target, value: body..<expressionEnd(in: skeleton, from: body))
        }
    }

    /// The end of `: Type =` right after a name, or nil
    private static func typedBindingEnd(in text: [Unicode.Scalar], after index: Int) -> Int? {
        guard matches(":", in: text, at: index), !matches("::", in: text, at: index) else { return nil }
        let stops: Set<Unicode.Scalar> = ["=", ",", "(", ")", "{", "}", "\n", ";"]
        var index = index + 1
        while index < text.count, !stops.contains(text[index]) { index += 1 }
        guard matches("=", in: text, at: index), !matches("==", in: text, at: index) else { return nil }
        return index + 1
    }

    /// The labels of the parameters of the file's functions and initializers, each with the names it takes inside them:
    /// `func launch(with storage: [String])` gives `with` and `storage`. A parameter without a label (`_`) is left out.
    private static func parameters(in skeleton: [Unicode.Scalar]) -> [String: [String]] {
        var parameters: [String: [String]] = [:]
        for word in identifiers(in: skeleton) {
            let keyword = String(String.UnicodeScalarView(skeleton[word]))
            guard keyword == "func" || keyword == "init", word.lowerBound == 0 || skeleton[word.lowerBound - 1] != ".",
                let open = skeleton[word.upperBound...].firstIndex(where: { $0 == "(" || $0 == "{" }),
                skeleton[open] == "(", let close = closer(of: open, in: skeleton)
            else { continue }
            for parameter in parts(of: skeleton[(open + 1)..<close]) {
                let range = NSRange(parameter.startIndex..., in: parameter)
                guard let match = parameterName.firstMatch(in: parameter, range: range),
                    let label = Range(match.range(at: 1), in: parameter)
                else { continue }
                let inside = Range(match.range(at: 2), in: parameter).map { String(parameter[$0]) }
                if parameter[label] != "_" {
                    parameters[String(parameter[label]), default: []].append(inside ?? String(parameter[label]))
                }
            }
        }
        return parameters
    }

    /// The label of a parameter, and its name inside the function when it has one of its own
    private static let parameterName = try! NSRegularExpression(
        pattern: #"^\s*([A-Za-z_][A-Za-z0-9_]*)(?:\s+([A-Za-z_][A-Za-z0-9_]*))?\s*:"#)

    /// The closing bracket of the one at `open`
    private static func closer(of open: Int, in text: [Unicode.Scalar]) -> Int? {
        var depth = 0
        for index in open..<text.count {
            switch text[index] {
            case "(", "[", "{": depth += 1
            case ")", "]", "}":
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
        }
        return nil
    }

    /// The parts of a list between its commas outside brackets
    private static func parts(of list: ArraySlice<Unicode.Scalar>) -> [String] {
        var parts: [String] = []
        var part = String.UnicodeScalarView()
        var depth = 0
        for scalar in list {
            if scalar == ",", depth == 0 {
                parts.append(String(part))
                part = String.UnicodeScalarView()
                continue
            }
            if "([{".unicodeScalars.contains(scalar) { depth += 1 }
            if ")]}".unicodeScalars.contains(scalar) { depth -= 1 }
            part.append(scalar)
        }
        parts.append(String(part))
        return parts
    }

    /// The names written in the text: a letter or `_`, then letters, digits or `_`
    private static func identifiers(in text: [Unicode.Scalar]) -> [Range<Int>] {
        var words: [Range<Int>] = []
        var index = 0
        while index < text.count {
            guard isIdentifier(text[index]) else {
                index += 1
                continue
            }
            var end = index
            while end < text.count, isIdentifier(text[end]) { end += 1 }
            if !CharacterSet.decimalDigits.contains(text[index]) { words.append(index..<end) }
            index = end
        }
        return words
    }

    // MARK: - Text

    private static func literal(_ argument: String) -> String { "\"\(argument)\"" }

    private static func isIdentifier(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || CharacterSet.alphanumerics.contains(scalar)
    }

    private static func isBlank(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\n" || scalar == "\t"
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
