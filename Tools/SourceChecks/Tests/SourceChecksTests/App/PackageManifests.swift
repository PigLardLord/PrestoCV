import Foundation

// MARK: - Package manifests

/// The targets of the repository's local packages and what each depends on, read from the text of every `Package.swift`.
///
/// The text is read, not dumped with `swift package dump-package`: a manifest puts targets behind `#if !os(Linux)`
/// (the AI drafting and rendering adapters, the composition), so a dump on Linux, where the checks run, would hide code
/// that a Release build for iOS compiles. Reading the text sees every branch of an `#if`, and so reads a superset of one
/// platform's build, which is the safe side for a check of what ships.
///
/// The reader fails closed: a declaration or a dependency written in a shape it does not follow goes to `unreadable`,
/// which the release checks require empty, so a new way of writing a manifest fails them instead of shrinking what they
/// scan. It does not depend on spelling: white space before a call's parenthesis is read as none, and a declaration word
/// used in any other way than `.word(` is reported. It follows a string only in its plain form, opened and closed by a
/// quote on one line, and a slash outside a string only as the start of a `//` comment: a line that holds another form of
/// string, a block comment, a regex literal or any other slash, or that ends inside a string, is reported, as the reader
/// could take code there for text and skip a declaration.
struct PackageManifests {

    struct Target: Hashable {
        let package: String
        let name: String
        /// The folder of the sources, from the repository root
        let folder: String
        /// The targets of the same package this one depends on
        let targets: [String]
        /// The products of other packages (or the same one) this one depends on
        let products: [ProductReference]
    }

    struct ProductReference: Hashable {
        let name: String
        let package: String
    }

    /// The package's name and folder are the same for every package in this repository.
    private(set) var targets: [String: Target] = [:]
    /// Product name to the targets it is made of, per package
    private(set) var products: [String: [String: [String]]] = [:]
    /// What the reader does not follow, as `<package>: <text>`, with its white space folded to single spaces
    private(set) var unreadable: [String] = []

    /// The calls that declare a target. The reader follows a list of what it knows: `.target(` is read, `.testTarget(`
    /// is skipped as it never ships, and any other kind is reported, so a target of a kind it does not follow (in any
    /// branch of a condition) fails the checks instead of leaving the scan. Naming them all also keeps a
    /// `.target(name:)` among their dependencies from being taken for a declaration.
    private static let declarations = [
        ".target(", ".testTarget(", ".executableTarget(", ".macro(", ".plugin(", ".binaryTarget(", ".systemLibrary(",
    ]

    /// The words that declare a target or a product, or name one as a dependency. Each must be written `.word(`; any
    /// other use (an escaped name, a comment before the parenthesis, a reference to the function) is reported, so no
    /// spelling of a declaration leaves the scan.
    private static let declarationWords = [
        "target", "testTarget", "executableTarget", "macro", "plugin", "binaryTarget", "systemLibrary", "library", "product",
    ]

    init(packages: [String], read: (String) throws -> String) rethrows {
        for package in packages {
            let source = try read(package)
            for line in Self.stringsTheReaderDoesNotFollow(in: source) { report(line, in: package) }
            let text = Self.canonical(Self.withoutComments(source))
            for line in Self.declarationWordsOutsideCalls(in: text) { report(line, in: package) }
            let aliases = Self.aliases(in: text)
            for call in Self.calls(of: [".library("], in: text) { readLibrary(call.body, in: package) }
            for call in Self.calls(of: Self.declarations, in: text) {
                switch call.opening {
                case ".target(": readTarget(call.body, in: package, aliases: aliases)
                case ".testTarget(": continue
                default: report("\(call.opening)\(call.body))", in: package)
                }
            }
        }
    }

    static func key(_ package: String, _ target: String) -> String { "\(package)/\(target)" }

    /// The targets a product is made of, or nil when no package declares it.
    func targets(ofProduct product: ProductReference) -> [String]? { products[product.package]?[product.name] }

    /// Where a walk from `start` ends: every target reached, and every product no manifest declares.
    func reached(from start: [ProductReference]) -> (targets: [Target], unresolved: [ProductReference]) {
        var seen: [String: Target] = [:]
        var unresolved: [ProductReference] = []
        var pending: [(package: String, name: String)] = []
        func take(_ product: ProductReference) {
            guard let names = targets(ofProduct: product) else { unresolved.append(product); return }
            pending += names.map { (product.package, $0) }
        }
        start.forEach(take)
        while let next = pending.popLast() {
            let id = Self.key(next.package, next.name)
            guard seen[id] == nil else { continue }
            guard let target = targets[id] else { unresolved.append(ProductReference(name: next.name, package: next.package)); continue }
            seen[id] = target
            pending += target.targets.map { (target.package, $0) }
            target.products.forEach(take)
        }
        return (seen.values.sorted { $0.folder < $1.folder }, unresolved)
    }

