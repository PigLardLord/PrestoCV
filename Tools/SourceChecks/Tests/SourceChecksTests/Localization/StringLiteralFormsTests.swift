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

    var testDescription: String { name }

    static let all: [LiteralForm] = [
        LiteralForm(name: "plain", source: #""Save your CV""#, read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "multiline", source: "\"\"\"\n    Save your CV\n    \"\"\"", read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "raw #", source: ##"#"Save your CV"#"##, read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "raw ##", source: ###"##"Save your CV"##"###, read: ["Save your CV"], keys: ["Save your CV"], canBeLookedUp: true),
        LiteralForm(name: "with an interpolation", source: #""Save \(name) CV""#, read: [#"Save \(name) CV"#], keys: ["Save %@ CV"], canBeLookedUp: true),
        LiteralForm(name: "raw with an interpolation", source: ##"#"Save \#(name) CV"#"##, read: [#"Save \(name) CV"#], keys: ["Save %@ CV"], canBeLookedUp: true),
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

    var testDescription: String { name }

    static let all: [LiteralContext] = [
        LiteralContext(name: "Text(", wrap: { "Text(\($0))" }, isLookup: false),
        LiteralContext(name: "String(localized:", wrap: { "Text(String(localized: \($0)))" }, isLookup: true),
        LiteralContext(name: "LocalizedStringKey(", wrap: { "Text(LocalizedStringKey(\($0)))" }, isLookup: true),
        LiteralContext(name: "LocalizedStringResource(", wrap: { "Text(LocalizedStringResource(\($0)))" }, isLookup: true),
        LiteralContext(name: ".localized", wrap: { "Text(\($0).localized)" }, isLookup: true),
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
        var rules = rules ?? StringRules()
        if rules.viewFolders == nil { rules.everyLiteralInViews = true }
        let found = try StringChecks.run(catalog: catalog, sources: [source], rules: rules).lookedUpButMissing
        return found.map { entry in String(entry[..<(entry.range(of: " (", options: .backwards)?.lowerBound ?? entry.endIndex)]) }.sorted()
    }

    @Test("A literal missing from the catalog is reported, whatever its form and place; one in the catalog is not", arguments: LiteralCase.all)
    func everyFormInEveryPlace(_ testCase: LiteralCase) throws {
        let code = "struct V {\n    var body: some View {\n        \(testCase.context.wrap(testCase.form.source))\n    }\n}\n"
        let missing = try Self.reported(code: code, catalogKeys: ["plant.ok"])
        let present = try Self.reported(code: code, catalogKeys: ["plant.ok"] + testCase.form.keys)

        #expect(missing == testCase.form.read.sorted(), "missing from the catalog: \(missing)")
        #expect(present.isEmpty, "in the catalog: \(present)")
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
}
