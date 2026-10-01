import Testing

/// A JSON document and what the schema and the exporter (`CVDocumentValidator.decode(json:)`) each say about it.
struct DocumentCase: Sendable, CustomTestStringConvertible {
    enum Agreement: Sendable {
        /// Both accept it.
        case valid
        /// Both refuse it.
        case invalid
        /// The schema accepts it and the exporter refuses it on this rule, which JSON Schema cannot express exactly and
        /// the validator alone enforces.
        case beyondSchema(Exporter.Rule)
    }

    let name: String, json: String, agreement: Agreement
    var testDescription: String { name }
}

/// Documents built as JSON text, so that a case can be wrong in ways the Swift model cannot express.
enum DocumentCases {
    static let all: [DocumentCase] = {
        var all: [DocumentCase] = []
        valid(&all)
        invalid(&all)
        beyondSchema(&all)
        return all
    }()

    // MARK: Building documents

    static func document(version: String = "1", language: String = #""en""#, person: String = #"{"name":"Ada"}"#, sections: String = "[]") -> String {
        #"{"schemaVersion":\#(version),"language":\#(language),"person":\#(person),"sections":\#(sections)}"#
    }

    /// A document with one section of `kind` holding `items`, each given as JSON.
    static func section(_ kind: String, items: [String]) -> String {
        document(sections: #"[{"kind":"\#(kind)","items":[\#(items.joined(separator: ","))]}]"#)
    }

    /// A document with one section of `kind` holding one item.
    static func section(_ kind: String, _ item: String) -> String { section(kind, items: [item]) }

    static func summary(_ text: String) -> String { document(sections: #"[{"kind":"summary","text":"\#(text)"}]"#) }

    /// A document whose person has the name `name`, given as JSON.
    static func named(_ name: String) -> String { document(person: #"{"name":\#(name)}"#) }

    /// An education entry whose period is `period`.
    static func education(period: String) -> String { section("education", #"{"degree":"d","school":"s","period":\#(period)}"#) }

    static func quoted(_ text: String) -> String { "\"" + text + "\"" }

    // MARK: The documents

    private static func valid(_ all: inout [DocumentCase]) {
        func add(_ name: String, _ json: String) { all.append(DocumentCase(name: name, json: json, agreement: .valid)) }
        add("the smallest document", document())
        add("a line feed in a text", summary(#"a\nb"#))
        add("a link of any scheme: the renderer decides which links to keep", section("profiles", #"{"platform":"Evil","url":"javascript:alert(1)"}"#))
        add("items on a summary, which reads text only", document(sections: #"[{"kind":"summary","text":"t","items":7}]"#))
        for kind in ["experience", "education", "skills", "languages", "certifications", "profiles", "interests"] {
            add("text on a \(kind) section, which reads items only", document(sections: #"[{"kind":"\#(kind)","items":[],"text":"ignored"}]"#))
        }
        add("an endDate that is ignored when the period is not over", education(period: #"{"start":{"year":2000},"end":"present","endDate":"never read"}"#))
        for end in ["present", "unspecified"] {
            add("a valid endDate that is ignored when the period ends as \(end)", education(period: #"{"start":{"year":2000},"end":"\#(end)","endDate":{"year":2001}}"#))
        }
        add("a period that ends in the month it starts", education(period: #"{"start":{"year":2000,"month":3},"end":"date","endDate":{"year":2000,"month":3}}"#))
    }

    private static func invalid(_ all: inout [DocumentCase]) {
        func add(_ name: String, _ json: String) { all.append(DocumentCase(name: name, json: json, agreement: .invalid)) }
        for kind in ["hobbies", "projects", ""] {
            add("an unknown section kind: \(kind.isEmpty ? "the empty text" : kind)", document(sections: #"[{"kind":"\#(kind)","items":[]}]"#))
        }
        add("a section kind in capitals", document(sections: #"[{"kind":"Summary","text":"t"}]"#))
        add("a summary that carries items instead of text", document(sections: #"[{"kind":"summary","items":[]}]"#))
        add("a section of items that carries text instead of items", document(sections: #"[{"kind":"skills","text":"t"}]"#))
        add("a period that ends in an unknown way", education(period: #"{"start":{"year":2000},"end":"future"}"#))
        add("a period end in capitals", education(period: #"{"start":{"year":2000},"end":"Present"}"#))
        add("a period that ends on a date, without the date", education(period: #"{"start":{"year":2000},"end":"date"}"#))
        add("level d1", section("languages", #"{"language":"l","level":"d1"}"#))
        add("level B2 in capitals", section("languages", #"{"language":"l","level":"B2"}"#))
    }

    private static func beyondSchema(_ all: inout [DocumentCase]) {
        func add(_ name: String, _ rule: Exporter.Rule, _ json: String) { all.append(DocumentCase(name: name, json: json, agreement: .beyondSchema(rule))) }
        add("a name of one space", .blankName, named(quoted(" ")))
        add("a name of one line feed", .blankName, named(quoted(#"\n"#)))
        add("a bell character in a text", .textRules, summary(#"a\u0007b"#))
        add("a tab in a text", .textRules, summary(#"a\tb"#))
        add("a delete character in a text", .textRules, summary(#"a\u007Fb"#))
        add("a next-line control in a text", .textRules, summary(#"a\u0085b"#))
        add("a right-to-left override in a text", .textRules, summary(#"\u202Eevil"#))
        add("a left-to-right embedding in a text", .textRules, summary(#"x\u202Ay"#))
        add("a left-to-right isolate in a text", .textRules, summary(#"a\u2066b"#))
        add("a period that ends in an earlier year", .periodOrder, education(period: #"{"start":{"year":2020},"end":"date","endDate":{"year":2019}}"#))
        add("a period that ends in an earlier month", .periodOrder, education(period: #"{"start":{"year":2020,"month":6},"end":"date","endDate":{"year":2020,"month":5}}"#))
        add("a text of 16,386 bytes in two-byte characters", .textRules, summary(String(repeating: "\u{00E9}", count: 8_193)))
        add("a letter with 10,000 combining marks", .textRules, summary("a" + String(repeating: "\u{0301}", count: 10_000)))
        add("30 texts of 10,000 characters, above the budget of the whole document", .textRules,
            section("interests", items: Array(repeating: quoted(String(repeating: "x", count: 10_000)), count: 30)))
        add("a document of more than 1 MiB", .documentSize, document() + String(repeating: " ", count: 1_048_577))
    }
}
