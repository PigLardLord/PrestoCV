import Testing
import Foundation

@Suite("ADR 0002 · the schema validator checks what it supports and refuses the rest")
struct JSONSchemaValidatorTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String, schema: String, instance: String, valid: Bool
        var testDescription: String { name }
    }

    static let cases: [Case] = {
        var all: [Case] = []
        func add(_ name: String, _ schema: String, _ instance: String, valid: Bool) {
            all.append(Case(name: name, schema: schema, instance: instance, valid: valid))
        }
        add("a string is a string", #"{"type":"string"}"#, #""x""#, valid: true)
        add("a number is not a string", #"{"type":"string"}"#, "1", valid: false)
        add("an integer written as 1.0 is an integer", #"{"type":"integer"}"#, "1.0", valid: true)
        add("1.5 is not an integer", #"{"type":"integer"}"#, "1.5", valid: false)
        add("a boolean is not an integer", #"{"type":"integer"}"#, "true", valid: false)
        add("an integer is a number", #"{"type":"number"}"#, "3", valid: true)
        add("null is null", #"{"type":"null"}"#, "null", valid: true)
        add("a list of types accepts any of them", #"{"type":["string","null"]}"#, "null", valid: true)
        add("a list of types refuses the others", #"{"type":["string","null"]}"#, "[]", valid: false)
        add("an object is an object", #"{"type":"object"}"#, "{}", valid: true)
        add("an array is not an object", #"{"type":"object"}"#, "[]", valid: false)
        add("a boolean is a boolean", #"{"type":"boolean"}"#, "false", valid: true)
        add("an array is an array", #"{"type":"array"}"#, "[]", valid: true)
        add("required accepts a present member", #"{"required":["a"]}"#, #"{"a":null}"#, valid: true)
        add("required refuses an absent member", #"{"required":["a"]}"#, #"{"b":1}"#, valid: false)
        add("required says nothing about a string", #"{"required":["a"]}"#, #""a""#, valid: true)
        add("a property that is absent is fine", #"{"properties":{"a":{"type":"string"}}}"#, "{}", valid: true)
        add("a property is checked when present", #"{"properties":{"a":{"type":"string"}}}"#, #"{"a":1}"#, valid: false)
        add("an unlisted property is ignored", #"{"properties":{"a":{"type":"string"}}}"#, #"{"b":1}"#, valid: true)
        add("items checks every element", #"{"items":{"type":"integer"}}"#, "[1,2,3]", valid: true)
        add("items refuses one wrong element", #"{"items":{"type":"integer"}}"#, #"[1,"2",3]"#, valid: false)
        add("enum accepts a listed value", #"{"enum":["a","b"]}"#, #""b""#, valid: true)
        add("enum refuses an unlisted value", #"{"enum":["a","b"]}"#, #""c""#, valid: false)
        add("const accepts its value", #"{"const":1}"#, "1.0", valid: true)
        add("const refuses another value", #"{"const":1}"#, "2", valid: false)
        add("const does not take true for 1", #"{"const":1}"#, "true", valid: false)
        add("minimum is inclusive", #"{"minimum":1}"#, "1", valid: true)
        add("below the minimum is refused", #"{"minimum":1}"#, "0", valid: false)
        add("maximum is inclusive", #"{"maximum":5}"#, "5", valid: true)
        add("above the maximum is refused", #"{"maximum":5}"#, "6", valid: false)
        add("minimum does not apply to a string", #"{"minimum":1}"#, #""0""#, valid: true)
        add("maxItems is inclusive", #"{"maxItems":2}"#, "[1,2]", valid: true)
        add("more than maxItems is refused", #"{"maxItems":2}"#, "[1,2,3]", valid: false)
        add("minLength refuses the empty string", #"{"minLength":1}"#, #""""#, valid: false)
        add("minLength accepts one character", #"{"minLength":1}"#, #""a""#, valid: true)
        add("maxLength is inclusive", #"{"maxLength":2}"#, #""ab""#, valid: true)
        add("more than maxLength is refused", #"{"maxLength":2}"#, #""abc""#, valid: false)
        add("a character outside the BMP counts once", #"{"maxLength":1}"#, #""😀""#, valid: true)
        add("a letter and a combining mark count twice", #"{"maxLength":1}"#, #""é""#, valid: false)
        add("oneOf accepts exactly one match", #"{"oneOf":[{"type":"string"},{"type":"integer"}]}"#, "1", valid: true)
        add("oneOf refuses no match", #"{"oneOf":[{"type":"string"},{"type":"integer"}]}"#, "null", valid: false)
        add("oneOf refuses two matches", #"{"oneOf":[{"type":"integer"},{"type":"number"}]}"#, "1", valid: false)
        add("a reference applies the definition", ##"{"$defs":{"n":{"type":"integer"}},"properties":{"a":{"$ref":"#/$defs/n"}}}"##, #"{"a":"x"}"#, valid: false)
        add("a reference accepts what the definition accepts", ##"{"$defs":{"n":{"type":"integer"}},"properties":{"a":{"$ref":"#/$defs/n"}}}"##, #"{"a":7}"#, valid: true)
        add("a reference keeps its sibling keywords", ##"{"$defs":{"n":{"type":"integer"}},"$ref":"#/$defs/n","maximum":3}"##, "4", valid: false)
        add("annotations change nothing", #"{"$schema":"x","$id":"y","title":"t","description":"d","type":"string"}"#, #""x""#, valid: true)
        return all
    }()

    @Test("a keyword is checked as JSON Schema defines it", arguments: cases)
    func keyword(testCase: Case) throws {
        let validator = try SchemaValidator(schema: JSON(parsing: testCase.schema))
        let instance = try JSON(parsing: testCase.instance)
        #expect(validator.accepts(instance) == testCase.valid, "\(validator.violations(of: instance))")
    }

    @Test("a violation says where it is")
    func violationPath() throws {
        let validator = try SchemaValidator(schema: JSON(parsing: #"{"properties":{"a":{"items":{"maximum":1}}}}"#))
        #expect(validator.violations(of: try JSON(parsing: #"{"a":[1,2]}"#)) == ["$.a[1]: above 1.0"])
    }

    @Test("text keeps booleans, numbers and null apart")
    func parsing() throws {
        let value = try JSON(parsing: #"{"a":[1,true,null,"s",1.5],"b":{}}"#)
        #expect(value["a"] == .array([.number(1), .bool(true), .null, .string("s"), .number(1.5)]))
        #expect(value["b"] == .object([:]))
        #expect(value["c"] == nil)
    }

    @Test("a keyword it does not support is refused, wherever it is", arguments: [
        #"{"pattern":"x"}"#,
        #"{"additionalProperties":false}"#,
        #"{"anyOf":[{}]}"#,
        #"{"if":{}}"#,
        #"{"minItems":1}"#,
        ##"{"$dynamicRef":"#x"}"##,
        #"{"properties":{"a":{"format":"email"}}}"#,
        #"{"items":{"uniqueItems":true}}"#,
        #"{"oneOf":[{"type":"string"},{"allOf":[]}]}"#,
        #"{"$defs":{"unused":{"patternProperties":{}}}}"#,
    ])
    func unsupportedKeyword(schema: String) throws {
        #expect(throws: SchemaValidator.Unsupported.self) { _ = try SchemaValidator(schema: JSON(parsing: schema)) }
    }

    @Test("a reference outside #/$defs, or to a missing definition, is refused", arguments: [
        ##"{"$ref":"#/$defs/missing"}"##,
        #"{"$ref":"https://example.com/schema.json"}"#,
        ##"{"$defs":{"a":{}},"$ref":"#/properties/a"}"##,
    ])
    func unsupportedReference(schema: String) {
        #expect(throws: SchemaValidator.Unsupported.self) { _ = try SchemaValidator(schema: JSON(parsing: schema)) }
    }

    @Test("an unknown type name and a schema that is not an object are refused", arguments: [#"{"type":"float"}"#, #"{"properties":{"a":true}}"#])
    func malformedSchema(schema: String) {
        #expect(throws: SchemaValidator.Unsupported.self) { _ = try SchemaValidator(schema: JSON(parsing: schema)) }
    }

    struct DifferenceCase: Sendable, CustomTestStringConvertible {
        let name: String, schema: String, instance: String, expected: [String]
        var testDescription: String { name }
    }

    static let differenceCases: [DifferenceCase] = {
        var all: [DifferenceCase] = []
        func add(_ name: String, _ schema: String, _ instance: String, expected: [String]) {
            all.append(DifferenceCase(name: name, schema: schema, instance: instance, expected: expected))
        }
        let oneOf = #"{"oneOf":[{"properties":{"k":{"const":1},"a":{}}},{"properties":{"k":{"const":2},"b":{}}}]}"#
        add("a property nobody declares", #"{"properties":{"a":{}}}"#, #"{"a":1,"b":2}"#, expected: ["$.b is written but not declared"])
        add("a declared property the instance lacks", #"{"properties":{"a":{},"b":{}}}"#, #"{"a":1}"#, expected: ["$.b is declared but not written"])
        add("the same properties", #"{"properties":{"a":{}}}"#, #"{"a":1}"#, expected: [])
        add("a reference at the root", ##"{"$defs":{"d":{"properties":{"a":{}}}},"$ref":"#/$defs/d"}"##, #"{"a":1,"b":2}"#, expected: ["$.b is written but not declared"])
        add("the items of an array", #"{"properties":{"l":{"items":{"properties":{"a":{}}}}}}"#, #"{"l":[{"a":1},{"a":1,"b":2}]}"#, expected: ["$.l[1].b is written but not declared"])
        add("the items of an array, by reference", ##"{"$defs":{"e":{"properties":{"a":{}}}},"properties":{"l":{"items":{"$ref":"#/$defs/e"}}}}"##, #"{"l":[{"b":2}]}"#,
            expected: ["$.l[0].b is written but not declared", "$.l[0].a is declared but not written"])
        add("the alternative that accepts the instance", oneOf, #"{"k":2,"b":0}"#, expected: [])
        add("the properties of another alternative", oneOf, #"{"k":2,"a":0}"#, expected: ["$.a is written but not declared", "$.b is declared but not written"])
        return all
    }()

    @Test("a property the schema does not declare, or declares and the instance lacks, is reported", arguments: differenceCases)
    func propertyDifferences(testCase: DifferenceCase) throws {
        let validator = try SchemaValidator(schema: JSON(parsing: testCase.schema))
        #expect(validator.propertyDifferences(of: try JSON(parsing: testCase.instance)) == testCase.expected)
    }
}
