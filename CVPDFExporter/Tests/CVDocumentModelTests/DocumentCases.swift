import Testing

/// A JSON document and what the schema and the exporter (`CVDocumentValidator.decode(json:)`) each say about it.
struct DocumentCase: Sendable, CustomTestStringConvertible {
    enum Agreement: Sendable {
        /// Both accept it.
        case valid
        /// Both refuse it.
        case invalid
        /// The schema accepts it and the exporter refuses it: a rule JSON Schema cannot express exactly, which the
        /// validator alone enforces.
        case beyondSchema
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

    static func sections(_ section: String, count: Int) -> String { "[" + Array(repeating: section, count: count).joined(separator: ",") + "]" }

    static func quoted(_ text: String) -> String { "\"" + text + "\"" }

    // MARK: The documents

    private static func valid(_ all: inout [DocumentCase]) {
        func add(_ name: String, _ json: String) { all.append(DocumentCase(name: name, json: json, agreement: .valid)) }
        add("the smallest document", document())
        add("a version written as 1.0", document(version: "1.0"))
        add("an empty language and empty texts", section("experience", #"{"role":"","company":""}"#))
        add("a line feed in a text", summary(#"a\nb"#))
        add("a link of any scheme: the renderer decides which links to keep", section("profiles", #"{"platform":"Evil","url":"javascript:alert(1)"}"#))

        add("a property nobody knows at the top level", #"{"schemaVersion":1,"language":"en","person":{"name":"Ada"},"sections":[],"extra":1}"#)
        add("a property nobody knows in the person", document(person: #"{"name":"Ada","extra":[]}"#))
        add("a property nobody knows in a section", document(sections: #"[{"kind":"summary","text":"t","extra":{}}]"#))
        add("items on a summary, which reads text only", document(sections: #"[{"kind":"summary","text":"t","items":7}]"#))
        add("a property nobody knows in an item", section("skills", #"{"name":"n","extra":true}"#))
        add("a property nobody knows in a date", education(period: #"{"start":{"year":2000,"extra":1},"end":"present"}"#))
        add("an endDate that is ignored when the period is not over", education(period: #"{"start":{"year":2000},"end":"present","endDate":"never read"}"#))

        add("optional person fields written as null", document(person: #"{"name":"Ada","professionalTitle":null,"email":null,"phone":null,"location":null,"website":null}"#))
        add("optional item fields written as null", section("experience", #"{"role":"r","company":"c","location":null,"period":null,"description":null}"#))
        add("a month and a rating written as null", section("skills", #"{"name":"n","rating":null}"#))
        add("a certification year written as null", section("certifications", #"{"name":"n","issuer":"i","year":null}"#))

        for end in ["present", "unspecified"] { add("a period that ends as \(end)", education(period: #"{"start":{"year":2000},"end":"\#(end)"}"#)) }
        add("a period that ends on a date", education(period: #"{"start":{"year":2000,"month":3},"end":"date","endDate":{"year":2001,"month":4}}"#))
        add("a period that ends in the month it starts", education(period: #"{"start":{"year":2000,"month":3},"end":"date","endDate":{"year":2000,"month":3}}"#))
        add("a year written as 2000.0", education(period: #"{"start":{"year":2000.0},"end":"present"}"#))
        for month in [1, 12] { add("month \(month)", education(period: #"{"start":{"year":2000,"month":\#(month)},"end":"present"}"#)) }
        for year in [1900, 2200] { add("year \(year)", education(period: #"{"start":{"year":\#(year)},"end":"present"}"#)) }
        for rating in [1, 5] { add("rating \(rating)", section("skills", #"{"name":"n","rating":\#(rating)}"#)) }
        for year in [1900, 2200] { add("certification year \(year)", section("certifications", #"{"name":"n","issuer":"i","year":\#(year)}"#)) }
        for level in ["a1", "a2", "b1", "b2", "c1", "c2", "native"] { add("level \(level)", section("languages", #"{"language":"l","level":"\#(level)"}"#)) }

        add("200 sections", document(sections: sections(#"{"kind":"summary","text":"t"}"#, count: 200)))
        add("200 interests", section("interests", items: Array(repeating: #""x""#, count: 200)))
        add("200 skills", section("skills", items: Array(repeating: #"{"name":"n"}"#, count: 200)))
        add("a text of 16,384 characters", summary(String(repeating: "a", count: 16_384)))
        add("a name of 16,384 characters", named(quoted(String(repeating: "a", count: 16_384))))
        add("a text of 16,384 bytes in two-byte characters", summary(String(repeating: "\u{00E9}", count: 8_192)))
    }

    private static func invalid(_ all: inout [DocumentCase]) {
        func add(_ name: String, _ json: String) { all.append(DocumentCase(name: name, json: json, agreement: .invalid)) }
        add("the root is not an object", "[]")
        add("schema version 2", document(version: "2"))
        add("schema version 0", document(version: "0"))
        add("schema version 1.5", document(version: "1.5"))
        add("a schema version written as text", document(version: quoted("1")))
        add("a missing schema version", #"{"language":"en","person":{"name":"Ada"},"sections":[]}"#)
        add("a missing language", #"{"schemaVersion":1,"person":{"name":"Ada"},"sections":[]}"#)
        add("a language that is a number", document(language: "5"))
        add("a missing person", #"{"schemaVersion":1,"language":"en","sections":[]}"#)
        add("a person that is not an object", document(person: quoted("Ada")))
        add("a missing name", document(person: #"{"email":"ada@example.com"}"#))
        add("an empty name", named(quoted("")))
        add("a name that is null", named("null"))
        add("a name that is a number", named("7"))
        add("missing sections", #"{"schemaVersion":1,"language":"en","person":{"name":"Ada"}}"#)
        add("sections that are an object", document(sections: "{}"))
        add("201 sections", document(sections: sections(#"{"kind":"summary","text":"t"}"#, count: 201)))

        add("an unknown section kind", document(sections: #"[{"kind":"hobbies","items":[]}]"#))
        add("a section kind in capitals", document(sections: #"[{"kind":"Summary","text":"t"}]"#))
        add("a section without a kind", document(sections: #"[{"items":[]}]"#))
        add("a section kind that is a number", document(sections: #"[{"kind":1,"items":[]}]"#))
        add("a summary without text", document(sections: #"[{"kind":"summary"}]"#))
        add("a summary whose text is a number", document(sections: #"[{"kind":"summary","text":5}]"#))
        add("a section without items", document(sections: #"[{"kind":"skills"}]"#))
        add("items that are an object", document(sections: #"[{"kind":"skills","items":{}}]"#))
        add("items that are null", document(sections: #"[{"kind":"skills","items":null}]"#))

        add("an experience without a company", section("experience", #"{"role":"r"}"#))
        add("an experience without a role", section("experience", #"{"company":"c"}"#))
        add("a role that is a number", section("experience", #"{"role":1,"company":"c"}"#))
        add("an education without a school", section("education", #"{"degree":"d"}"#))
        add("an education without a degree", section("education", #"{"school":"s"}"#))
        add("a skill without a name", section("skills", #"{"rating":3}"#))
        add("a language without a level", section("languages", #"{"language":"l"}"#))
        add("a language without a name", section("languages", #"{"level":"b1"}"#))
        add("a certification without an issuer", section("certifications", #"{"name":"n"}"#))
        add("a certification without a name", section("certifications", #"{"issuer":"i"}"#))
        add("a profile without a url", section("profiles", #"{"platform":"p"}"#))
        add("a profile without a platform", section("profiles", #"{"url":"u"}"#))
        add("an interest that is not text", section("interests", "5"))

        add("201 interests", section("interests", items: Array(repeating: #""x""#, count: 201)))
        add("201 skills", section("skills", items: Array(repeating: #"{"name":"n"}"#, count: 201)))
        add("201 experiences", section("experience", items: Array(repeating: #"{"role":"r","company":"c"}"#, count: 201)))

        add("a period that ends in an unknown way", education(period: #"{"start":{"year":2000},"end":"future"}"#))
        add("a period end in capitals", education(period: #"{"start":{"year":2000},"end":"Present"}"#))
        add("a period without an end", education(period: #"{"start":{"year":2000}}"#))
        add("a period end that is a number", education(period: #"{"start":{"year":2000},"end":1}"#))
        add("a period without a start", education(period: #"{"end":"present"}"#))
        add("a period that ends on a date, without the date", education(period: #"{"start":{"year":2000},"end":"date"}"#))
        add("a period that ends on a date, which is null", education(period: #"{"start":{"year":2000},"end":"date","endDate":null}"#))
        add("an end date in month 13", education(period: #"{"start":{"year":2000},"end":"date","endDate":{"year":2001,"month":13}}"#))
        add("an end date in 2201", education(period: #"{"start":{"year":2000},"end":"date","endDate":{"year":2201}}"#))

        add("month 13", education(period: #"{"start":{"year":2000,"month":13},"end":"present"}"#))
        add("month 0", education(period: #"{"start":{"year":2000,"month":0},"end":"present"}"#))
        add("month 1.5", education(period: #"{"start":{"year":2000,"month":1.5},"end":"present"}"#))
        add("a month written as text", education(period: #"{"start":{"year":2000,"month":"6"},"end":"present"}"#))
        add("year 1899", education(period: #"{"start":{"year":1899},"end":"present"}"#))
        add("year 2201", education(period: #"{"start":{"year":2201},"end":"present"}"#))
        add("a date without a year", education(period: #"{"start":{"month":6},"end":"present"}"#))
        add("a year written as text", education(period: #"{"start":{"year":"2000"},"end":"present"}"#))
        add("year 2000.5", education(period: #"{"start":{"year":2000.5},"end":"present"}"#))

        add("rating 6", section("skills", #"{"name":"n","rating":6}"#))
        add("rating 0", section("skills", #"{"name":"n","rating":0}"#))
        add("rating 3.5", section("skills", #"{"name":"n","rating":3.5}"#))
        add("a rating written as text", section("skills", #"{"name":"n","rating":"3"}"#))
        add("level d1", section("languages", #"{"language":"l","level":"d1"}"#))
        add("level B2 in capitals", section("languages", #"{"language":"l","level":"B2"}"#))
        add("a level that is a number", section("languages", #"{"language":"l","level":2}"#))
        add("a level that is null", section("languages", #"{"language":"l","level":null}"#))
        add("certification year 1899", section("certifications", #"{"name":"n","issuer":"i","year":1899}"#))
        add("certification year 2201", section("certifications", #"{"name":"n","issuer":"i","year":2201}"#))
        add("a certification year written as text", section("certifications", #"{"name":"n","issuer":"i","year":"2000"}"#))

        add("a text of 16,385 characters", summary(String(repeating: "a", count: 16_385)))
        add("a name of 16,385 characters", named(quoted(String(repeating: "a", count: 16_385))))
        add("an interest of 16,385 characters", section("interests", quoted(String(repeating: "a", count: 16_385))))
    }

    private static func beyondSchema(_ all: inout [DocumentCase]) {
        func add(_ name: String, _ json: String) { all.append(DocumentCase(name: name, json: json, agreement: .beyondSchema)) }
        add("a name of one space", named(quoted(" ")))
        add("a name of one line feed", named(quoted(#"\n"#)))
        add("a bell character in a text", summary(#"a\u0007b"#))
        add("a tab in a text", summary(#"a\tb"#))
        add("a delete character in a text", summary(#"a\u007Fb"#))
        add("a next-line control in a text", summary(#"a\u0085b"#))
        add("a right-to-left override in a text", summary(#"‮evil"#))
        add("a left-to-right embedding in a text", summary(#"x‪y"#))
        add("a left-to-right isolate in a text", summary(#"a⁦b"#))
        add("a period that ends in an earlier year", education(period: #"{"start":{"year":2020},"end":"date","endDate":{"year":2019}}"#))
        add("a period that ends in an earlier month", education(period: #"{"start":{"year":2020,"month":6},"end":"date","endDate":{"year":2020,"month":5}}"#))
        add("a text of 16,386 bytes in two-byte characters", summary(String(repeating: "\u{00E9}", count: 8_193)))
        add("a letter with 10,000 combining marks", summary("a" + String(repeating: "\u{0301}", count: 10_000)))
        add("30 texts of 10,000 characters, above the budget of the whole document",
            section("interests", items: Array(repeating: quoted(String(repeating: "x", count: 10_000)), count: 30)))
        add("a document of more than 1 MiB", document() + String(repeating: " ", count: 1_048_577))
    }
}
