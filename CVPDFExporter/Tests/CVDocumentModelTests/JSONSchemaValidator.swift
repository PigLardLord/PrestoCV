import Foundation

/// A JSON value decoded from text, so that booleans, numbers and `null` stay what the text says on every platform.
enum JSON: Equatable, Decodable {
    case null, bool(Bool), number(Double), string(String), array([JSON]), object([String: JSON])

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode([JSON].self) { self = .array(value) }
        else { self = .object(try c.decode([String: JSON].self)) }
    }

    init(parsing data: Data) throws { self = try JSONDecoder().decode(JSON.self, from: data) }

    init(parsing text: String) throws { try self.init(parsing: Data(text.utf8)) }

    subscript(key: String) -> JSON? { if case .object(let members) = self { members[key] } else { nil } }
}

/// The part of JSON Schema (draft 2020-12) that `cvdocument.v1.schema.json` uses, and nothing more. A keyword it does not
/// know makes `init` throw, so the schema cannot rely on a check this validator does not perform.
struct SchemaValidator {
    struct Unsupported: Error, CustomStringConvertible {
        let description: String
    }

    private static let annotations: Set<String> = ["$schema", "$id", "title", "description"]
    private static let types: Set<String> = ["null", "boolean", "object", "array", "number", "integer", "string"]

    private let root: JSON

    init(schema: JSON) throws {
        root = schema
        try Self.audit(schema, at: "#", root: schema)
    }

    /// The reasons `instance` does not satisfy the schema; empty when it does.
    func violations(of instance: JSON) -> [String] { check(instance, against: root, at: "$") }

    func accepts(_ instance: JSON) -> Bool { violations(of: instance).isEmpty }

    /// The schema called `name` in `$defs`.
    func definition(_ name: String) -> JSON? { root["$defs"]?[name] }

    /// The schema a `{"$ref": …}` schema points to.
    func resolve(_ schema: JSON) -> JSON? {
        guard case .string(let reference)? = schema["$ref"] else { return nil }
        return Self.target(of: reference, in: root)
    }

    /// Where `instance` and the schema disagree about which properties exist: those the instance has and no schema declares
    /// (what `unevaluatedProperties: false` would refuse), and those a schema declares that the instance lacks. Run on a
    /// document with every optional field present, it shows that the schema describes exactly what the model writes.
    func propertyDifferences(of instance: JSON) -> [String] { differences(of: instance, against: root, at: "$") }

    // MARK: Auditing the schema

    private static func audit(_ schema: JSON, at path: String, root: JSON) throws {
        guard case .object(let keywords) = schema else { throw Unsupported(description: "\(path): a schema must be an object") }
        for (keyword, value) in keywords.sorted(by: { $0.key < $1.key }) where !annotations.contains(keyword) {
            let here = "\(path)/\(keyword)"
            switch (keyword, value) {
            case ("$defs", .object(let schemas)), ("properties", .object(let schemas)):
                for (name, subschema) in schemas.sorted(by: { $0.key < $1.key }) { try audit(subschema, at: "\(here)/\(name)", root: root) }
            case ("items", _):
                try audit(value, at: here, root: root)
            case ("oneOf", .array(let branches)):
                for (index, branch) in branches.enumerated() { try audit(branch, at: "\(here)/\(index)", root: root) }
            case ("$ref", .string(let reference)):
                guard target(of: reference, in: root) != nil else { throw Unsupported(description: "\(here): \(reference) does not name a schema in #/$defs") }
            case ("type", _):
                if let unknown = typeNames(value).first(where: { !types.contains($0) }) { throw Unsupported(description: "\(here): unknown type \(unknown)") }
            case ("required", _), ("enum", _), ("const", _), ("minimum", _), ("maximum", _), ("maxItems", _), ("minLength", _), ("maxLength", _):
                continue
            default:
                throw Unsupported(description: "\(here): the keyword \(keyword) is not supported")
            }
        }
    }

    private static func target(of reference: String, in root: JSON) -> JSON? {
        let prefix = "#/$defs/"
        guard reference.hasPrefix(prefix) else { return nil }
        return root["$defs"]?[String(reference.dropFirst(prefix.count))]
    }

    private static func typeNames(_ value: JSON) -> [String] {
        switch value {
        case .string(let name): [name]
        case .array(let names): names.compactMap { if case .string(let name) = $0 { name } else { nil } }
        default: []
        }
    }

    // MARK: Checking an instance

