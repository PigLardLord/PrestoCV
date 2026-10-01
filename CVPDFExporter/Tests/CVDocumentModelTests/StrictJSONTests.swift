import Testing
import Foundation

@Suite("ADR 0002 · the committed schema is read as strict JSON")
struct StrictJSONTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String, text: String
        /// What the message must name, or nil when the text is strict JSON.
        let problem: String?
        var testDescription: String { name }
    }

    static let cases: [Case] = {
        var all: [Case] = []
        func accepted(_ name: String, _ text: String) { all.append(Case(name: name, text: text, problem: nil)) }
        func refused(_ name: String, _ text: String, naming problem: String) { all.append(Case(name: name, text: text, problem: problem)) }

        accepted("an empty object", "{}")
        accepted("every kind of value", #" { "a" : [ 1, -0, 0.5, 1e5, 2E-3, -1.5e+2, true, false, null, "s", {}, [] ] } "#)
        accepted("the same key in two objects", #"{"a":{"a":1},"b":{"a":2},"c":[{"a":1},{"a":2}]}"#)
        accepted("every escape", #"{"a":"\" \\ \/ \b \f \n \r \t \u0041 \u00e9 \ud83d\ude00"}"#)
        accepted("a duplicated value is not a duplicated key", #"{"a":1,"b":1}"#)
        accepted("non-ASCII text", "{\"a\":\"\u{00E9}\u{1F600}\"}")
        accepted("non-ASCII text with several emoji", #"{"a":"é😀😀"}"#)

        refused("a byte order mark", "\u{FEFF}{}", naming: "byte order mark")
        refused("a trailing comma in an object", #"{"a":1,}"#, naming: "trailing comma")
        refused("a trailing comma in an array", #"{"a":[1,2,]}"#, naming: "trailing comma")
        refused("a trailing comma after whitespace", "{\"a\":1 ,\n}", naming: "trailing comma")
        refused("a duplicate key", #"{"a":1,"a":2}"#, naming: "duplicate key \"a\"")
        refused("a duplicate key in a nested object", #"{"o":{"maxLength":16384,"maxLength":10}}"#, naming: "duplicate key \"maxLength\"")
        refused("a duplicate key spelled with an escape", #"{"a":1,"\u0061":2}"#, naming: "duplicate key")
        refused("a duplicate key with an accent", #"{"é":1,"é":2}"#, naming: "duplicate key")
        refused("a duplicate key with an emoji", #"{"😀":1,"😀":2}"#, naming: "duplicate key")
        refused("a duplicate key, once escaped and once not, with an accent", #"{"\u00e9":1,"é":2}"#, naming: "duplicate key")
        refused("a duplicate key, once a surrogate pair and once not", #"{"\ud83d\ude00":1,"😀":2}"#, naming: "duplicate key")
        refused("a duplicate key that is equal only under canonical equivalence", #"{"\u00e9":1,"e\u0301":2}"#, naming: "canonical equivalence")
        refused("a duplicate key in an object inside an array", #"{"l":[{"a":1,"a":1}]}"#, naming: "duplicate key")
        refused("a leading comma", #"{,"a":1}"#, naming: "key")
        refused("a missing comma", #"{"a":1 "b":2}"#, naming: "comma")
        refused("a missing colon", #"{"a" 1}"#, naming: "colon")
        refused("a key that is not text", "{1:2}", naming: "key")
        refused("a single-quoted string", "{'a':1}", naming: "key")
        refused("an unquoted word", "{\"a\":nope}", naming: "expected")
        refused("a comment", "{\"a\":1}// no", naming: "content after the value")
        refused("two values", "{} {}", naming: "content after the value")
        refused("no value", "  ", naming: "missing")
        refused("a number with a leading zero", #"{"a":01}"#, naming: "comma")
        refused("a number with a plus sign", #"{"a":+1}"#, naming: "unexpected")
        refused("a number that starts with a point", #"{"a":.5}"#, naming: "unexpected")
        refused("a number that ends with a point", #"{"a":1.}"#, naming: "digits after the point")
        refused("an exponent without digits", #"{"a":1e}"#, naming: "exponent")
        refused("an unknown escape", #"{"a":"\x"}"#, naming: "unknown escape")
        refused("a short unicode escape", #"{"a":"\u12"}"#, naming: "hexadecimal")
        refused("a lone high surrogate", #"{"a":"\ud83d"}"#, naming: "lone surrogate")
        refused("a lone low surrogate", #"{"a":"\ude00"}"#, naming: "lone surrogate")
        refused("a raw line feed inside a string", "{\"a\":\"x\ny\"}", naming: "control character")
        refused("a string that is not closed", #"{"a":"x"#, naming: "not closed")
        refused("an object that is not closed", #"{"a":1"#, naming: "comma")
        refused("a minus sign alone", "[-]", naming: "digits")
        refused("a word cut short", "[tru]", naming: "expected true")
        refused("a raw unit separator inside a string", "[\"a\u{1F}b\"]", naming: "control character")
        refused("a raw NUL inside a string", "[\"a\u{0}b\"]", naming: "control character")
        return all
    }()

    @Test("the scanner accepts strict JSON and names the first defect of anything else", arguments: cases)
    func scan(testCase: Case) {
        do {
            try StrictJSON.check(Data(testCase.text.utf8))
            #expect(testCase.problem == nil, "accepted, but it should name: \(testCase.problem ?? "")")
        } catch let error as StrictJSON.Problem {
            #expect(testCase.problem.map { error.description.contains($0) } == true, "\(error)")
        } catch {
            Issue.record("\(error)")
        }
    }

    @Test("nesting is limited to 512 levels, of arrays and of objects")
    func nesting() {
        let limit = 512
        func arrays(_ levels: Int) -> Data { Data((String(repeating: "[", count: levels) + String(repeating: "]", count: levels)).utf8) }
        func objects(_ levels: Int) -> Data { Data((String(repeating: #"{"a":"#, count: levels) + "1" + String(repeating: "}", count: levels)).utf8) }
        #expect(throws: Never.self) { try StrictJSON.check(arrays(limit)) }
        #expect(throws: Never.self) { try StrictJSON.check(objects(limit)) }
        for tooDeep in [arrays(limit + 1), objects(limit + 1)] {
            do {
                try StrictJSON.check(tooDeep)
                Issue.record("accepted nesting deeper than 512 levels")
            } catch {
                #expect("\(error)".contains("nesting deeper than 512 levels"), "\(error)")
            }
        }
    }

    @Test("a hundred thousand levels are refused at the limit, without recursing that deep", arguments: ["[", #"{"a":"#])
    func deepInput(opening: String) {
        do {
            try StrictJSON.check(Data(String(repeating: opening, count: 100_000).utf8))
            Issue.record("accepted nesting deeper than 512 levels")
        } catch {
            #expect("\(error)".contains("nesting deeper than 512 levels"), "\(error)")
        }
    }

    @Test("bytes that are not UTF-8 are refused")
    func invalidUTF8() {
        for bytes: [UInt8] in [[0x22, 0xFF, 0x22], [0x7B, 0x22, 0xC3, 0x22, 0x3A, 0x31, 0x7D], [0x22, 0xED, 0xA0, 0x80, 0x22]] {
            #expect(throws: StrictJSON.Problem.self) { try StrictJSON.check(Data(bytes)) }
        }
    }

    @Test("the committed schema is strict JSON")
    func committedSchema() throws {
        try StrictJSON.check(Data(contentsOf: CommittedSchema.url))
    }
}
