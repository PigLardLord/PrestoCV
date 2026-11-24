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
    /// The aliases of an infrastructure type (`typealias Gate = DistributionGate`, qualified or not), which name it without
    /// its name: a call through one is a construction too, so the rules that restrict the type know the alias.
    private(set) var aliases: [(alias: String, type: String, line: Int)] = []
    /// In a manifest: the names of every target declaration, in every `#if` branch.
    private(set) var declaredPackageTargets: [String] = []
    private let converter: SourceLocationConverter
    private let infrastructureTypes: Set<String>
    /// The views of the file's target, from every file of it: an extension of a view in another file is part of the view.
    private let viewTypes: Set<String>
    /// What each type of the file's target declares, from every file of it: the properties and initialisers that tell
    /// what a contextual `.init(…)` makes (`MemberIndex`).
    let memberTypes: [String: TypeMembers]
    /// The suffixes of the names of services a view may not hold (R5), and of the dependencies a default argument may not
    /// make (R17). A trailing `Protocol` does not count.
    private let serviceSuffixes: [String], dependencySuffixes: [String]
    /// The imports of the file, and whether it declares or extends a view model (R5).
    private var importDecls: [ImportDeclSyntax] = []
    private var declaresViewModel = false
    /// R19: the actors and global actors of the file's target, the blocking calls, and the synchronous port requirements that
    /// are quick. `syncRequirements` lists every synchronous function requirement of a protocol in the file, as
    /// `Protocol.name(label:)`, so that the checker can refuse a quick requirement that no longer exists.
    private let concurrency: ConcurrencyIndex, longWorkCalls: [LongWorkCall], quickRequirements: Set<String>
    private(set) var syncRequirements: [String] = []

    static let ambientTypes: Set<String> = ["Bundle", "FileManager", "UserDefaults", "ProcessInfo", "NotificationCenter"]
    static let ambientMembers: [String: Set<String>] = [
        "Locale": ["current", "autoupdatingCurrent"], "TimeZone": ["current", "autoupdatingCurrent"],
        "Calendar": ["current", "autoupdatingCurrent"],
    ]
    static let infrastructureMembers: [String: String] = ["FileManager": "default", "Bundle": "main", "UserDefaults": "standard"]
    static let escapeCalls: Set<String> = ["fatalError", "precondition", "preconditionFailure", "unsafeBitCast"]
    static let printCalls: Set<String> = ["print", "debugPrint", "NSLog", "dump"]

    /// Modules that only Apple platforms have: a pure target that imports one does not build for Android (R18).
    static let appleOnlyModules: Set<String> = [
        "SwiftUI", "UIKit", "AppKit", "WatchKit", "Combine", "CryptoKit", "os", "OSLog", "NaturalLanguage", "FoundationModels", "PDFKit",
        "WebKit", "Vision", "VisionKit", "CoreGraphics", "CoreImage", "CoreText", "CoreML", "QuickLook", "QuickLookThumbnailing",
        "UniformTypeIdentifiers", "LinkPresentation", "MapKit", "Photos", "PhotosUI", "AVFoundation", "AVKit", "StoreKit", "Security",
        "LocalAuthentication", "CoreData", "SwiftData", "CloudKit", "Contacts", "EventKit", "UserNotifications", "Network", "CoreLocation",
        "MessageUI", "SafariServices", "AuthenticationServices", "Accelerate", "Metal", "QuartzCore", "ImageIO", "CoreServices",
        "MobileCoreServices", "SystemConfiguration", "CoreTransferable", "Translation", "Speech", "ObjectiveC", "Darwin",
    ]
    /// The Foundation types and members that only the full Foundation has, with ICU; FoundationEssentials does not (R18).
    static let fullFoundationTypes: Set<String> = [
        "NSRegularExpression", "NSRange", "JSONSerialization", "NSString", "NSMutableString", "DateFormatter", "NumberFormatter",
        "ISO8601DateFormatter", "DateComponentsFormatter", "DateIntervalFormatter", "RelativeDateTimeFormatter", "ListFormatter",
        "ByteCountFormatter", "MeasurementFormatter", "PersonNameComponentsFormatter",
    ]
    static let fullFoundationMembers: Set<String> = [
        "trimmingCharacters", "folding", "replacingOccurrences", "regularExpression", "localizedCompare",
        "localizedCaseInsensitiveCompare", "localizedStandardCompare",
    ]

    init(tree: SourceFileSyntax, file: String, infrastructureTypes: Set<String>, viewTypes: Set<String> = [],
         memberTypes: [String: TypeMembers] = [:], serviceSuffixes: [String] = [], dependencySuffixes: [String] = [],
         concurrency: ConcurrencyIndex = ConcurrencyIndex(), longWorkCalls: [LongWorkCall] = [], quickRequirements: Set<String> = []) {
        converter = SourceLocationConverter(fileName: file, tree: tree)
        self.infrastructureTypes = infrastructureTypes
        self.viewTypes = viewTypes
        self.memberTypes = memberTypes
        self.serviceSuffixes = serviceSuffixes
        self.dependencySuffixes = dependencySuffixes
        self.concurrency = concurrency
        self.longWorkCalls = longWorkCalls
        self.quickRequirements = quickRequirements
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

    static func name(_ token: TokenSyntax) -> String { token.text.trimmingCharacters(in: CharacterSet(charactersIn: "`")) }

    // MARK: Imports

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let first = node.path.first else { return .skipChildren }
        importDecls.append(node)
        let access = node.modifiers.map(\.name.text).first { ["public", "package", "internal", "fileprivate", "private"].contains($0) }
        imports.append((Self.name(first.name), node.startLocation(converter: converter).line, "import " + Self.name(first.name), access))
        if node.attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "_exported" }) {
            hit("exportedImport", "@_exported import", node)
        }
        if Self.appleOnlyModules.contains(Self.name(first.name)) {
            hit("appleOnlyImport", "\(Self.name(first.name)) exists only on Apple platforms, and a pure target builds for Android too", node)
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
        checkLongWork(node)
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
        if let path = Self.unqualifiedPath(node.calledExpression), constructsViewModel(path, node), isInView(node),
           !Self.isInDebugBranch(node) {
            hit("viewDependency", "a view makes no view model: it is given one, which the composition root makes", node)
        }
        guard let callee else { return .visitChildren }
        let isInit = member == nil || member == "init"
        if callee == "Date", isInit, args.isEmpty { hit("wallClock", "Date()", node) }
        if callee == "UUID", isInit, args.isEmpty { hit("randomIdentity", "UUID()", node) }
        if member == nil, Self.escapeCalls.contains(callee) { hit("escapeHatch", callee + "()", node) }
        if member == nil, Self.printCalls.contains(callee) { hit("printing", callee + "()", node) }
        if callee == "NSLocalizedString" || (callee == "String" && args.first?.label?.text == "localized") { hit("localization", "localized string", node) }
        if callee == "String", isInit, args.first?.label?.text == "format" { hit("fullFoundation", Self.needsFullFoundation("String(format:)"), node) }
        if callee == "DispatchSemaphore" { hit("escapeHatch", "DispatchSemaphore", node) }
        if isInit, infrastructureTypes.contains(callee) { hit("infrastructureConstruction", callee + "(...)", node) }
        // A module-qualified type (`DiagnosticTrace.DistributionGate()`) is the type; the qualifier is no module of the fixed list.
        if let member, member != "init", infrastructureTypes.contains(member) { hit("infrastructureConstruction", member + "(...)", node) }
        // A contextual `.init(...)` makes the type its context expects: `let gate: DistributionGate = .init()`.
        if callee == "", member == "init", let expected = expectedType(of: ExprSyntax(node)), infrastructureTypes.contains(expected) {
            hit("infrastructureConstruction", expected + "(...)", node)
        }
        if callee == "unsafeFlags" { hit("unsafeFlags", "unsafeFlags", node) }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        // Only an alias that names the type itself, qualified or not: `[Gate]` or `Wrapper<Gate>` is another type.
        var named = node.initializer.value
        while let attributed = named.as(AttributedTypeSyntax.self) { named = attributed.baseType }
        let direct = named.as(IdentifierTypeSyntax.self).flatMap { $0.genericArgumentClause == nil ? Self.name($0.name) : nil }
            ?? named.as(MemberTypeSyntax.self).flatMap { $0.genericArgumentClause == nil ? Self.name($0.name) : nil }
        if let type = direct, infrastructureTypes.contains(type) {
            aliases.append((Self.name(node.name), type, node.startLocation(converter: converter).line))
        }
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
        if Self.fullFoundationMembers.contains(member) { hit("fullFoundation", Self.needsFullFoundation(member), node.declName) }
        // A module-qualified type (`Foundation.Bundle.module`) is checked like a bare one.
        if let base = node.base?.as(DeclReferenceExprSyntax.self), Self.moduleQualifiers.contains(Self.name(base.baseName)) {
            checkPortability(member, node)
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
        checkPortability(n, node)
        checkViewReference(n, node)
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        // Foundation.ProcessInfo, Dispatch.DispatchSemaphore: a module-qualified type is checked like a bare one.
        if let base = node.baseType.as(IdentifierTypeSyntax.self), Self.moduleQualifiers.contains(Self.name(base.name)) {
            checkType(Self.name(node.name), node)
        }
        checkViewReference(Self.name(node.name), node)
        return .visitChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        checkType(Self.name(node.name), node)
        checkViewReference(Self.name(node.name), node)
        return .visitChildren
    }

    private func checkType(_ n: String, _ node: some SyntaxProtocol) {
        if Self.ambientTypes.contains(n) { hit("ambientEnvironment", n, node) }
        if n == "LocalizedStringResource" || n == "LocalizedStringKey" { hit("localization", n, node) }
        if n == "DispatchSemaphore" { hit("escapeHatch", n, node) }
        if Self.isTestDoubleName(n) { hit("testDouble", n, node) }
        checkPortability(n, node)
    }

    // MARK: Portability (R18)

    /// A pure target reads no bundle, not even its own (`Bundle.module`): an Android app has no SwiftPM resource bundle,
    /// so the edge reads the resources and passes them in through a port. A type that only the full Foundation has warns.
    private func checkPortability(_ n: String, _ node: some SyntaxProtocol) {
        if n == "Bundle" { hit("bundleAccess", Self.readsBundle, node) }
        if Self.fullFoundationTypes.contains(n) { hit("fullFoundation", Self.needsFullFoundation(n), node) }
    }

    static let readsBundle = "a pure target reads no bundle, not even Bundle.module: the edge reads the resources and passes them in through a port"

    static func needsFullFoundation(_ api: String) -> String {
        "\(api) needs the full Foundation, with ICU; FoundationEssentials alone does not have it"
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
    /// `StaticString` parameter may default to one, as long as it only reports where an assertion failed: see
    /// `onlyForwardsLocation`.
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        let name = Self.name(node.macroName)
        if name == "bundle" { hit("bundleAccess", Self.readsBundle, node) }
        guard name == "filePath" || name == "file" else { return .visitChildren }
        let parameter = node.parent?.as(InitializerClauseSyntax.self)?.parent?.as(FunctionParameterSyntax.self)
        if let parameter, parameter.type.trimmedDescription == "StaticString" {
            if !Self.onlyForwardsLocation(parameter) {
                hit("sourceTreePath", "#\(name) is used other than to report where an assertion failed: forward it, unchanged, only as the file: argument of a call", node)
            }
        } else {
            hit("sourceTreePath", "#\(name) locates the source tree, which the machines that run the test plans do not have: read the file from a bundle", node)
        }
        return .visitChildren
    }

    /// Whether every use of the parameter in its function forwards it, unchanged, as the `file:` argument of a call: that is
    /// how XCTest's assertions take the location they report. Any other use, such as `String(describing:)`, an
    /// interpolation, `.description` or `withUTF8Buffer`, or a copy into a variable or a tuple, can turn it into a path of
    /// the checkout.
    private static func onlyForwardsLocation(_ parameter: FunctionParameterSyntax) -> Bool {
        let name = name(parameter.secondName ?? parameter.firstName)
        guard name != "_" else { return true }
        var scope = parameter.parent
        while let node = scope, !node.is(FunctionDeclSyntax.self), !node.is(InitializerDeclSyntax.self),
              !node.is(SubscriptDeclSyntax.self), !node.is(MacroDeclSyntax.self) {
            scope = node.parent
        }
        guard let scope else { return false }
        return references(to: name, in: scope).allSatisfy { reference in
            guard let argument = reference.parent?.as(LabeledExprSyntax.self), argument.label?.text == "file" else { return false }
            return argument.parent?.parent?.is(FunctionCallExprSyntax.self) == true
        }
    }

    /// The references to a name under a node. The member `file` of another value (`report.file`) is not one.
    private static func references(to name: String, in node: Syntax) -> [DeclReferenceExprSyntax] {
        var found: [DeclReferenceExprSyntax] = []
        if let reference = node.as(DeclReferenceExprSyntax.self), Self.name(reference.baseName) == name,
           reference.parent?.as(MemberAccessExprSyntax.self).map({ $0.declName.id == reference.id }) != true {
            found.append(reference)
        }
        for child in node.children(viewMode: .sourceAccurate) { found += references(to: name, in: child) }
        return found
    }

    // MARK: Views and view models (R5)

    /// The protocols that make a type a view: `View`, and the representables that refine it.
    static let viewProtocols: Set<String> = ["View", "UIViewRepresentable", "UIViewControllerRepresentable", "NSViewRepresentable",
                                             "NSViewControllerRepresentable"]
    /// The frameworks a view model does not import. Combine and Observation are not UI frameworks.
    static let uiFrameworks: Set<String> = ["SwiftUI", "UIKit", "AppKit", "WatchKit"]

    /// Whether an inheritance clause names a view protocol, plain, module-qualified (`SwiftUI.View`) or in a composition
    /// (`Equatable & View`).
    static func declaresView(_ clause: InheritanceClauseSyntax?) -> Bool {
        clause?.inheritedTypes.contains { inherited in
            let types = inherited.type.as(CompositionTypeSyntax.self).map { $0.elements.map(\.type) } ?? [inherited.type]
            return types.contains { viewProtocols.contains(typeName($0) ?? "") }
        } ?? false
    }

    /// The name of a plain or member type (`View`, `SwiftUI.View`, `Outer.Inner` gives "Inner"), through the attributes of a
    /// parameter (`@escaping`, `inout`); nil for any other type.
    static func typeName(_ type: TypeSyntax) -> String? {
        if let t = type.as(AttributedTypeSyntax.self) { return typeName(t.baseType) }
        if let t = type.as(OptionalTypeSyntax.self) { return typeName(t.wrappedType) }
        if let t = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return typeName(t.wrappedType) }
        if let t = type.as(IdentifierTypeSyntax.self) { return name(t.name) }
        if let t = type.as(MemberTypeSyntax.self) { return name(t.name) }
        return nil
    }

    /// The names of the views a file declares, as a type that conforms to a view protocol or an extension that makes one.
    static func viewTypeNames(in tree: SourceFileSyntax) -> Set<String> {
        final class Collector: SyntaxVisitor {
            var names: Set<String> = []
            func add(_ name: String?, _ clause: InheritanceClauseSyntax?) { if let name, Scanner.declaresView(clause) { names.insert(name) } }
            override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { add(Scanner.name(node.name), node.inheritanceClause); return .visitChildren }
            override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { add(Scanner.name(node.name), node.inheritanceClause); return .visitChildren }
            override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { add(Scanner.name(node.name), node.inheritanceClause); return .visitChildren }
            override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { add(Scanner.typeName(node.extendedType), node.inheritanceClause); return .visitChildren }
        }
        let collector = Collector(viewMode: .sourceAccurate)
        collector.walk(tree)
        return collector.names
    }

    /// Whether a node is part of a view: inside a view's declaration, or inside an extension of a view.
    private func isInView(_ node: some SyntaxProtocol) -> Bool {
        var current = node.parent
        while let n = current {
            if let d = n.as(StructDeclSyntax.self), viewTypes.contains(Self.name(d.name)) || Self.declaresView(d.inheritanceClause) { return true }
            if let d = n.as(ClassDeclSyntax.self), viewTypes.contains(Self.name(d.name)) || Self.declaresView(d.inheritanceClause) { return true }
            if let d = n.as(EnumDeclSyntax.self), viewTypes.contains(Self.name(d.name)) || Self.declaresView(d.inheritanceClause) { return true }
            if let e = n.as(ExtensionDeclSyntax.self), viewTypes.contains(Self.typeName(e.extendedType) ?? "") || Self.declaresView(e.inheritanceClause) {
                return true
            }
            current = n.parent
        }
        return false
    }

    /// Whether a node is in the `#if DEBUG` branch of a condition, which only debug builds compile: where previews make their
    /// view models with fakes. A condition that only adds to DEBUG (`DEBUG && os(iOS)`) counts; `#else` and `!DEBUG` do not.
    static func isInDebugBranch(_ node: some SyntaxProtocol) -> Bool {
        var current = node.parent
        while let n = current {
            if let clause = n.as(IfConfigClauseSyntax.self), let condition = clause.condition?.trimmedDescription,
               !condition.contains("||"), !condition.contains("!"),
               condition.components(separatedBy: "&&").contains(where: { $0.trimmingCharacters(in: .whitespaces) == "DEBUG" }) {
                return true
            }
            current = n.parent
        }
        return false
    }

    /// The name as written, when it names a type whose name, without a trailing `Protocol`, ends with one of the suffixes.
    static func hasSuffix(_ n: String, in suffixes: [String]) -> Bool {
        guard n.first?.isUppercase == true else { return false }
        let base = n.hasSuffix("Protocol") ? String(n.dropLast("Protocol".count)) : n
        return suffixes.contains { base.hasSuffix($0) }
    }

    /// A view holds no use case, repository, service or dependency container: its view model does (R5). Another view of
    /// the target is not one, whatever its name (`ViewStateContainer`).
    private func checkViewReference(_ n: String, _ node: some SyntaxProtocol) {
        guard Self.hasSuffix(n, in: serviceSuffixes), !viewTypes.contains(n), isInView(node), !Self.isInDebugBranch(node) else { return }
        hit("viewDependency", "a view holds no \(n): its view model does, and the composition root makes it", node)
    }

    static func isViewModelName(_ n: String) -> Bool { n.first?.isUppercase == true && n.hasSuffix("ViewModel") }

    /// `ListViewModel(…)`, `PrestoCVPresentation.ListViewModel(…)`, `ListViewModel.init(…)`, or `.init(…)` where the
    /// context expects a view model.
    private func constructsViewModel(_ path: [String], _ call: FunctionCallExprSyntax) -> Bool {
        if let last = path.last, Self.isViewModelName(last), path.dropLast().allSatisfy({ $0.first?.isUppercase == true }) {
            return true
        }
        guard path.last == "init" else { return false }
        if path.count >= 2, !path[path.count - 2].isEmpty { return Self.isViewModelName(path[path.count - 2]) }
        return expectedType(of: ExprSyntax(call)).map(Self.isViewModelName) ?? false
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if Self.isViewModelName(Self.typeName(node.extendedType) ?? "") { declaresViewModel = true }
        return .visitChildren
    }

    /// A file that declares or extends a view model imports no UI framework, in any form (R5).
    override func visitPost(_ node: SourceFileSyntax) {
        guard declaresViewModel else { return }
        for decl in importDecls {
            guard let module = decl.path.first.map({ Self.name($0.name) }), Self.uiFrameworks.contains(module) else { continue }
            hit("viewModelImport", "a view model imports no UI framework, and \(module) is one: Combine, Observation and Foundation are not", decl)
        }
    }

    // MARK: Default arguments (R17)

    /// A default argument that makes a dependency or reads ambient state hides it from the caller, and from tests: every
    /// dependency comes in through the initialiser, from the composition root.
    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        if let value = node.defaultValue?.value, let reason = hiddenDependency(value, type: node.type) {
            let parameter = Self.name(node.secondName ?? node.firstName)
            hit("defaultDependency", "the default of \(parameter) \(reason): take it as an argument, which the composition root passes", node)
        }
        return .visitChildren
    }

    /// Members of `URL` that are directories of the device.
    static let deviceDirectories: Set<String> = [
        "applicationSupportDirectory", "temporaryDirectory", "documentsDirectory", "cachesDirectory", "homeDirectory", "desktopDirectory",
        "downloadsDirectory", "libraryDirectory", "moviesDirectory", "musicDirectory", "picturesDirectory", "sharedPublicDirectory",
        "trashDirectory", "userDirectory", "applicationDirectory", "currentDirectory",
    ]

    /// Why a default value is a hidden dependency; nil when it is a plain value. Nil is always a plain value.
    private func hiddenDependency(_ value: ExprSyntax, type: TypeSyntax) -> String? {
        if value.is(NilLiteralExprSyntax.self) { return nil }
        let typeName = Self.baseTypeName(type)
        if let typeName, Self.hasSuffix(typeName, in: dependencySuffixes) || infrastructureTypes.contains(typeName) {
            return "makes a \(typeName)"
        }
        if let typeName, Self.ambientTypes.contains(typeName), Self.unqualifiedPath(value).map({ $0 != ["", "module"] && $0 != ["Bundle", "module"] }) ?? true {
            return "is the device's \(typeName)"
        }
        if let closure = value.as(ClosureExprSyntax.self) {
            if !Self.isConstant(closure) { return "is a closure, which does the real work" }
        } else if Self.isFunctionType(type), value.is(DeclReferenceExprSyntax.self) || value.is(MemberAccessExprSyntax.self) {
            return "is a function, which does the real work"
        }
        let finder = AmbientFinder(type: type, scanner: self)
        finder.walk(value)
        return finder.reason
    }

    /// Whether a closure does nothing, or only answers a literal (`{ _ in true }`, `{ nil }`): a value, not a dependency.
    static func isConstant(_ closure: ClosureExprSyntax) -> Bool {
        guard let only = closure.statements.first else { return true }
        guard closure.statements.count == 1, let expr = only.item.as(ExprSyntax.self) else { return false }
        return expr.is(BooleanLiteralExprSyntax.self) || expr.is(NilLiteralExprSyntax.self) || expr.is(IntegerLiteralExprSyntax.self)
            || expr.is(FloatLiteralExprSyntax.self) || (expr.as(StringLiteralExprSyntax.self).map { $0.segments.allSatisfy { $0.is(StringSegmentSyntax.self) } } ?? false)
    }

    /// The type of a parameter without optionality, attributes, `some` or `any`, parentheses and a trailing `Protocol`.
    static func baseTypeName(_ type: TypeSyntax) -> String? {
        if let t = type.as(OptionalTypeSyntax.self) { return baseTypeName(t.wrappedType) }
        if let t = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return baseTypeName(t.wrappedType) }
        if let t = type.as(AttributedTypeSyntax.self) { return baseTypeName(t.baseType) }
        if let t = type.as(SomeOrAnyTypeSyntax.self) { return baseTypeName(t.constraint) }
        if let t = type.as(TupleTypeSyntax.self), t.elements.count == 1, let only = t.elements.first { return baseTypeName(only.type) }
        return typeName(type)
    }

    /// Whether a parameter takes a function: its type is a function type, or is `@escaping`, which only a function can be.
    static func isFunctionType(_ type: TypeSyntax) -> Bool {
        if let t = type.as(OptionalTypeSyntax.self) { return isFunctionType(t.wrappedType) }
        if let t = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return isFunctionType(t.wrappedType) }
        if let t = type.as(AttributedTypeSyntax.self) {
            return t.attributes.contains { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "escaping" } || isFunctionType(t.baseType)
        }
        if let t = type.as(TupleTypeSyntax.self), t.elements.count == 1, let only = t.elements.first { return isFunctionType(only.type) }
        return type.is(FunctionTypeSyntax.self)
    }

    /// Finds, anywhere in a default value, what reads the device or makes a dependency.
    private final class AmbientFinder: SyntaxVisitor {
        private(set) var reason: String?
        private let typeText: String
        private unowned let scanner: Scanner
        init(type: TypeSyntax, scanner: Scanner) {
            typeText = type.trimmedDescription; self.scanner = scanner
            super.init(viewMode: .sourceAccurate)
        }
        private func found(_ why: String) { if reason == nil { reason = why } }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let path = Scanner.unqualifiedPath(node.calledExpression) else { return .visitChildren }
            let isInit = path.count == 1 || path.last == "init"
            let type = path.count == 1 ? path[0] : path[path.count - 2]
            if isInit, type == "Date", node.arguments.isEmpty { found("reads the clock") }
            if isInit, type == "ContinuousClock" || type == "SuspendingClock" { found("is the real clock") }
            if path == ["NSTemporaryDirectory"] || path == ["NSHomeDirectory"] { found("reads the file system") }
            if path == ["NSLocalizedString"] || (isInit && type == "String" && node.arguments.first?.label?.text == "localized") {
                found("reads the app's language")
            }
            if isInit, Scanner.hasSuffix(type, in: scanner.dependencySuffixes) || scanner.infrastructureTypes.contains(type) { found("makes a \(type)") }
            return .visitChildren
        }

        override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            let member = Scanner.name(node.declName.baseName)
            let base = node.base.flatMap { Scanner.unqualifiedPath($0)?.last }
            if member == "now", base == nil || base == "Date" { found("reads the clock") }
            if member == "current" || member == "autoupdatingCurrent" {
                if let base, ["Locale", "TimeZone", "Calendar"].contains(base) { found("reads the device's \(base)") }
                if base == nil, member == "autoupdatingCurrent" || typeText.range(of: #"\b(Locale|TimeZone|Calendar)\b"#, options: .regularExpression) != nil {
                    found("reads the device's settings")
                }
            }
            if base == "Locale", member == "preferredLanguages" { found("reads the person's languages") }
            if base == "Task", member == "sleep" { found("waits on the real clock") }
            if member == "continuous" || member == "suspending", base == nil || base == "ContinuousClock" || base == "SuspendingClock" {
                found("is the real clock")
            }
            if Scanner.deviceDirectories.contains(member), base == nil || base == "URL" { found("reads the file system") }
            return .visitChildren
        }

        override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            let n = Scanner.name(node.baseName)
            let ownResources = n == "Bundle" && node.parent?.as(MemberAccessExprSyntax.self).map { Scanner.name($0.declName.baseName) == "module" } == true
            if Scanner.ambientTypes.contains(n), !ownResources { found("reads the device's \(n)") }
            if n == "LocalizedStringResource" || n == "LocalizedStringKey" { found("reads the app's language") }
            if Scanner.hasSuffix(n, in: scanner.dependencySuffixes) || scanner.infrastructureTypes.contains(n) { found("names a \(n)") }
            return .visitChildren
        }
    }

    // MARK: Long work (R19)

    /// A function requirement of a protocol is `async`, or listed as quick (R19p); an `async` function that no actor isolates
    /// leaves its caller's actor on purpose, with `@concurrent` (R19c).
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !Self.isInDebugBranch(node) else { return .visitChildren }
        let isAsync = node.signature.effectSpecifiers?.asyncSpecifier != nil
        if let proto = Self.enclosingTypeDecl(of: node)?.as(ProtocolDeclSyntax.self) {
            guard !isAsync else { return .visitChildren }
            let labels = node.signature.parameterClause.parameters.map { Self.name($0.firstName) + ":" }.joined()
            let requirement = "\(Self.name(proto.name)).\(Self.name(node.name))(\(labels))"
            syncRequirements.append(requirement)
            if !quickRequirements.contains(requirement) {
                hit("synchronousPortRequirement", "\(requirement) is not async: make it async, or list it under quickRequirements with the reason it is quick", node)
            }
            return .visitChildren
        }
        guard isAsync else { return .visitChildren }
        if node.modifiers.contains(where: { $0.name.text == "nonisolated" && $0.detail?.detail.text == "nonsending" }) {
            hit("concurrentByDefault", "nonisolated(nonsending) runs on the caller's actor: mark the function @concurrent", node)
        } else if !Self.hasAttribute("concurrent", node.attributes), !isIsolated(node) {
            hit("concurrentByDefault", "\(Self.name(node.name)) is async and no actor isolates it: mark it @concurrent, so that it leaves its caller's actor whatever the setting", node)
        }
        return .visitChildren
    }

    private static func hasAttribute(_ name: String, _ attributes: AttributeListSyntax) -> Bool {
        attributes.contains { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name }
    }

    /// The nearest type, extension or protocol a declaration is a member of.
    private static func enclosingTypeDecl(of node: some SyntaxProtocol) -> Syntax? {
        var current = node.parent
        while let n = current {
            if n.is(StructDeclSyntax.self) || n.is(ClassDeclSyntax.self) || n.is(EnumDeclSyntax.self) || n.is(ActorDeclSyntax.self)
                || n.is(ProtocolDeclSyntax.self) || n.is(ExtensionDeclSyntax.self) { return n }
            current = n.parent
        }
        return nil
    }

    /// Whether an actor isolates the function: it is declared in an actor, in an extension of one of the target's actors, or
    /// in or on a type or function marked with a global actor; or it takes an `isolated` parameter. `nonisolated` takes the
    /// function out of its type's isolation, but not out of its own attribute or parameter.
    private func isIsolated(_ function: FunctionDeclSyntax) -> Bool {
        if function.signature.parameterClause.parameters.contains(where: { $0.type.trimmedDescription.hasPrefix("isolated ") }) { return true }
        if hasGlobalActor(function.attributes) { return true }
        if function.modifiers.contains(where: { $0.name.text == "nonisolated" }) { return false }
        var current = function.parent
        while let n = current {
            if n.is(ActorDeclSyntax.self) { return true }
            if let e = n.as(ExtensionDeclSyntax.self), concurrency.actors.contains(Self.typeName(e.extendedType) ?? "") { return true }
            if let d = n.as(StructDeclSyntax.self), hasGlobalActor(d.attributes) { return true }
            if let d = n.as(ClassDeclSyntax.self), hasGlobalActor(d.attributes) { return true }
            if let d = n.as(EnumDeclSyntax.self), hasGlobalActor(d.attributes) { return true }
            if let e = n.as(ExtensionDeclSyntax.self), hasGlobalActor(e.attributes) { return true }
            if let f = n.as(FunctionDeclSyntax.self), hasGlobalActor(f.attributes) { return true }
            current = n.parent
        }
        return false
    }

    private func hasGlobalActor(_ attributes: AttributeListSyntax) -> Bool {
        attributes.contains { attribute in
            guard let name = attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription else { return false }
            return concurrency.globalActors.contains(name)
        }
    }

    /// A call of `longWorkCalls` runs on the main actor unless it is in a `@concurrent` function or in an actor.
    private func checkLongWork(_ node: FunctionCallExprSyntax) {
        guard let call = longWorkCalls.first(where: { $0.matches(node) }), !isOffTheMainActor(node), !Self.isInDebugBranch(node) else { return }
        hit("mainActorLongWork", "\(call.text) blocks the thread that runs it: call it from a @concurrent function or an actor, which a port reaches", node)
    }

    private func isOffTheMainActor(_ node: some SyntaxProtocol) -> Bool {
        var current = node.parent
        while let n = current {
            if n.is(ActorDeclSyntax.self) { return true }
            if let e = n.as(ExtensionDeclSyntax.self), concurrency.actors.contains(Self.typeName(e.extendedType) ?? "") { return true }
            if let f = n.as(FunctionDeclSyntax.self), Self.hasAttribute("concurrent", f.attributes) { return true }
            current = n.parent
        }
        return false
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
        if Self.isViewModelName(Self.name(name)) { declaresViewModel = true }
    }

    static func isTestDoubleName(_ n: String) -> Bool {
        n.range(of: #"^(Mock|Fake|Stub|Test|Spy|Dummy)[A-Z]"#, options: .regularExpression) != nil
    }
}

import Foundation
