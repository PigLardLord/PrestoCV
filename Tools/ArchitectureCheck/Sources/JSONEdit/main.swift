// Edits a JSON file in place. The checker's self-test changes its fixtures' rules.json with it, so the self-test needs
// nothing beyond the Swift toolchain (#438).
//
//   JSONEdit <file> set <path> <json>                     puts the value at the path, in place of what is there
//   JSONEdit <file> append <path> <json>                  adds the value at the end of the array at the path
//   JSONEdit <file> extend <path> <json array>            adds the array's values at the end of the array at the path
//   JSONEdit <file> insert <path> <index> <json array>    puts the array's values into the array at the path, from the index
//   JSONEdit <file> remove <path>                         takes the value at the path away
//   JSONEdit <file> keep <path> <key>=<text>              keeps the objects of the array at the path whose `key` is the text
//   JSONEdit <file> copy <source file> <source path> <path>   puts the value at the source's path at the path
//
// A path is dot-separated, and the empty path is the whole document. In an array a segment is an index, or `key=text`
// for the first object whose string `key` is the text; in an object it is a key, which `set` adds when it is missing.
// A path that leads nowhere is an error: the file is left as it was, and the tool exits with 1.
import Foundation

enum JSONValue: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let flag = try Self.decode(Bool.self, from: value) {
            self = .bool(flag)
        } else if let number = try Self.decode(Double.self, from: value) {
            self = .number(number)
        } else if let text = try Self.decode(String.self, from: value) {
            self = .string(text)
        } else if let items = try Self.decode([JSONValue].self, from: value) {
            self = .array(items)
        } else {
            self = .object(try value.decode([String: JSONValue].self))
        }
    }

    /// The value as `type`, or nil when the JSON holds another kind of value.
    private static func decode<T: Decodable>(_ type: T.Type, from value: any SingleValueDecodingContainer) throws -> T? {
        do {
            return try value.decode(type)
        } catch DecodingError.typeMismatch {
            return nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let flag): try value.encode(flag)
        case .number(let number) where number.rounded() == number && abs(number) < 1e15: try value.encode(Int(number))
        case .number(let number): try value.encode(number)
        case .string(let text): try value.encode(text)
        case .array(let items): try value.encode(items)
        case .object(let fields): try value.encode(fields)
        }
    }

    /// The string field `key` of an object, or nil.
    func text(of key: String) -> String? {
        guard case .object(let fields) = self, case .string(let text)? = fields[key] else { return nil }
        return text
    }
}

struct EditFailure: Error, CustomStringConvertible {
    let description: String
}

/// The dot-separated segments of a path.
func segments(of path: String) -> ArraySlice<String> {
    path.isEmpty ? [] : ArraySlice(path.split(separator: ".", omittingEmptySubsequences: false).map(String.init))
}

/// The key and the text of a `key=text` segment, or nil when it has no `=`.
func match(_ segment: String) -> (key: String, text: String)? {
    guard let equals = segment.firstIndex(of: "=") else { return nil }
    return (String(segment[..<equals]), String(segment[segment.index(after: equals)...]))
}

/// The index of the element of `items` a segment names.
func position(of segment: String, in items: [JSONValue]) throws -> Int {
    if let (key, text) = match(segment) {
        guard let index = items.firstIndex(where: { $0.text(of: key) == text }) else {
            throw EditFailure(description: "no element has \(key) equal to \(text)")
        }
        return index
    }
    guard let index = Int(segment), items.indices.contains(index) else {
        throw EditFailure(description: "\(segment) is not an element of an array of \(items.count)")
    }
    return index
}

/// The value at `path` in `node`.
func value(at path: ArraySlice<String>, in node: JSONValue) throws -> JSONValue {
    guard let segment = path.first else { return node }
    switch node {
    case .array(let items):
        return try value(at: path.dropFirst(), in: items[position(of: segment, in: items)])
    case .object(let fields):
        guard let child = fields[segment] else { throw EditFailure(description: "no key \(segment)") }
        return try value(at: path.dropFirst(), in: child)
    default:
        throw EditFailure(description: "\(segment) leads into a value that is neither an array nor an object")
    }
}

