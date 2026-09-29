import Foundation

/// A link that is safe to print (R6, R8). Built only from input that parses cleanly; the emitted form is
/// the parser's serialisation, not the input text.
public struct WebLink: Sendable, Equatable {
    public let url: String
    static let maxLength = 2048

    public init?(_ raw: String) {
        guard raw.utf8.count <= Self.maxLength,
              raw.unicodeScalars.allSatisfy({ $0.isASCII && $0.value > 0x20 && $0.value != 0x7F && $0 != "\\" }),
              let c = URLComponents(string: raw), let scheme = c.scheme?.lowercased() else { return nil }
        switch scheme {
        case "https", "http":
            // Host required, ASCII only (IDN must arrive as punycode), no credentials, no port tricks.
            guard let host = c.host, !host.isEmpty, host.fullyMatches(#"[A-Za-z0-9.-]{1,253}"#),
                  c.user == nil, c.password == nil, c.port == nil || c.port == 443 || c.port == 80 else { return nil }
        case "mailto":
            guard c.query == nil, c.path.fullyMatches(#"[^@\s,;?]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#) else { return nil }
        case "tel":
            guard c.query == nil, c.path.fullyMatches(#"\+?[0-9-]{3,32}"#) else { return nil }
        default:
            return nil
        }
        guard let serialized = c.string else { return nil }
        url = serialized
    }
}

extension String {
    /// Whole-string match: `^…$` would accept a trailing newline, `\z` does not.
    func fullyMatches(_ pattern: String) -> Bool {
        range(of: "^(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
}
