// MARK: - Package manifests

/// The targets of the repository's local packages and what each depends on, read from the text of every `Package.swift`.
///
/// The text is read, not dumped with `swift package dump-package`: a manifest puts targets behind `#if !os(Linux)`
/// (the AI drafting and rendering adapters, the composition), so a dump on Linux, where the checks run, would hide code
/// that a Release build for iOS compiles. Reading the text sees every branch of an `#if`, and so reads a superset of one
/// platform's build, which is the safe side for a check of what ships.
///
/// The reader fails closed: it follows a small grammar, and every statement outside it goes to `unreadable` as the
/// lines that hold it, which the release checks require empty. A new way of writing a manifest fails them instead of
/// shrinking what they scan.
/// - **Text:** printable ASCII and tabs. A string is the plain one, with no backslash, on one line; a `//` comment runs
///   to a line feed or a carriage return.
/// - **Statements:** one per line, or over several lines while a bracket is open: `import PackageDescription`; `#if`
///   or `#elseif` with its whole condition on its line, ending in a word or `)`; `#else`; `#endif`; `let` or `var`
///   name, an optional type, `=` and a value; `name += value`; `name.append(value)`.
/// - **Values:** a string; a list `[...]` (a trailing comma allowed); `.name`; `.name(arguments)`;
///   `Target.Dependency.name(arguments)`; `Package(arguments)`; a word.
/// - **Declarations:** `.target` (name, dependencies, path, resources) and `.library` (name, type, targets) are read;
///   `.testTarget` is skipped, as it never ships; the labels of `.package` (path) and of `Package` (name, platforms,
///   products, dependencies, targets) are allowed. Any other member, label, or name that is not a literal is reported.
///
/// Every accepted statement ends in a word, a string, `)` or `]`, and none starts with an operator or a `.`, or holds a
/// brace or a semicolon, so the compiler splits the text into the same statements. With no brace there is no closure,
/// function or loop, and a list or a target changes only through `+=` or `append` on a name.
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

    init(packages: [String], read: (String) throws -> String) rethrows {
        for package in packages {
            let bytes = Array(try read(package).utf8)
            var statements: [Statement] = []
            for tokens in Self.statements(of: Self.tokens(of: bytes)) {
                var parser = Parser(tokens: tokens, bytes: bytes)
                if let statement = parser.statement() {
                    statements.append(statement)
                } else {
                    report(Self.lines(holding: tokens, in: bytes), in: package)
                }
            }
            readDeclarations(in: statements, of: package)
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

    /// Reads every declaration the statements hold. A declaration typed `Target.Dependency` or `[Target.Dependency]`
    /// names dependencies, so a `.target(name:)` in it is not a target's declaration.
    private mutating func readDeclarations(in statements: [Statement], of package: String) {
        let aliases = Self.aliases(in: statements)
        for statement in statements {
            switch statement {
            case .importDescription, .directive:
                continue
            case let .declaration(_, type, node):
                if type == "Target.Dependency" || type == "[Target.Dependency]" { continue }
                walk(node, in: package, aliases: aliases)
            case let .addition(node):
                walk(node, in: package, aliases: aliases)
            }
        }
    }

    /// Follows a value down to the declarations it holds: a list, `Package(...)` and its products, dependencies and
    /// targets. A member the reader does not know is reported, so a kind of target or product it does not follow (in any
    /// branch of a condition) fails the checks instead of leaving the scan.
    private mutating func walk(_ node: Node, in package: String, aliases: [String: [ProductReference]]) {
        switch node.value {
        case .member("testTarget", _):
            return
        case let .member("target", given?):
            readTarget(node, given, in: package, aliases: aliases)
        case let .member("library", given?):
            readLibrary(node, given, in: package)
        case let .member("package", given?):
            if !Self.byLabel(given, allowed: ["path"]).stray.isEmpty { report(node.text, in: package) }
        case let .packageDeclaration(given):
            let (labelled, stray) = Self.byLabel(given, allowed: ["name", "platforms", "products", "dependencies", "targets"])
            for argument in stray { report("Package \(argument.text)", in: package) }
            for label in ["products", "dependencies", "targets"] {
                if let argument = labelled[label] { walk(argument.node, in: package, aliases: aliases) }
            }
        case let .list(elements):
            for element in elements { walk(element, in: package, aliases: aliases) }
        case .word, .string, .dependency:
            return
        case .member:
            report(node.text, in: package)
        }
    }

    /// `.library(name: "X", type: .dynamic, targets: ["A", "B"])`; a product declared again (in the other branch of an
    /// `#if`) reaches the targets of both.
    private mutating func readLibrary(_ node: Node, _ given: [Argument], in package: String) {
        let (labelled, stray) = Self.byLabel(given, allowed: ["name", "type", "targets"])
        if !stray.isEmpty { report(node.text, in: package) }
        guard let name = labelled["name"].flatMap({ Self.name($0.node) }),
              case let .list(members)? = labelled["targets"]?.node.value
        else { return report(node.text, in: package) }
        let names = members.compactMap(Self.name)
        guard names.count == members.count else { return report(node.text, in: package) }
        let earlier = products[package]?[name] ?? []
        products[package, default: [:]][name] = earlier + names.filter { !earlier.contains($0) }
    }

    /// `.target(name: "A", dependencies: [...], path: "Sources/Elsewhere")`; a target declared again (in the other
    /// branch of an `#if`) keeps the dependencies of both. Another label is reported, and the target is still read.
    private mutating func readTarget(_ node: Node, _ given: [Argument], in package: String, aliases: [String: [ProductReference]]) {
        let (labelled, stray) = Self.byLabel(given, allowed: ["name", "dependencies", "path", "resources"])
        guard let name = labelled["name"].flatMap({ Self.name($0.node) }) else { return report(node.text, in: package) }
        for argument in stray { report("\(name) \(argument.text)", in: package) }
        var folder = "\(package)/Sources/\(name)"
        if let path = labelled["path"] {
            guard case let .string(literal) = path.node.value else { return report(node.text, in: package) }
            folder = "\(package)/\(literal)"
        }
        var local: [String] = []
        var external: [ProductReference] = []
        if let dependencies = labelled["dependencies"] {
            if case let .list(elements) = dependencies.node.value {
                for element in elements {
                    switch Self.dependency(element, aliases: aliases) {
                    case let .target(target): local.append(target)
                    case let .products(products): external += products
                    case .unknown: report(element.text, in: package)
                    }
                }
            } else {
                report("\(name) \(dependencies.text)", in: package)
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
    private static func dependency(_ node: Node, aliases: [String: [ProductReference]]) -> Dependency {
        switch node.value {
        case .string:
            return name(node).map(Dependency.target) ?? .unknown
        case let .word(word):
            return aliases[word].map(Dependency.products) ?? .unknown
        case let .member(function, given?), let .dependency(function, given):
            return call(function, given)
        case .member, .list, .packageDeclaration:
            return .unknown
        }
    }

    /// A dependency written as a call; one with a label the reader does not follow is unknown.
    private static func call(_ function: String, _ given: [Argument]) -> Dependency {
        switch function {
        case "target", "byName":
            let (labelled, stray) = byLabel(given, allowed: ["name", "condition"])
            guard stray.isEmpty, let target = labelled["name"].flatMap({ Self.name($0.node) }) else { return .unknown }
            return .target(target)
        case "product":
            let (labelled, stray) = byLabel(given, allowed: ["name", "package", "condition"])
            guard stray.isEmpty,
                  let product = labelled["name"].flatMap({ Self.name($0.node) }),
                  let owner = labelled["package"].flatMap({ Self.name($0.node) })
            else { return .unknown }
            return .products([ProductReference(name: product, package: owner)])
        default:
            return .unknown
        }
    }

    /// `let logging = Target.Dependency.product(name: "Log", package: "Logs")`, or `let logging: Target.Dependency =
    /// .product(...)`; `var` reads the same, as the grammar has no statement that gives a name another value. A name
    /// declared in several branches of a condition names the products of all of them. A name declared another way, in
    /// any branch, is not here, so its use is reported.
    private static func aliases(in statements: [Statement]) -> [String: [ProductReference]] {
        var declared: [String: Int] = [:]
        var read: [String: Int] = [:]
        var found: [String: [ProductReference]] = [:]
        for case let .declaration(alias, _, node) in statements {
            declared[alias, default: 0] += 1
            guard case let .products(products) = dependency(node, aliases: [:]) else { continue }
            read[alias, default: 0] += 1
            let earlier = found[alias] ?? []
            found[alias] = earlier + products.filter { !earlier.contains($0) }
        }
        return found.filter { declared[$0.key] == read[$0.key] }
    }

    /// A name written as a string literal (`"CVRendering"`, `"swift-syntax"`).
    private static func name(_ node: Node) -> String? {
        guard case let .string(text) = node.value, !text.isEmpty,
              text.utf8.allSatisfy({ $0.isWordByte || $0 == .hyphen })
        else { return nil }
        return text
    }

    /// The first argument of each allowed label; every other argument, and a label given twice, is stray.
    private static func byLabel(_ given: [Argument], allowed: Set<String>) -> (labelled: [String: Argument], stray: [Argument]) {
        var labelled: [String: Argument] = [:]
        var stray: [Argument] = []
        for argument in given {
            if let label = argument.label, allowed.contains(label), labelled[label] == nil {
                labelled[label] = argument
            } else {
                stray.append(argument)
            }
        }
        return (labelled, stray)
    }

    /// Reports a text once, though more than one rule may find it.
    private mutating func report(_ text: String, in package: String) {
        let entry = "\(package): \(text.split(whereSeparator: \.isWhitespace).joined(separator: " "))"
        if !unreadable.contains(entry) { unreadable.append(entry) }
    }

    // MARK: Reading the text

    private enum Statement {
        case importDescription
        case directive
        case declaration(name: String, type: String?, node: Node)
        case addition(Node)
    }

    private enum Value {
        case string(String)
        case list([Node])
        /// `.name`, or `.name(arguments)`
        case member(String, [Argument]?)
        /// `Target.Dependency.name(arguments)`
        case dependency(String, [Argument])
        case packageDeclaration([Argument])
        case word(String)
    }

    /// A value and the text it was read from
    private struct Node {
        let value: Value
        let text: String
    }

    private struct Argument {
        let label: String?
        let node: Node
        /// The label and the value, as written
        let text: String
    }

    private struct Token {
        enum Kind { case word, string, directive, symbol, lineBreak, bad }
        let kind: Kind
        /// Where the token is in the bytes of the manifest
        let range: Range<Int>
        let text: String
    }

    /// The tokens of a manifest. A plain string and a `//` comment end at the end of their line. A string or a comment
    /// the grammar does not follow (one that holds a byte outside printable ASCII and tab, or a string with a backslash
    /// or with no closing quote) is a `bad` token, and any other byte is a symbol of its own: no statement accepts a bad
    /// token or a symbol the grammar does not name. White space but a line break is skipped, and a comment is dropped.
    private static func tokens(of bytes: [UInt8]) -> [Token] {
        var tokens: [Token] = []
        var index = 0
        func emit(_ kind: Token.Kind, to end: Int) {
            tokens.append(Token(kind: kind, range: index..<end, text: String(decoding: bytes[index..<end], as: UTF8.self)))
            index = end
        }
        func end(from start: Int, while holds: (UInt8) -> Bool) -> Int {
            var last = start
            while last < bytes.count, holds(bytes[last]) { last += 1 }
            return last
        }
        while index < bytes.count {
            let byte = bytes[index]
            let following = index + 1 < bytes.count ? bytes[index + 1] : nil
            if byte == .space || byte == .tab {
                index += 1
            } else if byte.isLineBreak {
                emit(.lineBreak, to: index + 1)
            } else if byte == .slash, following == UInt8.slash {
                let close = end(from: index, while: { !$0.isLineBreak })
                if bytes[index..<close].allSatisfy({ $0.isPrintable || $0 == .tab }) { index = close } else { emit(.bad, to: close) }
            } else if byte == .quote {
                let close = end(from: index + 1, while: { $0 != .quote && !$0.isLineBreak })
                if close < bytes.count, bytes[close] == .quote {
                    let plain = bytes[(index + 1)..<close].allSatisfy { $0.isPrintable && $0 != .backslash }
                    emit(plain ? .string : .bad, to: close + 1)
                } else {
                    emit(.bad, to: close)
                }
            } else if byte == .hash, following?.isWordByte == true {
                emit(.directive, to: end(from: index + 1, while: \.isWordByte))
            } else if byte == .plus, following == UInt8.equals {
                emit(.symbol, to: index + 2)
            } else if byte.isWordByte {
                emit(.word, to: end(from: index, while: \.isWordByte))
            } else {
                emit(.symbol, to: index + 1)
            }
        }
        return tokens
    }

    private static let openings: Set<String> = ["(", "[", "{"]
    private static let closings: Set<String> = [")", "]", "}"]

    /// The tokens split into statements: at each line break outside brackets. A line break inside a bracket stays in
    /// its statement, as it does for the compiler.
    private static func statements(of tokens: [Token]) -> [[Token]] {
        var statements: [[Token]] = []
        var current: [Token] = []
        var depth = 0
        for token in tokens {
            if token.kind == .lineBreak, depth == 0 {
                if !current.isEmpty { statements.append(current) }
                current = []
                continue
            }
            current.append(token)
            guard token.kind == .symbol else { continue }
            if openings.contains(token.text) { depth += 1 }
            if closings.contains(token.text) { depth = max(0, depth - 1) }
        }
        if !current.isEmpty { statements.append(current) }
        return statements
    }

    /// The lines that hold the tokens of a statement, from its first token (only white space comes before it on its
    /// line) to the end of its last line, so a comment there is in the report.
    private static func lines(holding tokens: [Token], in bytes: [UInt8]) -> String {
        guard let first = tokens.first, let last = tokens.last else { return "" }
        var upper = last.range.upperBound
        while upper < bytes.count, !bytes[upper].isLineBreak { upper += 1 }
        return String(decoding: bytes[first.range.lowerBound..<upper], as: UTF8.self)
    }

    /// Reads one statement of the grammar, or nothing when a token is left over or out of place.
    private struct Parser {
        private static let conditionSymbols: Set<String> = ["!", "&", "|", "(", ")", ">", "<", "=", "."]

        private let tokens: [Token]
        private let bytes: [UInt8]
        private let spansLines: Bool
        private var position = 0

        init(tokens: [Token], bytes: [UInt8]) {
            self.tokens = tokens.filter { $0.kind != .lineBreak }
            self.bytes = bytes
            spansLines = tokens.contains { $0.kind == .lineBreak }
        }

        mutating func statement() -> Statement? {
            guard let statement = readStatement(), position == tokens.count else { return nil }
            return statement
        }

        private mutating func readStatement() -> Statement? {
            guard position < tokens.count else { return nil }
            let first = tokens[position]
            if first.kind == .directive {
                position += 1
                return directive(first.text)
            }
            guard let name = word() else { return nil }
            switch name {
            case "import":
                return take(word: "PackageDescription") ? .importDescription : nil
            case "let", "var":
                return declaration()
            default:
                if take("+=") { return value().map(Statement.addition) }
                guard take("."), take(word: "append"), take("("), let node = value(), take(")") else { return nil }
                return .addition(node)
            }
        }

        /// `name`, an optional `: Type`, `=` and a value
        private mutating func declaration() -> Statement? {
            guard let name = word() else { return nil }
            var type: String?
            if take(":") {
                guard let named = typeName() else { return nil }
                type = named
            }
            guard take("="), let node = value() else { return nil }
            return .declaration(name: name, type: type, node: node)
        }

        /// `Product`, `Target.Dependency`, `[Target]`, `[Package.Dependency]`
        private mutating func typeName() -> String? {
            let bracketed = take("[")
            guard var name = word() else { return nil }
            while take(".") {
                guard let part = word() else { return nil }
                name += ".\(part)"
            }
            guard bracketed else { return name }
            return take("]") ? "[\(name)]" : nil
        }

        /// `#if` or `#elseif` with a condition of words and the symbols of a condition, on one line and ending in a
        /// word or `)`, so the compiler ends it where the reader does; `#else` and `#endif` alone.
        private mutating func directive(_ name: String) -> Statement? {
            let condition = tokens[position...]
            position = tokens.count
            switch name {
            case "#if", "#elseif":
                guard !spansLines, let last = condition.last,
                      last.kind == .word || last.kind == .symbol && last.text == ")",
                      condition.allSatisfy({ $0.kind == .word || $0.kind == .symbol && Self.conditionSymbols.contains($0.text) })
                else { return nil }
                return .directive
            case "#else", "#endif":
                return condition.isEmpty ? .directive : nil
            default:
                return nil
            }
        }

        private mutating func value() -> Node? {
            guard position < tokens.count else { return nil }
            let start = position
            let token = tokens[position]
            let value: Value?
            if token.kind == .string {
                position += 1
                value = .string(String(token.text.dropFirst().dropLast()))
            } else if take("[") {
                value = list()
            } else if take(".") {
                value = member()
            } else if take(word: "Target") {
                value = dependency()
            } else if take(word: "Package") {
                value = arguments().map(Value.packageDeclaration)
            } else if token.kind == .word {
                position += 1
                value = .word(token.text)
            } else {
                value = nil
            }
            return value.map { Node(value: $0, text: text(from: start)) }
        }

        /// The elements of a list, after its `[`
        private mutating func list() -> Value? {
            var elements: [Node] = []
            while !take("]") {
                guard let element = value(), take(",") || peek("]") else { return nil }
                elements.append(element)
            }
            return .list(elements)
        }

        /// `.name` or `.name(arguments)`, after the `.`
        private mutating func member() -> Value? {
            guard let name = word() else { return nil }
            guard peek("(") else { return .member(name, nil) }
            return arguments().map { .member(name, $0) }
        }

        /// `.Dependency.name(arguments)`, after `Target`
        private mutating func dependency() -> Value? {
            guard take("."), take(word: "Dependency"), take("."), let name = word(), let given = arguments() else { return nil }
            return .dependency(name, given)
        }

        /// `(label: value, value, ...)`, a trailing comma allowed
        private mutating func arguments() -> [Argument]? {
            guard take("(") else { return nil }
            var given: [Argument] = []
            while !take(")") {
                let start = position
                var label: String?
                if position + 1 < tokens.count, tokens[position].kind == .word,
                   tokens[position + 1].kind == .symbol, tokens[position + 1].text == ":" {
                    label = tokens[position].text
                    position += 2
                }
                guard let node = value() else { return nil }
                given.append(Argument(label: label, node: node, text: text(from: start)))
                guard take(",") || peek(")") else { return nil }
            }
            return given
        }

        private func peek(_ symbol: String) -> Bool {
            position < tokens.count && tokens[position].kind == .symbol && tokens[position].text == symbol
        }

        private mutating func take(_ symbol: String) -> Bool {
            guard peek(symbol) else { return false }
            position += 1
            return true
        }

        private mutating func take(word expected: String) -> Bool {
            guard position < tokens.count, tokens[position].kind == .word, tokens[position].text == expected else { return false }
            position += 1
            return true
        }

        private mutating func word() -> String? {
            guard position < tokens.count, tokens[position].kind == .word else { return nil }
            position += 1
            return tokens[position - 1].text
        }

        /// The text from the token at `start` to the last one read, as written
        private func text(from start: Int) -> String {
            String(decoding: bytes[tokens[start].range.lowerBound..<tokens[position - 1].range.upperBound], as: UTF8.self)
        }
    }
}

// MARK: - Bytes of a manifest

private extension UInt8 {
    static let tab: UInt8 = 0x09
    static let lineFeed: UInt8 = 0x0A
    static let carriageReturn: UInt8 = 0x0D
    static let space: UInt8 = 0x20
    static let quote: UInt8 = 0x22
    static let hash: UInt8 = 0x23
    static let plus: UInt8 = 0x2B
    static let hyphen: UInt8 = 0x2D
    static let slash: UInt8 = 0x2F
    static let equals: UInt8 = 0x3D
    static let backslash: UInt8 = 0x5C

    var isLineBreak: Bool { self == .lineFeed || self == .carriageReturn }
    var isPrintable: Bool { (0x20...0x7E).contains(self) }
    var isDigit: Bool { (0x30...0x39).contains(self) }
    var isWordByte: Bool { isDigit || (0x41...0x5A).contains(self) || (0x61...0x7A).contains(self) || self == 0x5F }
}
