import Testing
import Foundation

/// One change to `ModelSamples.populated`: a place in the document, and what to do there.
struct BoundaryCase: Sendable, CustomTestStringConvertible {
    enum Step: Sendable, Hashable {
        case key(String)
        case index(Int)
    }

    enum Edit: Sendable {
        /// Replaces the value with this JSON text.
        case replace(String)
        /// Removes the key the path ends on.
        case remove
        /// Adds a property that no schema declares to the object the path ends on.
        case addUnknownProperty
        /// Makes the array the path ends on hold this many copies of its first element.
        case resize(Int)
    }

    /// What the exporter is expected to say. It makes the matrix check its own aim: a change that stops probing the
    /// boundary it was written for fails instead of passing.
    enum Premise: Sendable {
        /// The change is valid; only the order of a period's dates may still refuse it.
        case exporterAccepts
        case exporterRefuses
        /// The field is optional or required: the exporter says which.
        case exporterDecides
        /// The exporter refuses it on a byte limit that the schema cannot express.
        case exceedsSchema
    }

    let path: [Step], change: String, edit: Edit, premise: Premise

    var testDescription: String {
        let place = path.map { step in
            switch step {
            case .key(let name): "." + name
            case .index(let position): "[\(position)]"
            }
        }
        return "$" + place.joined() + ": " + change
    }
}

/// Every change worth making to every place of a document that has all its optional fields. Each node of the document is
/// visited, so each site of the schema (including the ones that share a definition) is probed at its own boundaries.
enum BoundaryMatrix {
    /// The bounds of the integer fields of the model, as the validator checks them.
    static let bounds: [String: ClosedRange<Int>] = ["schemaVersion": 1...1, "year": 1900...2200, "month": 1...12, "rating": 1...5]

    /// The fields that hold one of a closed set of words, so that no free text fits.
    static let wordFields: Set<String> = ["kind", "end", "level"]

    struct Node {
        let path: [BoundaryCase.Step], value: JSON
    }

    static let populated: JSON = (try? JSON(parsing: JSONEncoder().encode(ModelSamples.populated))) ?? .null

    static let nodes: [Node] = {
        var all: [Node] = []
        collect(populated, at: [], into: &all)
        return all
    }()

    static let cases: [BoundaryCase] = {
        var all: [BoundaryCase] = []
        for node in nodes { changes(to: node, into: &all) }
        return all
    }()

    /// The names of the integer fields of the document.
    static var integerFields: Set<String> {
        Set(nodes.compactMap { node in
            if case .number = node.value, case .key(let name)? = node.path.last { name } else { nil }
        })
    }

    static func render(_ testCase: BoundaryCase) -> String { render(populated, path: testCase.path[...], edit: testCase.edit) }

    // MARK: Making the changes

    private static func collect(_ value: JSON, at path: [BoundaryCase.Step], into all: inout [Node]) {
        all.append(Node(path: path, value: value))
        switch value {
        case .object(let members):
            for (name, member) in members.inKeyOrder { collect(member, at: path + [.key(name)], into: &all) }
        case .array(let elements):
            for (position, element) in elements.enumerated() { collect(element, at: path + [.index(position)], into: &all) }
        default:
            break
        }
    }

