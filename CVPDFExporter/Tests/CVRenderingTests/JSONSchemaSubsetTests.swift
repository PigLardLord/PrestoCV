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
}
