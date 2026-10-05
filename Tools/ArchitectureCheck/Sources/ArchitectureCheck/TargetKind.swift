import Foundation

/// What a target is. The kinds are a closed set: a misspelt one in `rules.json` would leave a production target without its
/// detectors while the modules check still treated it as production, so decoding refuses a kind that is not one of these.
enum TargetKind: String, Decodable, CaseIterable {
    case production, test, tool, manifest, legacy, excluded

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let kind = Self(rawValue: name) else {
            let known = Self.allCases.map(\.rawValue).joined(separator: ", ")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown target kind \"\(name)\"; the kinds are \(known)")
        }
        self = kind
    }
}
