import Testing
import Foundation
@testable import TailoringModel

/// The JSON decoder of Foundation reads a key written twice in one object without a word, so the format cannot refuse it.
/// This scans the text instead: every bundled file is held to having no repeated key at any depth.
enum DuplicateKeys {
    private enum Frame {
        case object(keys: Set<String>, expectingKey: Bool)
        case array
    }

    /// The keys written twice in one object, wherever the object is.
    static func find(in data: Data) -> [String] {
        let bytes = Array(data)
        var stack: [Frame] = []
        var found: [String] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "{"):
                stack.append(.object(keys: [], expectingKey: true))
            case UInt8(ascii: "["):
                stack.append(.array)
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                if !stack.isEmpty { stack.removeLast() }
            case UInt8(ascii: ","):
                if case .object(let keys, _)? = stack.last { stack[stack.count - 1] = .object(keys: keys, expectingKey: true) }
            case UInt8(ascii: "\""):
                var end = index + 1
                while end < bytes.count, bytes[end] != UInt8(ascii: "\"") { end += bytes[end] == UInt8(ascii: "\\") ? 2 : 1 }
                let quoted = Data(bytes[index...min(end, bytes.count - 1)])
                if case .object(var keys, true)? = stack.last {
                    let key = text(of: quoted)
                    if !keys.insert(key).inserted { found.append(key) }
                    stack[stack.count - 1] = .object(keys: keys, expectingKey: false)
                }
                index = end
            default:
                break
            }
            index += 1
        }
        return found
    }

    private static func text(of quoted: Data) -> String {
        do {
            return try JSONDecoder().decode(String.self, from: quoted)
        } catch {
            return String(decoding: quoted, as: UTF8.self)
        }
    }
}

@Suite("ADR 0013 / R8 · no key is written twice in a word-list file (#136)")
struct DuplicateKeysTests {
    private func find(_ json: String) -> [String] { DuplicateKeys.find(in: Data(json.utf8)) }

    @Test("a key written twice in one object is found, at the top and deeper")
    func found() {
        #expect(find(#"{"a":1,"a":2}"#) == ["a"])
        #expect(find(#"{"x":{"a":1,"b":2,"a":3}}"#) == ["a"])
        #expect(find(#"{"list":[{"a":1,"a":2}]}"#) == ["a"])
        #expect(find(#"{"a":1,"b":{"c":1,"c":2},"b":3}"#) == ["c", "b"])
    }

    @Test("a key written in two objects, or in an object and its parent, is not a repeat")
    func notFound() {
        #expect(find(#"{"a":{"a":1},"b":{"a":2}}"#).isEmpty)
        #expect(find(#"[{"a":1},{"a":1}]"#).isEmpty)
        #expect(find(#"{"a":[{"a":1},{"a":2}]}"#).isEmpty)
        #expect(find("").isEmpty && find("{}").isEmpty && find("[]").isEmpty)
    }

    @Test("a string value that looks like a key, with escapes and brackets in it, is not read as one")
    func valuesAreNotKeys() {
        #expect(find(#"{"a":"x\",\"a\":1","b":"{\"b\":1,\"b\":2}"}"#).isEmpty)
        #expect(find(#"{"a":"]}","b":"[{"}"#).isEmpty)
    }

    @Test("a key written with an escape is the same key")
    func escapedKeys() {
        #expect(find(#"{"a":1,"\u0061":2}"#) == ["a"])
    }

    @Test("no bundled file writes a key twice")
    func bundledFiles() throws {
        let index = try #require(WordListResources.url(named: "index"))
        let directory = index.deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".json") }
        #expect(files.contains("index.json") && files.contains("en.json"))
        for file in files {
            let data = try Data(contentsOf: directory.appendingPathComponent(file))
            #expect(DuplicateKeys.find(in: data).isEmpty, "\(file) writes a key twice")
        }
    }
}
