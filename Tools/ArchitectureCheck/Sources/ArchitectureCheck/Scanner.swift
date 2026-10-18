import SwiftParser
import SwiftSyntax

/// One detected construct. `node` is the construct's source text without trivia (comments, spacing),
/// which makes the baseline fingerprint stable when comments or indentation change.
struct Hit {
    let detector: String
    let detail: String
    let node: String
    let line: Int
    /// In a manifest: the name of the target declaration that contains the construct, if any.
    let packageTarget: String?
}

/// Walks the syntax tree of one file. Every `#if` branch is visited (sourceAccurate), so code that is
/// inactive on the checking host is still checked. Regex literals, strings and comments are syntax,
/// not text, so they can neither hide code nor produce false findings.
final class Scanner: SyntaxVisitor {
    private(set) var hits: [Hit] = []
    private(set) var imports: [(module: String, line: Int, node: String, access: String?)] = []
    /// In a manifest: the names of every target declaration, in every `#if` branch.
    private(set) var declaredPackageTargets: [String] = []
    private let converter: SourceLocationConverter
    private let infrastructureTypes: Set<String>

    static let ambientTypes: Set<String> = ["Bundle", "FileManager", "UserDefaults", "ProcessInfo", "NotificationCenter"]
    static let ambientMembers: [String: Set<String>] = [
        "Locale": ["current", "autoupdatingCurrent"], "TimeZone": ["current", "autoupdatingCurrent"],
        "Calendar": ["current", "autoupdatingCurrent"],
    ]
    static let infrastructureMembers: [String: String] = ["FileManager": "default", "Bundle": "main", "UserDefaults": "standard"]
    static let escapeCalls: Set<String> = ["fatalError", "precondition", "preconditionFailure", "unsafeBitCast"]
    static let printCalls: Set<String> = ["print", "debugPrint", "NSLog", "dump"]

    init(tree: SourceFileSyntax, file: String, infrastructureTypes: Set<String>) {
        converter = SourceLocationConverter(fileName: file, tree: tree)
        self.infrastructureTypes = infrastructureTypes
        super.init(viewMode: .sourceAccurate)
    }

    private func hit(_ detector: String, _ detail: String, _ node: some SyntaxProtocol) {
        // Tokens without trivia: spacing and comments inside the construct do not change its identity.
        let text = node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
        hits.append(Hit(detector: detector, detail: detail, node: text, line: node.startLocation(converter: converter).line,
                        packageTarget: Self.enclosingPackageTarget(of: Syntax(node))))
    }

    /// Module names that may qualify a symbol (`Swift.fatalError`, `Foundation.Date()`). They are stripped before
    /// the detectors run, so qualifying a name cannot hide it.
    static let moduleQualifiers: Set<String> = ["Swift", "Foundation", "FoundationEssentials", "Dispatch", "Darwin", "Glibc", "_Concurrency", "Observation"]

    /// The names of a reference chain (`a.b.c` gives ["a", "b", "c"]; an implicit member `.c` gives ["", "c"]),
    /// with leading module qualifiers removed. Nil for any other expression.
    static func unqualifiedPath(_ expr: ExprSyntax) -> [String]? {
        var parts: [String]
        if let ref = expr.as(DeclReferenceExprSyntax.self) { parts = [name(ref.baseName)] }
        else if let access = expr.as(MemberAccessExprSyntax.self) {
            if let base = access.base { guard let b = unqualifiedPath(base) else { return nil }; parts = b }
            else { parts = [""] }
            parts.append(name(access.declName.baseName))
        } else { return nil }
        while parts.count > 1, moduleQualifiers.contains(parts[0]) { parts.removeFirst() }
        return parts
    }

    static let targetFactories: Set<String> = ["target", "testTarget", "executableTarget", "plugin", "macro", "systemLibrary", "binaryTarget"]

    /// The `name:` of the nearest enclosing `.target(name: "…", …)` call; nil for package-level settings.
    private static func enclosingPackageTarget(of node: Syntax) -> String? {
        var current = node.parent
        while let n = current {
            if let call = n.as(FunctionCallExprSyntax.self), let access = call.calledExpression.as(MemberAccessExprSyntax.self),
               targetFactories.contains(name(access.declName.baseName)),
               let literal = call.arguments.first(where: { $0.label?.text == "name" })?.expression.as(StringLiteralExprSyntax.self),
               literal.segments.count == 1, let segment = literal.segments.first?.as(StringSegmentSyntax.self) {
                return segment.content.text
            }
            current = n.parent
        }
        return nil
    }

    private static func name(_ token: TokenSyntax) -> String { token.text.trimmingCharacters(in: CharacterSet(charactersIn: "`")) }

