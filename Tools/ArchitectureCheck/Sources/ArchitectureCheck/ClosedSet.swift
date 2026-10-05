import Foundation

/// A setting of `rules.json` that is one word out of a closed set. Decoding refuses any other word, because a misspelt one
/// would switch a check off or leave a target out of it without a sound.
protocol ClosedSet: CaseIterable, Decodable, RawRepresentable where RawValue == String {
    /// What the word names, as the message says it: "target kind".
    static var subject: String { get }
}

extension ClosedSet {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let word = try container.decode(String.self)
        guard let value = Self(rawValue: word) else {
            let choices = Self.allCases.map(\.rawValue).joined(separator: ", ")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown \(Self.subject) \"\(word)\"; the choices are \(choices)")
        }
        self = value
    }
}
