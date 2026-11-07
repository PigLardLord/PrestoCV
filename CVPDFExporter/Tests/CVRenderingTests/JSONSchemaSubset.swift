import Foundation

/// A JSON value, decoded so that integers, numbers and booleans stay apart (a `JSONSerialization` number cannot be told
/// from a boolean the same way on every platform).
enum JSONValue: Decodable, Equatable {
    case null, bool(Bool), integer(Int), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    static func parse(_ data: Data) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: data) }

    subscript(key: String) -> JSONValue? { if case .object(let o) = self { return o[key] } else { return nil } }
    var keys: Set<String> { if case .object(let o) = self { return Set(o.keys) } else { return [] } }
    var strings: [String] { if case .array(let a) = self { return a.compactMap { if case .string(let s) = $0 { return s } else { return nil } } } else { return [] } }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a } else { return nil } }
    var integerValue: Int? { if case .integer(let i) = self { return i } else { return nil } }
}

/// The part of JSON Schema 2020-12 that `cv-document.schema.json` uses, and nothing more: a keyword it does not know is
/// reported, never skipped, so the schema cannot start to say something the tests do not check.
struct JSONSchemaSubset {
    let root: JSONValue
    private static let annotations: Set<String> = ["$schema", "$id", "title", "description", "$defs", "$comment"]
    private static let implemented: Set<String> = [
        "$ref", "type", "const", "enum", "minimum", "maximum", "minLength", "pattern", "maxItems", "minItems", "items",
        "properties", "required", "additionalProperties", "oneOf",
    ]

    struct Unsupported: Error, CustomStringConvertible { let description: String }

    /// Walks the whole schema (every definition, property, item and oneOf branch) before any document is matched, and
    /// fails on a keyword the checker does not implement: a branch that matching never reaches cannot hide one.
    init(root: JSONValue) throws {
        self.root = root
        var found: [String] = []
        Self.collectUnsupported(root, path: "#", into: &found)
        if !found.isEmpty { throw Unsupported(description: "the schema uses keywords the checker does not implement: " + found.joined(separator: ", ")) }
    }

    private static func collectUnsupported(_ schema: JSONValue, path: String, into found: inout [String]) {
        guard case .object(let keywords) = schema else { return }
        for (keyword, argument) in keywords.sorted(by: { $0.key < $1.key }) {
            if annotations.contains(keyword) {
                if keyword == "$defs", case .object(let defs) = argument { for (name, sub) in defs.sorted(by: { $0.key < $1.key }) { collectUnsupported(sub, path: "\(path)/$defs/\(name)", into: &found) } }
                continue
            }
            guard implemented.contains(keyword) else { found.append("\(path): \(keyword)"); continue }
            switch (keyword, argument) {
            case ("properties", .object(let props)): for (name, sub) in props.sorted(by: { $0.key < $1.key }) { collectUnsupported(sub, path: "\(path)/properties/\(name)", into: &found) }
            case ("items", _), ("additionalProperties", _): collectUnsupported(argument, path: "\(path)/\(keyword)", into: &found)
            case ("oneOf", .array(let branches)): for (i, sub) in branches.enumerated() { collectUnsupported(sub, path: "\(path)/oneOf/\(i)", into: &found) }
            default: break
            }
        }
    }

    /// The problems of `value` against the schema, each with the path where it was found; empty when it is valid.
    func problems(_ value: JSONValue) -> [String] { check(value, root, path: "$") }

    private func check(_ value: JSONValue, _ schema: JSONValue, path: String) -> [String] {
        if schema == .bool(true) { return [] }
        if schema == .bool(false) { return ["\(path): not allowed"] }
        guard case .object(let keywords) = schema else { return ["\(path): the schema is not an object"] }
        var found: [String] = []
        for (keyword, argument) in keywords.sorted(by: { $0.key < $1.key }) where !Self.annotations.contains(keyword) {
            found += apply(keyword, argument, to: value, path: path, siblings: keywords)
        }
        return found
    }