    // MARK: Imports

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let first = node.path.first else { return .skipChildren }
        let access = node.modifiers.map(\.name.text).first { ["public", "package", "internal", "fileprivate", "private"].contains($0) }
        imports.append((Self.name(first.name), node.startLocation(converter: converter).line, "import " + Self.name(first.name), access))
        if node.attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "_exported" }) {
            hit("exportedImport", "@_exported import", node)
        }
        return .skipChildren
    }

    // MARK: Platform conditions

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        if let condition = node.condition, condition.trimmedDescription.range(of: #"\b(os|canImport|targetEnvironment|arch)\s*\("#, options: .regularExpression) != nil {
            hit("platformCondition", "#if " + condition.trimmedDescription, condition)
        }
        return .visitChildren
    }

    override func visit(_ node: AvailabilityConditionSyntax) -> SyntaxVisitorContinueKind {
        hit("platformCondition", "#available", node); return .visitChildren
    }

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        switch node.attributeName.trimmedDescription {
        case "available": hit("platformCondition", "@available", node)
        case "unchecked": hit("escapeHatch", "@unchecked", node)
        default: break
        }
        return .visitChildren
    }

    // MARK: Escape hatches and error handling

    override func visit(_ node: DeclModifierSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == "nonisolated", node.detail?.detail.text == "unsafe" { hit("escapeHatch", "nonisolated(unsafe)", node) }
        return .visitChildren
    }

    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        switch node.questionOrExclamationMark?.tokenKind {
        case .postfixQuestionMark?: hit("swallowedError", "try?", node.tryKeyword)
        case .exclamationMark?: hit("escapeHatch", "try!", node.tryKeyword)
        default: break
        }
        return .visitChildren
    }

    override func visit(_ node: UnresolvedAsExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark?.tokenKind == .exclamationMark { hit("escapeHatch", "as!", node) }
        return .visitChildren
    }

    override func visit(_ node: AsExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark?.tokenKind == .exclamationMark { hit("escapeHatch", "as!", node) }
        return .visitChildren
    }

    override func visit(_ node: ForceUnwrapExprSyntax) -> SyntaxVisitorContinueKind {
        hit("escapeHatch", "force unwrap", node); return .visitChildren
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        if node.body.statements.isEmpty { hit("swallowedError", "empty catch", node.catchKeyword) }
        return .visitChildren
    }

    // MARK: Calls, members, references

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let args = node.arguments
        var callee: String?, member: String?
        if let path = Self.unqualifiedPath(node.calledExpression) {           // "" = implicit member (.foo)
            if path.count == 1 { callee = path[0] } else { callee = path[path.count - 2]; member = path[path.count - 1] }
        }
        if member == "unsafeFlags" { hit("unsafeFlags", "unsafeFlags", node) }
        if member == "copy", callee == "" || callee == "Resource" { checkCopiedResource(node) }
        // A language mode below 6 in any spelling: .version("5"), .version("4.2").
        if member == "version", let literal = args.first?.expression.as(StringLiteralExprSyntax.self),
           let major = Int(literal.segments.trimmedDescription.prefix { $0.isNumber }), major < 6 {
            hit("swift5Mode", ".version(\"\(literal.segments.trimmedDescription)\")", node)
        }
        if let member, Self.targetFactories.contains(member),
           let nameLiteral = args.first(where: { $0.label?.text == "name" })?.expression.as(StringLiteralExprSyntax.self) {
            declaredPackageTargets.append(nameLiteral.segments.trimmedDescription)
        }
        guard let callee else { return .visitChildren }
        let isInit = member == nil || member == "init"
        if callee == "Date", isInit, args.isEmpty { hit("wallClock", "Date()", node) }
        if callee == "UUID", isInit, args.isEmpty { hit("randomIdentity", "UUID()", node) }
        if member == nil, Self.escapeCalls.contains(callee) { hit("escapeHatch", callee + "()", node) }
        if member == nil, Self.printCalls.contains(callee) { hit("printing", callee + "()", node) }
        if callee == "NSLocalizedString" || (callee == "String" && args.first?.label?.text == "localized") { hit("localization", "localized string", node) }
        if callee == "DispatchSemaphore" { hit("escapeHatch", "DispatchSemaphore", node) }
        if isInit, infrastructureTypes.contains(callee) { hit("infrastructureConstruction", callee + "(...)", node) }
        if callee == "unsafeFlags" { hit("unsafeFlags", "unsafeFlags", node) }
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let member = Self.name(node.declName.baseName)
        let base = node.base.flatMap { Self.unqualifiedPath($0)?.last }
        if member == "now", base == nil || base == "Date" { hit("wallClock", (base ?? "") + ".now", node) }
        if let base, Self.ambientMembers[base]?.contains(member) == true { hit("ambientEnvironment", "\(base).\(member)", node) }
        if let base, Self.infrastructureMembers[base] == member { hit("infrastructureConstruction", "\(base).\(member)", node) }
        if member == "assumeIsolated" { hit("escapeHatch", "assumeIsolated", node) }
        if member == "swiftLanguageMode" || member == "swiftLanguageVersion" || member == "v5" || member == "v4" || member == "v4_2" {
            if member.hasPrefix("v") { hit("swift5Mode", "." + member, node) }
        }
        return .visitChildren
    }

    override func visit(_ node: LabeledExprSyntax) -> SyntaxVisitorContinueKind {
        if let label = node.label?.text, label == "swiftLanguageVersions" || label == "swiftLanguageModes" || label == "swiftLanguageMode",
           node.expression.trimmedDescription.range(of: #"\.v[45]"#, options: .regularExpression) != nil {
            hit("swift5Mode", label, node)
        }
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let n = Self.name(node.baseName)
        // `Bundle.module` reads the package's own resources, which R13 requires; every other Bundle use is ambient.
        let ownResources = n == "Bundle" && node.parent?.as(MemberAccessExprSyntax.self).map { Self.name($0.declName.baseName) == "module" } == true
        if Self.ambientTypes.contains(n), !ownResources { hit("ambientEnvironment", n, node) }
        if n == "LocalizedStringResource" || n == "LocalizedStringKey" { hit("localization", n, node) }
        if Self.isTestDoubleName(n) { hit("testDouble", n, node) }
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        // Foundation.ProcessInfo, Dispatch.DispatchSemaphore: a module-qualified type is checked like a bare one.
        if let base = node.baseType.as(IdentifierTypeSyntax.self), Self.moduleQualifiers.contains(Self.name(base.name)) {
            checkType(Self.name(node.name), node)
        }
        return .visitChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        checkType(Self.name(node.name), node)
        return .visitChildren
    }

    private func checkType(_ n: String, _ node: some SyntaxProtocol) {
        if Self.ambientTypes.contains(n) { hit("ambientEnvironment", n, node) }
        if n == "LocalizedStringResource" || n == "LocalizedStringKey" { hit("localization", n, node) }
        if n == "DispatchSemaphore" { hit("escapeHatch", n, node) }
        if Self.isTestDoubleName(n) { hit("testDouble", n, node) }
    }

    // MARK: Resource bundles

    /// The names a bundle reserves for its own structure (R15), compared without case: the default macOS file system ignores it.
    static let reservedBundleNames: Set<String> = ["contents", "resources", "macos", "_codesignature"]

    /// `.copy` puts a directory at the root of the resource bundle under its last path component. `.process` flattens a
    /// directory's files to the root, so only `.copy` can put a reserved directory there. The path is the literal's value,
    /// as SwiftPM receives it: escapes decoded, multiline delimiters and line continuations removed.
    private func checkCopiedResource(_ node: FunctionCallExprSyntax) {
        guard let path = node.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue else {
            hit("bundleLayout", "the path of a copied resource must be a string literal without interpolation", node); return
        }
        if let entry = path.split(separator: "/").last(where: { $0 != "." }), Self.reservedBundleNames.contains(entry.lowercased()) {
            hit("bundleLayout", "copies \(entry)/ to the root of the resource bundle, a name the bundle's own structure uses", node)
        }
    }

    // MARK: Source tree

    /// `#filePath` and `#file` locate the source tree, which the machines that run a test plan do not have (R16). A
    /// `StaticString` parameter may default to one: that is how XCTest reports where an assertion failed, without reading it.
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        let name = Self.name(node.macroName)
        guard name == "filePath" || name == "file" else { return .visitChildren }
        let parameter = node.parent?.as(InitializerClauseSyntax.self)?.parent?.as(FunctionParameterSyntax.self)
        if parameter?.type.trimmedDescription != "StaticString" {
            hit("sourceTreePath", "#\(name) locates the source tree, which the machines that run the test plans do not have: read the file from a bundle", node)
        }
        return .visitChildren
    }

    // MARK: Declarations

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }),
           node.bindings.contains(where: { $0.pattern.trimmedDescription == "shared" }) { hit("singleton", "static shared", node.bindings) }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { declared(node.name, node); return .visitChildren }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { declared(node.name, node); return .visitChildren }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { declared(node.name, node); return .visitChildren }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { declared(node.name, node); return .visitChildren }

    private func declared(_ name: TokenSyntax, _ node: some SyntaxProtocol) {
        if Self.isTestDoubleName(Self.name(name)) { hit("testDouble", Self.name(name), name) }
    }

    static func isTestDoubleName(_ n: String) -> Bool {
        n.range(of: #"^(Mock|Fake|Stub|Test|Spy|Dummy)[A-Z]"#, options: .regularExpression) != nil
    }
}

import Foundation