    private func check(_ instance: JSON, against schema: JSON, at path: String) -> [String] {
        guard case .object(let keywords) = schema else { return [] }
        var found: [String] = []
        for (keyword, value) in keywords.sorted(by: { $0.key < $1.key }) {
            switch (keyword, value) {
            case ("$ref", .string(let reference)):
                if let target = Self.target(of: reference, in: root) { found += check(instance, against: target, at: path) }
            case ("type", _):
                let names = Self.typeNames(value)
                if !names.contains(where: { Self.matches(instance, type: $0) }) { found.append("\(path): expected \(names.joined(separator: " or "))") }
            case ("required", .array(let names)):
                if case .object(let members) = instance {
                    for case .string(let name) in names where members[name] == nil { found.append("\(path): \(name) is required") }
                }
            case ("properties", .object(let schemas)):
                for (name, subschema) in schemas.sorted(by: { $0.key < $1.key }) {
                    if let member = instance[name] { found += check(member, against: subschema, at: "\(path).\(name)") }
                }
            case ("items", _):
                if case .array(let elements) = instance {
                    for (index, element) in elements.enumerated() { found += check(element, against: value, at: "\(path)[\(index)]") }
                }
            case ("enum", .array(let options)):
                if !options.contains(instance) { found.append("\(path): not one of the allowed values") }
            case ("const", _):
                if instance != value { found.append("\(path): not the required value") }
            case ("minimum", .number(let limit)):
                if case .number(let number) = instance, number < limit { found.append("\(path): below \(limit)") }
            case ("maximum", .number(let limit)):
                if case .number(let number) = instance, number > limit { found.append("\(path): above \(limit)") }
            case ("maxItems", .number(let limit)):
                if case .array(let elements) = instance, Double(elements.count) > limit { found.append("\(path): more than \(limit) items") }
            case ("minLength", .number(let limit)):
                if case .string(let text) = instance, Double(text.unicodeScalars.count) < limit { found.append("\(path): shorter than \(limit) characters") }
            case ("maxLength", .number(let limit)):
                if case .string(let text) = instance, Double(text.unicodeScalars.count) > limit { found.append("\(path): longer than \(limit) characters") }
            case ("oneOf", .array(let branches)):
                let matching = branches.filter { check(instance, against: $0, at: path).isEmpty }.count
                if matching != 1 { found.append("\(path): matches \(matching) of the \(branches.count) alternatives, not exactly one") }
            default:
                continue
            }
        }
        return found
    }

    private static func matches(_ instance: JSON, type: String) -> Bool {
        switch (type, instance) {
        case ("null", .null), ("boolean", .bool), ("object", .object), ("array", .array), ("string", .string), ("number", .number): true
        case ("integer", .number(let number)): number.isFinite && number == number.rounded()
        default: false
        }
    }

    // MARK: Comparing the properties

    private func differences(of instance: JSON, against schema: JSON, at path: String) -> [String] {
        var found: [String] = []
        switch instance {
        case .object(let members):
            let declared = declaredProperties(in: schema, for: instance)
            for name in members.keys.sorted() where declared[name] == nil { found.append("\(path).\(name) is written but not declared") }
            for name in declared.keys.sorted() where members[name] == nil { found.append("\(path).\(name) is declared but not written") }
            for (name, member) in members.sorted(by: { $0.key < $1.key }) {
                for subschema in declared[name] ?? [] { found += differences(of: member, against: subschema, at: "\(path).\(name)") }
            }
        case .array(let elements):
            for items in itemSchemas(in: schema) {
                for (index, element) in elements.enumerated() { found += differences(of: element, against: items, at: "\(path)[\(index)]") }
            }
        default:
            break
        }
        return found
    }

    /// The subschemas of each property that `schema`, its reference and the alternatives that accept `instance` declare.
    private func declaredProperties(in schema: JSON, for instance: JSON) -> [String: [JSON]] {
        var declared: [String: [JSON]] = [:]
        func merge(_ more: [String: [JSON]]) { declared.merge(more) { $0 + $1 } }
        if let target = resolve(schema) { merge(declaredProperties(in: target, for: instance)) }
        if case .object(let properties)? = schema["properties"] { merge(properties.mapValues { [$0] }) }
        if case .array(let branches)? = schema["oneOf"] {
            for branch in branches where check(instance, against: branch, at: "$").isEmpty { merge(declaredProperties(in: branch, for: instance)) }
        }
        return declared
    }

    private func itemSchemas(in schema: JSON) -> [JSON] {
        (resolve(schema).map(itemSchemas) ?? []) + (schema["items"].map { [$0] } ?? [])
    }
}

extension Dictionary where Key == String {
    /// The members in the order of their keys, so that messages and generated documents do not change between runs.
    var inKeyOrder: [(key: String, value: Value)] { sorted { $0.key < $1.key } }
}