/// Changes the value at `path` in `node`: `change` is given the value there (nil for a key an object does not have) and
/// leaves the new one, or nil to take it away.
func edit(_ node: inout JSONValue, at path: ArraySlice<String>, _ change: (inout JSONValue?) throws -> Void) throws {
    guard let segment = path.first else {
        var whole: JSONValue? = node
        try change(&whole)
        guard let whole else { throw EditFailure(description: "the whole document cannot be taken away") }
        node = whole
        return
    }
    let rest = path.dropFirst()
    switch node {
    case .array(var items):
        let index = try position(of: segment, in: items)
        if rest.isEmpty {
            var element: JSONValue? = items[index]
            try change(&element)
            if let element { items[index] = element } else { items.remove(at: index) }
        } else {
            try edit(&items[index], at: rest, change)
        }
        node = .array(items)
    case .object(var fields):
        if rest.isEmpty {
            var field = fields[segment]
            try change(&field)
            fields[segment] = field
        } else {
            guard var child = fields[segment] else { throw EditFailure(description: "no key \(segment)") }
            try edit(&child, at: rest, change)
            fields[segment] = child
        }
        node = .object(fields)
    default:
        throw EditFailure(description: "\(segment) leads into a value that is neither an array nor an object")
    }
}

/// The items of an array value; `name` says which value in the error.
func items(of value: JSONValue?, _ name: String) throws -> [JSONValue] {
    guard case .array(let items)? = value else { throw EditFailure(description: "\(name) is not an array") }
    return items
}

func document(at url: URL) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
}

func parse(_ text: String) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
}

func run(_ arguments: [String]) throws {
    let usage = EditFailure(description: "usage: JSONEdit <file> set|append|extend|insert|remove|keep|copy <operands> (see main.swift)")
    guard arguments.count >= 3 else { throw usage }
    let file = URL(fileURLWithPath: arguments[0]), operands = Array(arguments.dropFirst(2)), path = segments(of: arguments[2])
    var root = try document(at: file)
    switch (arguments[1], operands.count) {
    case ("set", 2):
        let new = try parse(operands[1])
        try edit(&root, at: path) { $0 = new }
    case ("append", 2):
        let new = try parse(operands[1])
        try edit(&root, at: path) { $0 = .array(try items(of: $0, operands[0]) + [new]) }
    case ("extend", 2):
        let new = try items(of: parse(operands[1]), operands[1])
        try edit(&root, at: path) { $0 = .array(try items(of: $0, operands[0]) + new) }
    case ("insert", 3):
        let new = try items(of: parse(operands[2]), operands[2])
        guard let index = Int(operands[1]) else { throw usage }
        try edit(&root, at: path) {
            var array = try items(of: $0, operands[0])
            guard (0...array.count).contains(index) else {
                throw EditFailure(description: "\(index) is outside an array of \(array.count)")
            }
            array.insert(contentsOf: new, at: index)
            $0 = .array(array)
        }
    case ("remove", 1):
        try edit(&root, at: path) {
            guard $0 != nil else { throw EditFailure(description: "nothing at \(operands[0])") }
            $0 = nil
        }
    case ("keep", 2):
        guard let (key, text) = match(operands[1]) else { throw usage }
        try edit(&root, at: path) { $0 = .array(try items(of: $0, operands[0]).filter { $0.text(of: key) == text }) }
    case ("copy", 3):
        let new = try value(at: segments(of: operands[1]), in: document(at: URL(fileURLWithPath: operands[0])))
        try edit(&root, at: segments(of: operands[2])) { $0 = new }
    default:
        throw usage
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(root).write(to: file, options: .atomic)
}

do {
    try run(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("JSONEdit: \(error)\n".utf8))
    exit(1)
}
