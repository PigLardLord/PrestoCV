import Foundation
@testable import TailoringModel

/// A complete word-list file of format version 1 as a JSON object: one small list for every key the format knows, so a
/// test edits only what it varies. It is built by the same schema the decoder reads, so a new key joins every test.
enum WordListFixture {
    typealias Object = [String: Any]

    static func object() -> Object {
        var object: Object = ["version": 1]
        for key in WordListKey.allCases {
            var group = object[key.group] as? Object ?? [:]
            group[key.name] = list(for: key)
            object[key.group] = group
        }
        return object
    }

    static func data(_ object: Object = object()) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The fixture with one change made to it.
    static func data(editing edit: (inout Object) -> Void) throws -> Data {
        var object = object()
        edit(&object)
        return try data(object)
    }

    /// The fixture with one list changed.
    static func data(editing key: WordListKey, _ edit: (inout Object) -> Void) throws -> Data {
        try data { object in
            var group = object[key.group] as? Object ?? [:]
            var list = group[key.name] as? Object ?? [:]
            edit(&list)
            group[key.name] = list
            object[key.group] = group
        }
    }

    /// The lists whose entries are plain words, with no rule beyond the ones every list shares.
    static var textKeys: [WordListKey] {
        var shaped: [WordListKey] = []
        shaped.append(contentsOf: [.datesMonths, .numbersWords, .spansCountWords])
        shaped.append(contentsOf: [.advertSynonyms, .spansTiedCounts])
        return WordListKey.allCases.filter { !shaped.contains($0) }
    }

    static func list(for key: WordListKey) -> Object {
        var list: Object = ["source": "a test", "licence": "ISC", "entries": entries(for: key)]
        if key == .advertStreets { list["order"] = "after" }
        return list
    }

    static func entries(for key: WordListKey) -> [Any] {
        switch key {
        case .datesMonths:
            var months: [Any] = []
            for number in 1...12 { months.append(["name": "month\(number)", "month": number] as Object) }
            return months
        case .numbersWords, .spansCountWords:
            var numbers: [Any] = []
            numbers.append(["word": "two", "value": 2] as Object)
            numbers.append(["word": "three", "value": 3] as Object)
            return numbers
        case .advertSynonyms:
            var groups: [Any] = []
            groups.append(["forms": ["ui", "user interface"]] as Object)
            return groups
        case .spansTiedCounts:
            return ["{count} of them at {employer}"]
        default:
            var texts: [Any] = ["alpha"]
            texts.append("beta")
            return texts
        }
    }
}
