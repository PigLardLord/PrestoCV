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

    /// A minimal schema using the form, an instance that satisfies it, one that violates it, and the path of the violation.
    /// No `default`: a new `AcceptedForm` case does not compile until it has its row.
    static func row(_ form: JSONSchemaSubset.AcceptedForm) -> (schema: String, valid: String, invalid: String, path: String) {
        switch form {
        case .typeObject: return (#"{"type":"object"}"#, "{}", "1", "$")
        case .typeArray: return (#"{"type":"array"}"#, "[]", "1", "$")
        case .typeString: return (#"{"type":"string"}"#, #""a""#, "1", "$")
        case .typeNumber: return (#"{"type":"number"}"#, "1.5", #""a""#, "$")
        case .typeInteger: return (#"{"type":"integer"}"#, "1", "1.5", "$")
        case .typeBoolean: return (#"{"type":"boolean"}"#, "true", "1", "$")
        case .typeNull: return (#"{"type":"null"}"#, "null", "1", "$")
        case .const: return (#"{"const":"a"}"#, #""a""#, #""b""#, "$")
        case .enumeration: return (#"{"enum":["a","b"]}"#, #""a""#, #""c""#, "$")
        case .minimum: return (#"{"minimum":2}"#, "2", "1", "$")
        case .maximum: return (#"{"maximum":2}"#, "2", "3", "$")
        case .minLength: return (#"{"minLength":2}"#, #""ab""#, #""a""#, "$")
        case .pattern: return (#"{"pattern":"^a$"}"#, #""a""#, #""b""#, "$")
        case .maxItems: return (#"{"maxItems":1}"#, "[1]", "[1,2]", "$")
        case .minItems: return (#"{"minItems":2}"#, "[1,2]", "[1]", "$")
        case .items: return (#"{"items":{"type":"string"}}"#, #"["a"]"#, #"["a",1]"#, "$[1]")
        case .properties: return (#"{"properties":{"a":{"type":"string"}}}"#, #"{"a":"x"}"#, #"{"a":1}"#, "$.a")
        case .propertyForbidden: return (#"{"properties":{"a":false}}"#, "{}", #"{"a":1}"#, "$.a")
        case .required: return (#"{"required":["a"]}"#, #"{"a":1}"#, "{}", "$")
        case .noAdditionalProperties: return (#"{"properties":{"a":{}},"additionalProperties":false}"#, #"{"a":1}"#, #"{"b":1}"#, "$")
        case .oneOf: return (#"{"oneOf":[{"type":"string"},{"type":"integer"}]}"#, "1", "true", "$")
        case .localReference: return (##"{"$defs":{"s":{"type":"string"}},"$ref":"#/$defs/s"}"##, #""a""#, "1", "$")
        }
    }

    @Test("every accepted form is classified as itself and enforced against a violating instance", arguments: JSONSchemaSubset.AcceptedForm.allCases)
    func formIsEnforced(form: JSONSchemaSubset.AcceptedForm) throws {
        let row = Self.row(form)
        let root = try JSONValue.parse(Data(row.schema.utf8))
        let argument = try #require(root[form.keyword])
        #expect(JSONSchemaSubset.form(of: form.keyword, argument: argument, root: root) == .success(form))
        let s = try JSONSchemaSubset(root: root)
        #expect(s.problems(try JSONValue.parse(Data(row.valid.utf8))).isEmpty, "\(form) rejects its valid instance")
        let problems = s.problems(try JSONValue.parse(Data(row.invalid.utf8)))
        #expect(problems.contains { $0.hasPrefix(row.path) }, "\(form) is accepted but not enforced at \(row.path): \(problems)")
    }

    @Test("a keyword whose argument form the matcher does not enforce is refused at init", arguments: [
        #"{"additionalProperties":{"type":"string"}}"#,
        #"{"additionalProperties":true}"#,
        #"{"additionalProperties":{}}"#,
        #"{"items":true}"#,
        #"{"items":false}"#,
        #"{"properties":{"a":true}}"#,
        #"{"oneOf":[true]}"#,
        #"{"oneOf":[{"type":"string"},false]}"#,
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
