import Foundation

/// A design's version, `MAJOR.MINOR.PATCH`, ordered by number: `1.0.10` is later than `1.0.9`. Each part is `0` or
/// one to nine ASCII digits without a leading zero, so a version has one spelling (`text`) and fits an `Int`. It is
/// stored and decoded as that text; a text that is not a version does not decode.
public struct DesignVersion: Comparable, Hashable, Sendable, Codable {
    let major: Int, minor: Int, patch: Int

    public init?(_ text: String) {
        var parts = text.split(separator: ".").makeIterator()
        guard text.fullyMatches(#"(?:0|[1-9][0-9]{0,8})(?:\.(?:0|[1-9][0-9]{0,8})){2}"#),
              let major = parts.next().flatMap({ Int($0) }), let minor = parts.next().flatMap({ Int($0) }),
              let patch = parts.next().flatMap({ Int($0) }) else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }

    /// The version as written in a manifest.
    public var text: String { "\(major).\(minor).\(patch)" }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let version = DesignVersion(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a MAJOR.MINOR.PATCH version"))
        }
        self = version
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    public static func < (lhs: DesignVersion, rhs: DesignVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
