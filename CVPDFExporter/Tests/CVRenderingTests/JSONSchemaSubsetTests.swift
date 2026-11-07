import Testing
import Foundation
@testable import CVDocumentModel

@Suite("the schema subset checker refuses what it does not implement (#82)")
struct JSONSchemaSubsetTests {
    func schema(_ json: String) throws -> JSONSchemaSubset { try JSONSchemaSubset(root: JSONValue.parse(Data(json.utf8))) }

    @Test("an unsupported keyword hidden in an overlapping oneOf branch is a checker error, not a silent pass")
    func unsupportedKeywordInOneOf() throws {
        // A real validator rejects "Ada" (both branches match); a checker that drops the unknown branch would accept it.
        #expect(throws: (any Error).self) {
            _ = try schema(#"{"oneOf":[{"type":"string"},{"type":"string","multipleOf":2}]}"#)
        }
    }

    @Test("an unsupported keyword is found anywhere in the schema", arguments: [
        #"{"type":"string","format":"email"}"#,
        #"{"$defs":{"a":{"type":"integer","multipleOf":2}},"type":"string"}"#,
        #"{"properties":{"a":{"items":{"format":"date"}}}}"#,
        #"{"oneOf":[{"type":"string"},{"properties":{"a":{"format":"uri"}}}]}"#,
        ##"{"$defs":{"a":{"oneOf":[{"multipleOf":3}]}},"$ref":"#/$defs/a"}"##,
    ])
    func unsupportedEverywhere(json: String) throws {
        #expect(throws: (any Error).self) { _ = try schema(json) }
    }

    @Test("the keywords the checker implements are accepted, and pattern is matched anywhere in the string")
    func supportedKeywords() throws {
        let s = try schema(#"{"type":"string","pattern":"[^ ]"}"#)
        #expect(s.problems(.string("a b")).isEmpty)
        #expect(!s.problems(.string("   ")).isEmpty)
    }

    /// One row per implemented keyword: a schema that uses it and an instance that breaks it. A keyword the walker
    /// accepts and the matcher ignores makes its row go red.
    static let violations: [(keyword: String, schema: String, instance: String)] = [
        ("$ref", ##"{"$defs":{"s":{"type":"string"}},"$ref":"#/$defs/s"}"##, "1"),
        ("type", #"{"type":"string"}"#, "1"),
        ("const", #"{"const":"a"}"#, #""b""#),
        ("enum", #"{"enum":["a","b"]}"#, #""c""#),
        ("minimum", #"{"minimum":2}"#, "1"),
        ("maximum", #"{"maximum":2}"#, "3"),
        ("minLength", #"{"minLength":2}"#, #""a""#),
        ("pattern", #"{"pattern":"^a$"}"#, #""b""#),
        ("maxItems", #"{"maxItems":1}"#, "[1,2]"),
        ("minItems", #"{"minItems":2}"#, "[1]"),
        ("items", #"{"items":{"type":"string"}}"#, "[1]"),
        ("properties", #"{"properties":{"a":{"type":"string"}}}"#, #"{"a":1}"#),
        ("required", #"{"required":["a"]}"#, "{}"),
        ("additionalProperties", #"{"properties":{"a":{}},"additionalProperties":false}"#, #"{"b":1}"#),
        ("oneOf", #"{"oneOf":[{"type":"string"},{"type":"integer"}]}"#, "true"),
    ]

    @Test("every implemented keyword reports a violation", arguments: violations)
    func keywordIsEnforced(row: (keyword: String, schema: String, instance: String)) throws {
        let s = try schema(row.schema)
        let problems = s.problems(try JSONValue.parse(Data(row.instance.utf8)))
        #expect(!problems.isEmpty, "\(row.keyword) is accepted but not enforced")
    }

    @Test("the table covers every implemented keyword")
    func tableCoversEveryKeyword() {
        #expect(Set(Self.violations.map(\.keyword)) == JSONSchemaSubset.implementedKeywords)
    }

    @Test("a keyword whose argument form the matcher does not enforce is refused at init", arguments: [
        #"{"additionalProperties":{"type":"string"}}"#,
        #"{"additionalProperties":true}"#,
        #"{"type":["string","null"]}"#,
        #"{"type":"text"}"#,
        #"{"minimum":1.5}"#,
        #"{"maximum":"3"}"#,
        #"{"minLength":"1"}"#,
        #"{"minLength":-1}"#,
        #"{"pattern":"("}"#,
        #"{"pattern":1}"#,
        #"{"maxItems":-1}"#,
        #"{"minItems":1.5}"#,
        #"{"items":[{"type":"string"}]}"#,
        #"{"items":3}"#,
        #"{"properties":[]}"#,
        #"{"properties":{"a":3}}"#,
        #"{"required":"a"}"#,
        #"{"required":[1]}"#,
        #"{"enum":"a"}"#,
        #"{"oneOf":[]}"#,
        #"{"oneOf":{"type":"string"}}"#,
        ##"{"$ref":"#/$defs/missing"}"##,
        ##"{"$ref":"#/properties/a"}"##,
        ##"{"$ref":3}"##,
    ])
    func rejectedForms(json: String) {
        #expect(throws: (any Error).self) { _ = try schema(json) }
    }

    @Test("a double below an integer minimum is reported")
    func doubleBelowMinimum() throws {
        let s = try schema(#"{"minimum":2}"#)
        #expect(!s.problems(.number(1.5)).isEmpty)
        #expect(s.problems(.number(2.5)).isEmpty)
        let m = try schema(#"{"maximum":2}"#)
        #expect(!m.problems(.number(2.5)).isEmpty)
    }

    @Test("minLength counts code points, not grapheme clusters")
    func minLengthCountsScalars() throws {
        let s = try schema(#"{"minLength":2}"#)
        #expect(s.problems(.string("e\u{301}")).isEmpty) // 2 code points, 1 character
        #expect(!s.problems(.string("\u{301}")).isEmpty)
        let t = try schema(#"{"minLength":3}"#)
        #expect(!t.problems(.string("e\u{301}")).isEmpty)
    }
}
