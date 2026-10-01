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

extension Dictionary where Key == String {
    /// The members in the order of their keys, so that messages and generated documents do not change between runs.
    var inKeyOrder: [(key: String, value: Value)] { sorted { $0.key < $1.key } }
}