    // MARK: Declarations

    /// `.library(name: "X", type: .dynamic, targets: ["A", "B"])`; a product declared again (in the other branch of an
    /// `#if`) reaches the targets of both.
    private mutating func readLibrary(_ body: String, in package: String) {
        let arguments = Self.arguments(of: body)
        guard let name = arguments["name"].flatMap(Self.name), let members = arguments["targets"].flatMap(Self.list) else {
            return report(".library(\(body))", in: package)
        }
        let names = members.compactMap(Self.name)
        guard names.count == members.count else { return report(".library(\(body))", in: package) }
        let earlier = products[package]?[name] ?? []
        products[package, default: [:]][name] = earlier + names.filter { !earlier.contains($0) }
    }

    /// `.target(name: "A", dependencies: [...], path: "Sources/Elsewhere")`; a target declared again (in the other
    /// branch of an `#if`) keeps the dependencies of both.
    private mutating func readTarget(_ body: String, in package: String, aliases: [String: [ProductReference]]) {
        let arguments = Self.arguments(of: body)
        guard let name = arguments["name"].flatMap(Self.name) else { return report(".target(\(body))", in: package) }
        var folder = "\(package)/Sources/\(name)"
        if let path = arguments["path"] {
            guard let literal = Self.literal(path) else { return report(".target(\(body))", in: package) }
            folder = "\(package)/\(literal)"
        }
        var local: [String] = []
        var external: [ProductReference] = []
        if let dependencies = arguments["dependencies"] {
            if let elements = Self.list(dependencies) {
                for element in elements {
                    switch Self.dependency(element, aliases: aliases) {
                    case .target(let target): local.append(target)
                    case .products(let found): external.append(contentsOf: found)
                    case .unknown: report(element, in: package)
                    }
                }
            } else {
                report("\(name) dependencies: \(dependencies)", in: package)
            }
        }
        let id = Self.key(package, name)
        if let earlier = targets[id] {
            guard earlier.folder == folder else {
                return report("\(name) declared at \(earlier.folder) and at \(folder)", in: package)
            }
            local = earlier.targets + local.filter { !earlier.targets.contains($0) }
            external = earlier.products + external.filter { !earlier.products.contains($0) }
        }
        targets[id] = Target(package: package, name: name, folder: folder, targets: local, products: external)
    }

    private enum Dependency {
        case target(String)
        /// One product, or every product an alias names across the branches of a condition
        case products([ProductReference])
        case unknown
    }

    /// `"B"`, `.target(name: "B")`, `.byName(name: "B")`, `.product(name: "C", package: "Other")` (each may carry a
    /// condition), or an alias.
    private static func dependency(_ element: String, aliases: [String: [ProductReference]]) -> Dependency {
        if let target = Self.name(element) { return .target(target) }
        if let named = aliases[element] { return .products(named) }
        guard let found = Self.call(element) else { return .unknown }
        let arguments = Self.arguments(of: found.body)
        guard let named = arguments["name"].flatMap(Self.name) else { return .unknown }
        switch found.function {
        case "target", "byName":
            return .target(named)
        case "product":
            guard let owner = arguments["package"].flatMap(Self.name) else { return .unknown }
            return .products([ProductReference(name: named, package: owner)])
        default:
            return .unknown
        }
    }