    private func apply(_ keyword: String, _ argument: JSONValue, to value: JSONValue, path: String, siblings: [String: JSONValue]) -> [String] {
        switch keyword {
        case "$ref": return reference(argument).map { check(value, $0, path: path) } ?? ["\(path): unresolved reference"]
        case "type": return matches(value, type: argument) ? [] : ["\(path): not of type \(argument)"]
        case "const": return value == argument ? [] : ["\(path): not the constant \(argument)"]
        case "enum": if case .array(let options) = argument { return options.contains(value) ? [] : ["\(path): not one of the allowed values"] } else { return ["\(path): bad enum"] }
        case "minimum", "maximum": return bound(keyword, argument, value, path: path)
        case "minLength": if case .string(let s) = value, let n = argument.integerValue { return s.count >= n ? [] : ["\(path): shorter than \(n)"] } else { return [] }
        case "pattern": return pattern(argument, value, path: path)
        case "maxItems", "minItems": return itemCount(keyword, argument, value, path: path)
        case "items": if case .array(let a) = value { return a.enumerated().flatMap { check($1, argument, path: "\(path)[\($0)]") } } else { return [] }
        case "properties": return properties(argument, of: value, path: path)
        case "required": return required(argument, of: value, path: path)
        case "additionalProperties": return additional(argument, of: value, path: path, declared: siblings["properties"]?.keys ?? [])
        case "oneOf": return oneOf(argument, value, path: path)
        default: return ["\(path): unsupported keyword \(keyword)"]
        }
    }

    private func reference(_ argument: JSONValue) -> JSONValue? {
        guard case .string(let ref) = argument, ref.hasPrefix("#/$defs/") else { return nil }
        return root["$defs"]?[String(ref.dropFirst("#/$defs/".count))]
    }

    private func matches(_ value: JSONValue, type: JSONValue) -> Bool {
        guard case .string(let name) = type else { return false }
        switch (name, value) {
        case ("object", .object), ("array", .array), ("string", .string), ("integer", .integer), ("boolean", .bool), ("null", .null): return true
        case ("number", .integer), ("number", .number): return true
        default: return false
        }
    }

    private func bound(_ keyword: String, _ argument: JSONValue, _ value: JSONValue, path: String) -> [String] {
        guard case .integer(let v) = value, let limit = argument.integerValue else { return [] }
        let ok = keyword == "minimum" ? v >= limit : v <= limit
        return ok ? [] : ["\(path): \(v) breaks \(keyword) \(limit)"]
    }

    private func itemCount(_ keyword: String, _ argument: JSONValue, _ value: JSONValue, path: String) -> [String] {
        guard case .array(let a) = value, let limit = argument.integerValue else { return [] }
        let ok = keyword == "maxItems" ? a.count <= limit : a.count >= limit
        return ok ? [] : ["\(path): \(a.count) items break \(keyword) \(limit)"]
    }

    /// `pattern` is a search, not a full match (ECMA-262 `RegExp.test`).
    private func pattern(_ argument: JSONValue, _ value: JSONValue, path: String) -> [String] {
        guard case .string(let s) = value else { return [] }
        guard case .string(let source) = argument, let regex = try? NSRegularExpression(pattern: source) else { return ["\(path): bad pattern"] }
        return regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil ? [] : ["\(path): does not match pattern \(source)"]
    }

    private func properties(_ argument: JSONValue, of value: JSONValue, path: String) -> [String] {
        guard case .object(let declared) = argument, case .object(let given) = value else { return [] }
        return declared.sorted(by: { $0.key < $1.key }).flatMap { name, schema in given[name].map { check($0, schema, path: "\(path).\(name)") } ?? [] }
    }

    private func required(_ argument: JSONValue, of value: JSONValue, path: String) -> [String] {
        guard case .object(let given) = value else { return [] }
        return argument.strings.filter { given[$0] == nil }.map { "\(path): \($0) is required" }
    }

    private func additional(_ argument: JSONValue, of value: JSONValue, path: String, declared: Set<String>) -> [String] {
        guard argument == .bool(false), case .object(let given) = value else { return [] }
        return given.keys.filter { !declared.contains($0) }.sorted().map { "\(path): \($0) is not declared" }
    }

    private func oneOf(_ argument: JSONValue, _ value: JSONValue, path: String) -> [String] {
        guard case .array(let options) = argument else { return ["\(path): bad oneOf"] }
        let valid = options.filter { check(value, $0, path: path).isEmpty }.count
        return valid == 1 ? [] : ["\(path): matches \(valid) of the \(options.count) alternatives, not one"]
    }
}