    private static func changes(to node: Node, into all: inout [BoundaryCase]) {
        func add(_ change: String, _ edit: BoundaryCase.Edit, _ premise: BoundaryCase.Premise, at path: [BoundaryCase.Step]? = nil) {
            all.append(BoundaryCase(path: path ?? node.path, change: change, edit: edit, premise: premise))
        }
        add("null", .replace("null"), .exporterDecides)
        switch node.value {
        case .string:
            var isWord = false
            if case .key(let name)? = node.path.last { isWord = wordFields.contains(name) }
            let characters = String(repeating: "a", count: 16_384), twoByte = String(repeating: "\u{00E9}", count: 8_192)
            add("a number instead of text", .replace("5"), .exporterRefuses)
            add("empty", .replace(quote("")), .exporterDecides)
            add("16,384 characters", .replace(quote(characters)), isWord ? .exporterRefuses : .exporterAccepts)
            add("16,385 characters", .replace(quote(characters + "a")), .exporterRefuses)
            add("16,384 bytes in two-byte characters", .replace(quote(twoByte)), isWord ? .exporterRefuses : .exporterAccepts)
            add("16,386 bytes in two-byte characters", .replace(quote(twoByte + "\u{00E9}")), isWord ? .exporterRefuses : .exceedsSchema)
        case .number(let current):
            add("text instead of a number", .replace(quote("7")), .exporterRefuses)
            if case .key(let name)? = node.path.last, let range = bounds[name] {
                add("\(range.lowerBound - 1)", .replace("\(range.lowerBound - 1)"), .exporterRefuses)
                add("\(range.lowerBound)", .replace("\(range.lowerBound)"), .exporterAccepts)
                if range.upperBound != range.lowerBound { add("\(range.upperBound)", .replace("\(range.upperBound)"), .exporterAccepts) }
                add("\(range.upperBound + 1)", .replace("\(range.upperBound + 1)"), .exporterRefuses)
                add("\(Int(current)) written as \(Int(current)).0", .replace("\(Int(current)).0"), .exporterAccepts)
                add("\(Int(current)).5", .replace("\(Int(current)).5"), .exporterRefuses)
            }
        case .object(let members):
            add("text instead of an object", .replace(quote("x")), .exporterRefuses)
            for (name, _) in members.inKeyOrder { add("\(name) removed", .remove, .exporterDecides, at: node.path + [.key(name)]) }
            add("an unknown property", .addUnknownProperty, .exporterAccepts)
        case .array:
            add("an object instead of an array", .replace("{}"), .exporterRefuses)
            add("200 elements", .resize(200), .exporterAccepts)
            add("201 elements", .resize(201), .exporterRefuses)
        case .bool, .null:
            break
        }
    }

    // MARK: Writing the document

    private static func render(_ value: JSON, path: ArraySlice<BoundaryCase.Step>, edit: BoundaryCase.Edit) -> String {
        guard let step = path.first else { return renderTarget(value, edit: edit) }
        switch (value, step) {
        case (.object(let members), .key(let name)):
            let parts = members.inKeyOrder.compactMap { key, member -> String? in
                guard key == name else { return quote(key) + ":" + plain(member) }
                if path.count == 1, case .remove = edit { return nil }
                return quote(key) + ":" + render(member, path: path.dropFirst(), edit: edit)
            }
            return "{" + parts.joined(separator: ",") + "}"
        case (.array(let elements), .index(let position)):
            let parts = elements.enumerated().map { offset, element in
                offset == position ? render(element, path: path.dropFirst(), edit: edit) : plain(element)
            }
            return "[" + parts.joined(separator: ",") + "]"
        default:
            return plain(value)
        }
    }

    private static func renderTarget(_ value: JSON, edit: BoundaryCase.Edit) -> String {
        switch (edit, value) {
        case (.replace(let text), _):
            return text
        case (.addUnknownProperty, .object(let members)):
            return "{" + (members.inKeyOrder.map { quote($0.key) + ":" + plain($0.value) } + [#""unknownProperty":[null]"#]).joined(separator: ",") + "}"
        case (.resize(let count), .array(let elements)):
            guard let first = elements.first else { return "[]" }
            return "[" + Array(repeating: plain(first), count: count).joined(separator: ",") + "]"
        default:
            return plain(value)
        }
    }

    private static func plain(_ value: JSON) -> String {
        switch value {
        case .null: "null"
        case .bool(let flag): flag ? "true" : "false"
        case .number(let number): number == number.rounded() ? String(Int(number)) : "\(number)"
        case .string(let text): quote(text)
        case .array(let elements): "[" + elements.map(plain).joined(separator: ",") + "]"
        case .object(let members): "{" + members.inKeyOrder.map { quote($0.key) + ":" + plain($0.value) }.joined(separator: ",") + "}"
        }
    }

    static func quote(_ text: String) -> String {
        var quoted = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": quoted += "\\\""
            case "\\": quoted += "\\\\"
            case _ where scalar.value < 0x20: quoted += String(format: "\\u%04X", scalar.value)
            default: quoted.unicodeScalars.append(scalar)
            }
        }
        return quoted + "\""
    }
}
