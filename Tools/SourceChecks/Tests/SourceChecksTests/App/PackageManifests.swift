import Foundation

// MARK: - Package manifests

/// The targets of the repository's local packages and what each depends on, read from the text of every `Package.swift`.
///
/// The text is read, not dumped with `swift package dump-package`: a manifest puts targets behind `#if !os(Linux)`
/// (the AI drafting and rendering adapters, the composition), so a dump on Linux, where the checks run, would hide code
/// that a Release build for iOS compiles. Reading the text sees every branch of an `#if`, and so reads a superset of one
/// platform's build, which is the safe side for a check of what ships.
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

    init(packages: [String], read: (String) throws -> String) rethrows {
        for package in packages {
            let text = Self.withoutComments(try read(package))
            let aliases = Self.aliases(in: text)
            for (name, members) in Self.libraries(in: text) { products[package, default: [:]][name] = members }
            for call in Self.calls(of: ".target(", in: text) {
                guard let name = Self.first(#"name:\s*"([^"]+)""#, in: call) else { continue }
                let path = Self.first(#"path:\s*"([^"]+)""#, in: call) ?? "Sources/\(name)"
                let (local, external) = Self.dependencies(of: call, aliases: aliases, package: package)
                targets[Self.key(package, name)] = Target(
                    package: package, name: name, folder: "\(package)/\(path)", targets: local, products: external
                )
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

    /// `let logging = Target.Dependency.product(name: "DiagnosticLogging", package: "DiagnosticLogging")`
    private static func aliases(in text: String) -> [String: ProductReference] {
        var found: [String: ProductReference] = [:]
        for match in matches(#"let (\w+) = Target\.Dependency\.product\(name:\s*"(\w+)",\s*package:\s*"(\w+)""#, in: text) {
            found[match[0]] = ProductReference(name: match[1], package: match[2])
        }
        return found
    }

    /// `.library(name: "X", targets: ["A", "B"])`
    private static func libraries(in text: String) -> [String: [String]] {
        var found: [String: [String]] = [:]
        for match in matches(#"\.library\(name:\s*"(\w+)",\s*targets:\s*\[([^\]]*)\]"#, in: text) {
            found[match[0]] = matches(#""(\w+)""#, in: match[1]).map { $0[0] }
        }
        return found
    }

    /// The text between the parentheses of every call that starts with `opening` (`.target(`, not `.testTarget(`).
    static func calls(of opening: String, in text: String) -> [String] {
        var found: [String] = []
        var search = text.startIndex..<text.endIndex
        while let range = text.range(of: opening, range: search) {
            var depth = 1
            var inString = false
            var index = range.upperBound
            while index < text.endIndex, depth > 0 {
                let character = text[index]
                if character == "\"" { inString.toggle() }
                if !inString { depth += character == "(" ? 1 : character == ")" ? -1 : 0 }
                index = text.index(after: index)
            }
            found.append(String(text[range.upperBound..<index]))
            search = index..<text.endIndex
        }
        return found
    }

    private static func dependencies(
        of call: String, aliases: [String: ProductReference], package: String
    ) -> (targets: [String], products: [ProductReference]) {
        guard let label = call.range(of: "dependencies:"), let open = call[label.upperBound...].firstIndex(of: "[") else {
            return ([], [])
        }
        var depth = 0
        var index = open
        while index < call.endIndex {
            if call[index] == "[" { depth += 1 }
            if call[index] == "]" { depth -= 1; if depth == 0 { break } }
            index = call.index(after: index)
        }
        var list = String(call[call.index(after: open)..<index])
        let external = matches(#"\.product\(name:\s*"(\w+)",\s*package:\s*"(\w+)""#, in: list)
            .map { ProductReference(name: $0[0], package: $0[1]) }
        list = list.replacingOccurrences(of: #"\.product\([^)]*\)"#, with: "", options: .regularExpression)
        let local = matches(#""(\w+)""#, in: list).map { $0[0] }
        let named = matches(#"(?<![\w."])([a-z]\w*)(?![\w"])"#, in: list).compactMap { aliases[$0[0]] }
        return (local, external + named)
    }

    private static func first(_ pattern: String, in text: String) -> String? { matches(pattern, in: text).first?[0] }

    /// The capture groups of every match of `pattern`.
    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        let expression: NSRegularExpression
        do { expression = try NSRegularExpression(pattern: pattern) } catch { preconditionFailure("\(pattern) is not a pattern") }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        }
    }
}
