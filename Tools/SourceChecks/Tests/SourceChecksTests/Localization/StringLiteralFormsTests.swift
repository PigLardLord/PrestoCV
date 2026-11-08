import Foundation
import Testing

// Every form of a string literal in every place it can stand: the string checks read them through one lexer, so a form
// that escapes the scan in one place is a defect of the lexer. The table is the literal forms times the contexts times
// the catalog having the key or missing it.

/// A literal form: how it is written, the literals the checks must read from it, and the catalog keys that name them.
struct LiteralForm: Sendable, CustomTestStringConvertible {
    let name: String
    let source: String
    /// The literals with words that the checks read, as the checks name them. An interpolation reads `\(name)`.
    let read: [String]
    /// The catalog keys under which each of `read` passes.
    let keys: [String]
    /// Whether the literal as a whole can be the argument of a lookup, i.e. it holds the text itself.
    let canBeLookedUp: Bool
    /// The placeholders the rules declare for its literal with values, so that a lookup of it can be found.
    var valueTypes: [String: ValueTypes] = [:]

    /// Whether the literal holds a value: its catalog key is then not its text.
    var hasValue: Bool { keys != read }

    var testDescription: String { name }

    static let all: [LiteralForm] = [
        LiteralForm(name: "plain", source: #""Save your CV""#, read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "multiline", source: "\"\"\"\n    Save your CV\n    \"\"\"", read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "raw #", source: ##"#"Save your CV"#"##, read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "raw ##", source: ###"##"Save your CV"##"###, read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "with an interpolation", source: #""Save \(name) CV""#, read: [#"Save \(name) CV"#], keys: ["Save %@ CV"], canBeLookedUp: true,
            valueTypes: [#"Save \(name) CV"#: ValueTypes(["%@"], "name is a String")]),
        LiteralForm(name: "raw with an interpolation", source: ##"#"Save \#(name) CV"#"##, read: [#"Save \(name) CV"#], keys: ["Save %@ CV"], canBeLookedUp: true,
            valueTypes: [#"Save \(name) CV"#: ValueTypes(["%@"], "name is a String")]),
        LiteralForm(
            name: "nested in an interpolation", source: #""\(isReady ? "Save your CV" : "Try again")""#,
            read: ["Save your CV", "Try again"], keys: ["Save your CV", "Try again"], canBeLookedUp: false),
        LiteralForm(
            name: "nested two deep", source: #""\(a ? "\(b ? "Save your CV" : "Try again")" : "Other words")""#,
            read: ["Save your CV", "Try again", "Other words"], keys: ["Save your CV", "Try again", "Other words"], canBeLookedUp: false),
    ]
}

/// A place where a literal stands: the code around `literal`.
struct LiteralContext: Sendable, CustomTestStringConvertible {
    let name: String
    let wrap: @Sendable (String) -> String
    /// A lookup is not read by the every-literal rule, but its key must be in the catalog.
    let isLookup: Bool
    /// A String extension receives the String already built, with each value filled in: it asks the catalog for the
    /// filled-in text, so a literal with a value is never found, whatever key the catalog has.
    var fillsInValues = false

    var testDescription: String { name }

    static let all: [LiteralContext] = [
        LiteralContext(name: "Text(", wrap: { "Text(\($0))" }, isLookup: false),
        LiteralContext(name: "String(localized:", wrap: { "Text(String(localized: \($0)))" }, isLookup: true),
        LiteralContext(name: "LocalizedStringKey(", wrap: { "Text(LocalizedStringKey(\($0)))" }, isLookup: true),
        LiteralContext(name: "LocalizedStringResource(", wrap: { "Text(LocalizedStringResource(\($0)))" }, isLookup: true),
        LiteralContext(name: ".localized", wrap: { "Text(\($0).localized)" }, isLookup: true, fillsInValues: true),
        LiteralContext(name: ".localizedWithArgs(", wrap: { "Text(\($0).localizedWithArgs(count))" }, isLookup: true, fillsInValues: true),
        LiteralContext(name: ".asLoclizedKey", wrap: { "Text(\($0).asLoclizedKey)" }, isLookup: true, fillsInValues: true),
        LiteralContext(name: "a ternary", wrap: { "Text(isReady ? \($0) : \"plant.ok\")" }, isLookup: false),
        LiteralContext(name: "a local let", wrap: { "let heading = \($0)\nText(heading)" }, isLookup: false),
        LiteralContext(name: "an argument label", wrap: { "Banner(title: \($0))" }, isLookup: false),
        LiteralContext(name: ".uppercased()", wrap: { "Text(\($0).uppercased())" }, isLookup: false),
        LiteralContext(name: "a concatenation with +", wrap: { "Text(\($0) + \"plant.ok\")" }, isLookup: false),
    ]
}

struct LiteralCase: Sendable, CustomTestStringConvertible {
    let form: LiteralForm
    let context: LiteralContext

    var testDescription: String { "\(form.name) in \(context.name)" }

    static let all: [LiteralCase] = LiteralForm.all.flatMap { form in
        LiteralContext.all.compactMap { context in
            context.isLookup && !form.canBeLookedUp ? nil : LiteralCase(form: form, context: context)
        }
    }
}

@Suite("The string checks read every form of string literal, wherever it stands")
struct StringLiteralFormsTests {
    /// Runs the checks on `code` and a catalog with `keys`, and returns the literals reported as not looked up.
    static func reported(code: String, catalogKeys keys: [String], rules: StringRules? = nil) throws -> [String] {
        let found = try findings(code: code, catalogKeys: keys, rules: rules).lookedUpButMissing
        return found.map { entry in String(entry[..<(entry.range(of: " (", options: .backwards)?.lowerBound ?? entry.endIndex)]) }.sorted()
    }

    /// Runs the checks on `code` and a catalog with `keys`.
    static func findings(code: String, catalogKeys keys: [String], rules: StringRules? = nil) throws -> StringFindings {
        try withFiles(code: code, catalogKeys: keys) { catalog, source in
            try StringChecks.run(catalog: catalog, sources: [source], rules: Self.viewRules(rules))
        }
    }

    /// The exemptions of `rules` that exempt nothing in `code` and a catalog with `keys`.
    static func stale(code: String, catalogKeys keys: [String], rules: StringRules) throws -> [String] {
        try withFiles(code: code, catalogKeys: keys) { catalog, source in
            try StringChecks.staleExemptions(catalog: catalog, sources: [source], rules: Self.viewRules(rules))
        }
    }

    /// The rules with every literal of the views read, unless they name the view folders.
    private static func viewRules(_ rules: StringRules?) -> StringRules {
        var rules = rules ?? StringRules()
        if rules.viewFolders == nil { rules.everyLiteralInViews = true }
        return rules
    }

    /// Writes a catalog with `keys` and a source with `code` to a new folder, runs `body` on them and removes the folder.
    private static func withFiles<T>(code: String, catalogKeys keys: [String], _ body: (URL, URL) throws -> T) throws -> T {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("literal-forms-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var strings: [String: Any] = [:]
        for key in keys {
            strings[key] = ["localizations": ["en": ["stringUnit": ["state": "translated", "value": key]]]]
        }
        let catalog = folder.appendingPathComponent("Localizable.xcstrings")
        try JSONSerialization.data(withJSONObject: ["sourceLanguage": "en", "version": "1.0", "strings": strings]).write(to: catalog)
        let source = folder.appendingPathComponent("View.swift")
        try code.write(to: source, atomically: true, encoding: .utf8)
        return try body(catalog, source)
    }

    @Test("A literal missing from the catalog is reported, whatever its form and place; one in the catalog is not", arguments: LiteralCase.all)
    func everyFormInEveryPlace(_ testCase: LiteralCase) throws {
        let code = "struct V {\n    var body: some View {\n        \(testCase.context.wrap(testCase.form.source))\n    }\n}\n"
        var rules = StringRules()
        rules.valueTypes = testCase.form.valueTypes
        let missing = try Self.reported(code: code, catalogKeys: ["plant.ok"], rules: rules)
        let present = try Self.reported(code: code, catalogKeys: ["plant.ok"] + testCase.form.keys, rules: rules)

        let neverFound = testCase.context.fillsInValues && testCase.form.hasValue
        #expect(missing == testCase.form.read.sorted(), "missing from the catalog: \(missing)")
        #expect(present == (neverFound ? testCase.form.read.sorted() : []), "in the catalog: \(present)")
    }

    @Test("A literal with a value looked up by a String extension is reported even with its format key in the catalog", arguments: [".localized", ".localizedWithArgs(count)", ".asLoclizedKey"])
    func extensionLookupOfAValue(_ call: String) throws {
        let withValue = "Text(\"Hello \\(name)\"\(call))\n"
        let withoutValue = "Text(\"Hello %@\"\(call))\n"

        #expect(try Self.reported(code: withValue, catalogKeys: ["Hello %@", "Hello %lld"]) == ["Hello \\(name)"])
        #expect(try Self.reported(code: withoutValue, catalogKeys: ["Hello %@"]).isEmpty)
    }

    @Test("A format key that only a String extension lookup of a literal with a value names is unused: the extension never asks for it")
    func extensionLookupDoesNotUseTheFormatKey() throws {
        var rules = StringRules()
        rules.valueTypes = ["Hello \\(name)": ValueTypes(["%@"], "name is a String")]
        let byExtension = try Self.findings(code: "Text(\"Hello \\(name)\".localized)\n", catalogKeys: ["Hello %@"], rules: rules)
        let byInitializer = try Self.findings(code: "Text(String(localized: \"Hello \\(name)\"))\n", catalogKeys: ["Hello %@"], rules: rules)

        #expect(byExtension.unused == ["Hello %@"])
        #expect(byInitializer.unused.isEmpty)
    }

    /// Rules that declare a text value and a number value for `shell.numbered \(title) \(number)`.
    private static let numberedRules: StringRules = {
        var rules = StringRules()
        rules.valueTypes = ["shell.numbered \\(title) \\(number)": ValueTypes(["%@", "%lld"], "title is a String, number an Int")]
        return rules
    }()

    @Test("A format lookup with a text value and a number value is found under its declared mixed key, which counts as used")
    func formatWithValuesOfTwoTypes() throws {
        let code = "let s = String(localized: \"shell.numbered \\(title) \\(number)\")\n"
        let mixed = try Self.findings(code: code, catalogKeys: ["shell.numbered %@ %lld"], rules: Self.numberedRules)

        #expect(mixed.lookedUpButMissing.isEmpty && mixed.unused.isEmpty)
    }

    @Test("A catalog key with the placeholders of a format swapped is reported missing and unused: the app never asks for it")
    func formatWithItsPlaceholdersSwapped() throws {
        let lookup = "let s = String(localized: \"shell.numbered \\(title) \\(number)\")\n"
        let view = "Text(\"shell.numbered \\(title) \\(number)\")\n"

        for code in [lookup, view] {
            let swapped = try Self.findings(code: code, catalogKeys: ["shell.numbered %lld %@"], rules: Self.numberedRules)
            #expect(try Self.reported(code: code, catalogKeys: ["shell.numbered %lld %@"], rules: Self.numberedRules) == ["shell.numbered \\(title) \\(number)"])
            #expect(swapped.unused == ["shell.numbered %lld %@"])
        }
    }

    @Test("A literal with values whose placeholders are not declared is reported with the hint, whatever keys the catalog has")
    func undeclaredValues() throws {
        let hint = ": declare the type of each value in valueTypes"
        for code in ["Text(String(localized: \"Hello \\(name)\"))\n", "Text(\"Hello \\(name)\")\n"] {
            let found = try Self.findings(code: code, catalogKeys: ["Hello %@", "Hello %lld"])
            #expect(found.lookedUpButMissing.count == 1 && found.lookedUpButMissing.allSatisfy { $0.hasPrefix("Hello \\(name) (") && $0.hasSuffix(hint) }, "\(found.lookedUpButMissing)")
            #expect(found.unused == ["Hello %@", "Hello %lld"])
        }
        let byExtension = try Self.findings(code: "Text(\"Hello \\(name)\".localized)\n", catalogKeys: [])
        #expect(byExtension.lookedUpButMissing.allSatisfy { !$0.hasSuffix(hint) }, "a String extension never finds a value, declared or not")
    }

    @Test("A literal with seven values of mixed types is found under its declared key, and reported when undeclared")
    func sevenMixedValues() throws {
        let code = "let s = String(localized: \"seven \\(a) \\(b) \\(c) \\(d) \\(e) \\(f) \\(g)\")\n"
        let key = "seven %@ %lld %@ %lld %@ %lld %@"
        var rules = StringRules()
        rules.valueTypes = ["seven \\(a) \\(b) \\(c) \\(d) \\(e) \\(f) \\(g)": ValueTypes(["%@", "%lld", "%@", "%lld", "%@", "%lld", "%@"], "a planted mix")]

        let declared = try Self.findings(code: code, catalogKeys: [key], rules: rules)
        let undeclared = try Self.findings(code: code, catalogKeys: [key])
        #expect(declared.lookedUpButMissing.isEmpty && declared.unused.isEmpty)
        #expect(undeclared.lookedUpButMissing.count == 1 && undeclared.unused == [key])
    }

    @Test("A declaration of placeholders that no checked literal needs, or that does not fit its literal, is stale")
    func staleValueTypes() throws {
        let code = "Text(String(localized: \"Hello \\(name)\"))\nlet s = \"Plain \\(x)\".localized\n"
        func stale(_ text: String, _ placeholders: [String], keys: [String] = ["Hello %@"]) throws -> [String] {
            var rules = StringRules()
            rules.valueTypes = [text: ValueTypes(placeholders, "a planted declaration")]
            return try Self.stale(code: code, catalogKeys: keys, rules: rules)
        }

        #expect(try stale("Hello \\(name)", ["%@"]).isEmpty)
        #expect(try stale("Gone \\(x)", ["%@"]) == [#""Gone \(x)" is in no checked source as a format with values: remove it from valueTypes"#])
        #expect(try stale("Plain \\(x)", ["%@"]) == [#""Plain \(x)" is in no checked source as a format with values: remove it from valueTypes"#])
        #expect(try stale("Hello \\(name)", ["%@", "%lld"]) == [#""Hello \(name)" declares 2 placeholders for its 1 value: correct it in valueTypes"#])
        #expect(try stale("Hello \\(name)", ["%s"], keys: ["Hello %s"]) == [#""Hello \(name)" declares %s, which is not a placeholder: correct it in valueTypes"#])
        #expect(try stale("Hello \\(name)", ["%lld"]) == [#""Hello \(name)" builds the key Hello %lld, which the catalog lacks: correct it in valueTypes"#])
    }

    @Test("The name of an SF Symbol handed to a view as symbol: is not text to translate")
    func symbolArgument() throws {
        let code = "struct V {\n    var body: some View {\n        EmptyStateView(symbol: \"doc.text\", title: \"plant.ok\", message: \"plant.ok\")\n    }\n}\n"

        #expect(try Self.reported(code: code, catalogKeys: ["plant.ok"]).isEmpty)
    }

    @Test("Both English alternatives of a ternary inside an interpolation are reported")
    func ternaryInsideAnInterpolation() throws {
        let code = "Text(\"\\(isReady ? \"Save your CV\" : \"Try again\")\")\n"

        #expect(try Self.reported(code: code, catalogKeys: []) == ["Save your CV", "Try again"])
        #expect(try Self.reported(code: code, catalogKeys: ["Save your CV", "Try again"]).isEmpty)
    }

    @Test("A raw lookup with no catalog entry is reported, and passes with one")
    func rawLookup() throws {
        let code = "Text(String(localized: #\"Save your CV\"#))\n"

        #expect(try Self.reported(code: code, catalogKeys: []) == ["Save your CV"])
        #expect(try Self.reported(code: code, catalogKeys: ["Save your CV"]).isEmpty)
    }

    @Test("A multiline lookup with no catalog entry is reported, and passes with one")
    func multilineLookup() throws {
        let code = "Text(String(localized: \"\"\"\n    Save your CV\n    \"\"\"))\n"

        #expect(try Self.reported(code: code, catalogKeys: []) == ["Save your CV"])
        #expect(try Self.reported(code: code, catalogKeys: ["Save your CV"]).isEmpty)
    }

    @Test("A literal that holds // is text, and is read")
    func slashesInsideALiteral() throws {
        let code = "Text(\"Visit https://example.com today\")\nText(\"\"\"\n    // Not a comment here\n    \"\"\")\n"

        #expect(try Self.reported(code: code, catalogKeys: []) == ["// Not a comment here", "Visit https://example.com today"])
    }

    @Test("A literal inside a comment is skipped, nested block comments included")
    func literalsInsideComments() throws {
        let code = """
            /* Text("Hidden words") */
            /* outer /* inner */ Text("Still hidden") */
            // Text("Line comment")
            Text("Shown words") /* Text("After it") */
            """

        #expect(try Self.reported(code: code, catalogKeys: []) == ["Shown words"])
    }

    @Test("A quote or a comment marker inside a literal does not end the code around it")
    func markersInsideLiterals() throws {
        let code = "let a = \"/*\"\nText(\"Real words\")\nlet b = \"*/\"\n"

        #expect(try Self.reported(code: code, catalogKeys: []) == ["Real words"])
    }

    @Test("The lexer decodes escapes and indentation, gives the key of a value, and the context of each literal")
    func lexerDetails() {
        let code = "Text(\"a\\tb \\\"q\\\" \\(n + 1)\")\nlet x = \"\"\"\n    one\n      two \\(n)\n    \"\"\"\nBanner(title: #\"raw \\n \\#(m)\"#)"
        let found = StringLiteralLexer.literals(in: code)

        #expect(found.map(\.text) == ["a\tb \"q\" \\(n + 1)", "one\n  two \\(n)", "raw \\n \\(m)"])
        #expect(found.map(\.key) == ["a\tb \"q\" %@", "one\n  two %@", "raw \\n %@"])
        #expect(found[0].formatParts == ["a\tb \"q\" ", ""] && found[0].formatKey(["%lld"]) == "a\tb \"q\" %lld")
        let two = StringLiteralLexer.literals(in: "\"\\(a) of \\(b)\"")[0]
        #expect(two.formatParts == ["", " of ", ""] && two.valueCount == 2)
        #expect(two.formatKey(["%lld", "%@"]) == "%lld of %@" && two.formatKey(["%@"]) == nil)
        #expect(found[0].before == "Text(" && found[2].before.hasSuffix("title:"))
    }
}
