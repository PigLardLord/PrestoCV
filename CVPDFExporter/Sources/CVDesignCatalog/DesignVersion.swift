import Foundation

/// A design's version, `MAJOR.MINOR.PATCH`, ordered by number: `1.0.10` is later than `1.0.9`. Each part is `0` or
/// one to nine ASCII digits without a leading zero, so a version has one spelling and fits an `Int`. Only the validator
/// creates one, from the manifest's `version` text, and `ValidatedDesign` carries it.
public struct DesignVersion: Comparable, Sendable {
    let major: Int, minor: Int, patch: Int

    init?(_ text: String) {
        guard text.fullyMatches(#"(?:0|[1-9][0-9]{0,8})(?:\.(?:0|[1-9][0-9]{0,8})){2}"#) else { return nil }
        let parts = text.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.major = parts[0]; self.minor = parts[1]; self.patch = parts[2]
    }

    public static func < (lhs: DesignVersion, rhs: DesignVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
