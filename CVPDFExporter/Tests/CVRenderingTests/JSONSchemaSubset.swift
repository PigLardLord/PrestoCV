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

/// The part of JSON Schema 2020-12 that `cv-document.schema.json` uses, and nothing more. A keyword it does not know is
/// reported, and so is a known keyword in a form the matcher does not enforce for every kind of value (see `rejection`),
/// never skipped, so the schema cannot start to say something the tests do not check.
struct JSONSchemaSubset {
    let root: JSONValue
    private let patterns: [String: NSRegularExpression]
    private static let annotations: Set<String> = ["$schema", "$id", "title", "description", "$defs", "$comment"]
    static let implementedKeywords: Set<String> = [
        "$ref", "type", "const", "enum", "minimum", "maximum", "minLength", "pattern", "maxItems", "minItems", "items",
        "properties", "required", "additionalProperties", "oneOf",
    ]
    private static let jsonTypes: Set<String> = ["object", "array", "string", "number", "integer", "boolean", "null"]

    struct Unsupported: Error, CustomStringConvertible { let description: String }

    /// The one place that says which argument forms the matcher enforces: nil when `argument` is accepted for
    /// `keyword`, else why it is not. Add a form here only together with its enforcement in the matcher below.
    private static func rejection(_ keyword: String, _ argument: JSONValue, root: JSONValue) -> String? {
        func isSchema(_ v: JSONValue) -> Bool { if case .object = v { return true } else { return v == .bool(true) || v == .bool(false) } }
        switch (keyword, argument) {
        case ("additionalProperties", .bool(false)): return nil
        case ("additionalProperties", _): return "only false is enforced"
        case ("type", .string(let name)): return jsonTypes.contains(name) ? nil : "\(name) is not a JSON type"
        case ("type", _): return "only a single type name is enforced"
        case ("const", _): return nil
        case ("enum", .array): return nil
        case ("enum", _): return "must be an array"
        case ("minimum", .integer), ("maximum", .integer): return nil
        case ("minimum", _), ("maximum", _): return "must be an integer"
        case ("minLength", .integer(let n)), ("maxItems", .integer(let n)), ("minItems", .integer(let n)): return n >= 0 ? nil : "must not be negative"
        case ("minLength", _), ("maxItems", _), ("minItems", _): return "must be a non-negative integer"
        case ("pattern", .string(let source)): return (try? NSRegularExpression(pattern: source)) != nil ? nil : "does not compile"
        case ("pattern", _): return "must be a string"
        case ("items", _): return isSchema(argument) ? nil : "must be a schema"
        case ("properties", .object(let props)): return props.values.allSatisfy(isSchema) ? nil : "every property must be a schema"
        case ("properties", _): return "must be an object"
        case ("required", .array(let names)): return names.count == argument.strings.count ? nil : "must be an array of strings"
        case ("required", _): return "must be an array of strings"
        case ("oneOf", .array(let branches)): return !branches.isEmpty && branches.allSatisfy(isSchema) ? nil : "must be a non-empty array of schemas"
        case ("oneOf", _): return "must be a non-empty array of schemas"
        case ("$ref", .string(let ref)):
            guard ref.hasPrefix("#/$defs/") else { return "only #/$defs/<name> is enforced" }
            return root["$defs"]?[String(ref.dropFirst("#/$defs/".count))] != nil ? nil : "does not resolve"
        case ("$ref", _): return "must be a string"
        default: return "no accepted form"
        }
    }

    /// Walks the whole schema (every definition, property, item and oneOf branch) before any document is matched, and
    /// fails on a keyword the checker does not implement or an argument form it does not enforce: a branch that
    /// matching never reaches cannot hide one. Patterns are compiled here.
    init(root: JSONValue) throws {
        self.root = root
        var found: [String] = []
        var compiled: [String: NSRegularExpression] = [:]
        Self.collectUnsupported(root, root: root, path: "#", into: &found, patterns: &compiled)
        if !found.isEmpty { throw Unsupported(description: "the schema uses what the checker does not enforce: " + found.joined(separator: ", ")) }
        patterns = compiled
    }

    private static func collectUnsupported(_ schema: JSONValue, root: JSONValue, path: String, into found: inout [String], patterns: inout [String: NSRegularExpression]) {
        guard case .object(let keywords) = schema else { return }
        for (keyword, argument) in keywords.sorted(by: { $0.key < $1.key }) {
            if annotations.contains(keyword) {
                if keyword == "$defs", case .object(let defs) = argument { for (name, sub) in defs.sorted(by: { $0.key < $1.key }) { collectUnsupported(sub, root: root, path: "\(path)/$defs/\(name)", into: &found, patterns: &patterns) } }
                continue
            }
            guard implementedKeywords.contains(keyword) else { found.append("\(path): \(keyword)"); continue }
            if let why = rejection(keyword, argument, root: root) { found.append("\(path)/\(keyword): \(why)"); continue }
            switch (keyword, argument) {
            case ("pattern", .string(let source)): patterns[source] = try? NSRegularExpression(pattern: source)
            case ("properties", .object(let props)): for (name, sub) in props.sorted(by: { $0.key < $1.key }) { collectUnsupported(sub, root: root, path: "\(path)/properties/\(name)", into: &found, patterns: &patterns) }
            case ("items", _): collectUnsupported(argument, root: root, path: "\(path)/items", into: &found, patterns: &patterns)
            case ("oneOf", .array(let branches)): for (i, sub) in branches.enumerated() { collectUnsupported(sub, root: root, path: "\(path)/oneOf/\(i)", into: &found, patterns: &patterns) }
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
        case "minLength": if case .string(let s) = value, let n = argument.integerValue { return s.unicodeScalars.count >= n ? [] : ["\(path): shorter than \(n)"] } else { return [] }
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
        let v: Double
        switch value {
        case .integer(let i): v = Double(i)
        case .number(let d): v = d
        default: return []
        }
        guard let limit = argument.integerValue else { return [] }
        let ok = keyword == "minimum" ? v >= Double(limit) : v <= Double(limit)
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
        guard case .string(let source) = argument, let regex = patterns[source] else { return ["\(path): bad pattern"] }
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