    /// `let logging = Target.Dependency.product(name: "Log", package: "Logs")`, or `let logging: Target.Dependency =
    /// .product(...)`, on one line or several. A name declared in several branches of a condition names the products of
    /// all of them. A name declared another way, in any branch, is not here, so its use is reported.
    private static func aliases(in text: String) -> [String: [ProductReference]] {
        let pattern = #"let\s+(\w+)\s*(?::\s*Target\.Dependency\s*)?=\s*(?:Target\.Dependency)?\.product\(\s*name:\s*"([\w-]+)"\s*,\s*package:\s*"([\w-]+)"\s*\)"#
        var found: [String: [ProductReference]] = [:]
        var readDeclarations: [String: Int] = [:]
        for match in matches(pattern, in: text) {
            let product = ProductReference(name: match[1], package: match[2])
            readDeclarations[match[0], default: 0] += 1
            if !found[match[0], default: []].contains(product) { found[match[0], default: []].append(product) }
        }
        var declarations: [String: Int] = [:]
        for match in matches(#"\b(?:let|var)\s+(\w+)"#, in: text) { declarations[match[0], default: 0] += 1 }
        return found.filter { name, _ in declarations[name] == readDeclarations[name] }
    }

    /// Reports a line once, though more than one rule may find it.
    private mutating func report(_ text: String, in package: String) {
        let entry = "\(package): \(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))"
        if !unreadable.contains(entry) { unreadable.append(entry) }
    }

    // MARK: Reading the text

    /// The text without `//` comments (a `//` inside a string literal stays).
    static func withoutComments(_ text: String) -> String {
        var result = ""
        var inString = false
        var iterator = text.makeIterator()
        var previous: Character?
        while let character = iterator.next() {
            if character == "\"" && previous != "\\" { inString.toggle() }
            if !inString && character == "/" && previous == "/" {
                result.removeLast()
                while let skipped = iterator.next(), skipped != "\n" {}
                result.append("\n")
                previous = nil
                continue
            }
            result.append(character)
            previous = character
        }
        return result
    }

    /// The lines whose strings the reader does not follow. It takes a string for the text between two quotes on one line,
    /// so it lists the forms that break that: a raw string (`#"`), a multi-line string (`"""`), an escaped backslash
    /// (`\\`), an interpolation (`\(`), a block comment (`/*`) and a regex literal (`#/`). On the other lines every
    /// string is a plain one, so walking a line from the left tells exactly what is inside a string up to the first slash
    /// outside one; the walk reports that slash unless it starts a `//` comment (a bare regex literal `/"/` could hide a
    /// declaration between two quotes on one line, and a division is reported with it), and reports a line that ends
    /// inside a string. No manifest uses any of them.
    static func stringsTheReaderDoesNotFollow(in source: String) -> [String] {
        let forms = ["#\"", "\"\"\"", "\\\\", "\\(", "/*", "#/"]
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        let withForms = lines.filter { line in forms.contains { line.contains($0) } }
        return withForms.map(String.init) + lines.filter { !walksToItsEnd(Array($0)) }.map(String.init)
    }

    /// Whether a line ends outside a string with no slash outside a string, but one that starts a `//` comment.
    private static func walksToItsEnd(_ line: [Character]) -> Bool {
        var inString = false
        for index in line.indices {
            let character = line[index]
            let previous = index > line.startIndex ? line[index - 1] : nil
            if character == "\"" && previous != "\\" { inString.toggle() }
            if !inString && character == "/" {
                return index + 1 < line.endIndex && line[index + 1] == "/"
            }
        }
        return !inString
    }

    /// The text with the white space between a member's name and its parenthesis taken out, outside string literals:
    /// `.target (name: "A")` and `.target` with `(name: "A")` on the next line read as `.target(name: "A")`.
    static func canonical(_ text: String) -> String {
        outsideStrings(text, emptying: false) { code in
            NSRegularExpression.compiled(#"\.(\w+)\s+\("#).stringByReplacingMatches(
                in: code, range: NSRange(code.startIndex..., in: code), withTemplate: ".$1("
            )
        }
    }

    /// The lines that use a declaration word, outside string literals, in another way than `.word(`.
    private static func declarationWordsOutsideCalls(in text: String) -> [String] {
        let words = declarationWords.joined(separator: "|")
        let misuse = NSRegularExpression.compiled(#"(?<![\w.])(?:"# + words + #")(?!\w)|(?<=\.)(?:"# + words + #")(?![\w(])"#)
        let code = outsideStrings(text, emptying: true) { $0 }.split(separator: "\n", omittingEmptySubsequences: false)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return zip(code, lines).compactMap { code, line in
            let code = String(code)
            return misuse.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) == nil ? nil : String(line)
        }
    }

    /// The text with `transform` applied to each part outside string literals. The literals are kept, or, when
    /// `emptying`, each of their characters but a line break becomes a space, so the lines stay where they were.
    private static func outsideStrings(_ text: String, emptying: Bool, _ transform: (String) -> String) -> String {
        var result = ""
        var code = ""
        var inString = false
        var previous: Character?
        for character in text {
            if character == "\"" && previous != "\\" {
                if !inString {
                    result += transform(code)
                    code = ""
                }
                inString.toggle()
                result.append(character)
            } else if inString {
                result.append(emptying && character != "\n" ? " " : character)
            } else {
                code.append(character)
            }
            previous = character
        }
        return result + transform(code)
    }

    /// The text between the parentheses of every call that starts with one of `openings`, outside string literals, and
    /// outermost only: a call written inside one already found is part of that one's text.
    static func calls(of openings: [String], in text: String) -> [(opening: String, body: String)] {
        var found: [(opening: String, body: String)] = []
        var index = text.startIndex
        var inString = false
        var previous: Character?
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" && previous != "\\" { inString.toggle() }
            if !inString, character == ".", let opening = openings.first(where: { text[index...].hasPrefix($0) }) {
                let start = text.index(index, offsetBy: opening.count)
                let end = closing(in: text, from: start, opening: "(", closing: ")")
                found.append((opening, String(text[start..<end])))
                index = end < text.endIndex ? text.index(after: end) : end
                previous = ")"
                continue
            }
            previous = character
            index = text.index(after: index)
        }
        return found
    }

