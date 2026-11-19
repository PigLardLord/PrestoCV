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
/// scan.
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

    /// The calls that declare a target. Only `.target(` is read; the others are named so that a `.target(name:)` among
    /// their dependencies is not taken for a declaration.
    private static let declarations = [
        ".target(", ".testTarget(", ".executableTarget(", ".macro(", ".plugin(", ".binaryTarget(", ".systemLibrary(",
    ]

    init(packages: [String], read: (String) throws -> String) rethrows {
        for package in packages {
            let text = Self.withoutComments(try read(package))
            let aliases = Self.aliases(in: text)
            for call in Self.calls(of: [".library("], in: text) { readLibrary(call.body, in: package) }
            for call in Self.calls(of: Self.declarations, in: text) where call.opening == ".target(" {
                readTarget(call.body, in: package, aliases: aliases)
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

    /// `.library(name: "X", type: .dynamic, targets: ["A", "B"])`
    private mutating func readLibrary(_ body: String, in package: String) {
        let arguments = Self.arguments(of: body)
        guard let name = arguments["name"].flatMap(Self.name), let members = arguments["targets"].flatMap(Self.list) else {
            return report(".library(\(body))", in: package)
        }
        let names = members.compactMap(Self.name)
        guard names.count == members.count else { return report(".library(\(body))", in: package) }
        products[package, default: [:]][name] = names
    }

    /// `.target(name: "A", dependencies: [...], path: "Sources/Elsewhere")`; a target declared again (in the other
    /// branch of an `#if`) keeps the dependencies of both.
    private mutating func readTarget(_ body: String, in package: String, aliases: [String: ProductReference]) {
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
                    case .product(let product): external.append(product)
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
        case product(ProductReference)
        case unknown
    }

    /// `"B"`, `.target(name: "B")`, `.byName(name: "B")`, `.product(name: "C", package: "Other")` (each may carry a
    /// condition), or an alias.
    private static func dependency(_ element: String, aliases: [String: ProductReference]) -> Dependency {
        if let target = Self.name(element) { return .target(target) }
        if let alias = aliases[element] { return .product(alias) }
        guard let found = Self.call(element) else { return .unknown }
        let arguments = Self.arguments(of: found.body)
        guard let named = arguments["name"].flatMap(Self.name) else { return .unknown }
        switch found.function {
        case "target", "byName":
            return .target(named)
        case "product":
            guard let owner = arguments["package"].flatMap(Self.name) else { return .unknown }
            return .product(ProductReference(name: named, package: owner))
        default:
            return .unknown
        }
    }

    /// `let logging = Target.Dependency.product(name: "Log", package: "Logs")`, or `let logging: Target.Dependency =
    /// .product(...)`, on one line or several. An alias written another way is not here, so its use is reported.
    private static func aliases(in text: String) -> [String: ProductReference] {
        let pattern = #"let\s+(\w+)\s*(?::\s*Target\.Dependency\s*)?=\s*(?:Target\.Dependency)?\.product\(\s*name:\s*"([\w-]+)"\s*,\s*package:\s*"([\w-]+)"\s*\)"#
        var found: [String: ProductReference] = [:]
        for match in matches(pattern, in: text) {
            found[match[0]] = ProductReference(name: match[1], package: match[2])
        }
        return found
    }

    private mutating func report(_ text: String, in package: String) {
        unreadable.append("\(package): \(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))")
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
        let expression: NSRegularExpression
        do { expression = try NSRegularExpression(pattern: pattern) } catch { preconditionFailure("\(pattern) is not a pattern") }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        }
    }
}