    /// The index of the bracket that closes the one open just before `start`, or the end of the text.
    private static func closing(in text: String, from start: String.Index, opening: Character, closing: Character) -> String.Index {
        var depth = 1
        var inString = false
        var previous: Character?
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" && previous != "\\" { inString.toggle() }
            if !inString && character == opening { depth += 1 }
            if !inString && character == closing {
                depth -= 1
                if depth == 0 { return index }
            }
            previous = character
            index = text.index(after: index)
        }
        return text.endIndex
    }

    /// The parts of a list or of a call's arguments: the text between the commas outside brackets and string literals,
    /// trimmed, without the empty part a trailing comma leaves.
    static func elements(of text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        var previous: Character?
        for character in text {
            if character == "\"" && previous != "\\" { inString.toggle() }
            if !inString && "([{".contains(character) { depth += 1 }
            if !inString && ")]}".contains(character) { depth -= 1 }
            if character == "," && depth == 0 && !inString {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
            previous = character
        }
        parts.append(current)
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// A call's arguments by label; an argument without a label is left out.
    private static func arguments(of body: String) -> [String: String] {
        var found: [String: String] = [:]
        for element in elements(of: body) {
            guard let colon = element.firstIndex(of: ":") else { continue }
            let label = element[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { continue }
            found[label] = element[element.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return found
    }

    /// The text of a string literal that is the whole of `value`.
    private static func literal(_ value: String) -> String? {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return nil }
        let inside = value.dropFirst().dropLast()
        return inside.contains("\"") || inside.contains("\\") ? nil : String(inside)
    }

    /// A name written as a string literal (`"CVRendering"`, `"swift-syntax"`).
    private static func name(_ value: String) -> String? {
        guard let text = literal(value), !text.isEmpty,
              text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else { return nil }
        return text
    }

    /// The parts of a list that is the whole of `value` (`["A", "B"]`, not `["A"] + more`).
    private static func list(_ value: String) -> [String]? {
        guard value.count >= 2, value.first == "[", value.last == "]" else { return nil }
        let start = value.index(after: value.startIndex)
        let end = value.index(before: value.endIndex)
        guard closing(in: value, from: start, opening: "[", closing: "]") == end else { return nil }
        return elements(of: String(value[start..<end]))
    }

    /// The function and the arguments of a call that is the whole of `value` (`.product(...)`,
    /// `Target.Dependency.target(...)`).
    private static func call(_ value: String) -> (function: String, body: String)? {
        guard let head = matches(#"^(?:Target\.Dependency)?\.(\w+)\("#, in: value).first?.first,
              let open = value.firstIndex(of: "("), value.last == ")" else { return nil }
        let start = value.index(after: open)
        let end = value.index(before: value.endIndex)
        guard closing(in: value, from: start, opening: "(", closing: ")") == end else { return nil }
        return (head, String(value[start..<end]))
    }

    /// The capture groups of every match of `pattern`.
    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        NSRegularExpression.compiled(pattern).matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        }
    }
}

private extension NSRegularExpression {
    /// A pattern written in this file, which is known to compile.
    static func compiled(_ pattern: String) -> NSRegularExpression {
        do { return try NSRegularExpression(pattern: pattern) } catch { preconditionFailure("\(pattern) is not a pattern") }
    }
}
