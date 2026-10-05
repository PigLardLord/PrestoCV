import Foundation
import CVDesignCatalog

/// A link that is safe to print (RichDomain, ValidatingBoundary). Built only from input that parses cleanly; the emitted form is
/// the parser's serialisation, not the input text.
public struct WebLink: Sendable, Equatable {
    public let url: String
    static let maxLength = 2048

    /// Parses `raw` as an `http`, `https`, `mailto` or `tel` link, or returns nil.
    ///
    /// The text must be at most 2048 bytes of printable ASCII with no backslash. An `http(s)` link needs an ASCII host
    /// (an international name must arrive as punycode), no credentials and the default port; a `mailto` link needs one
    /// address and no query; a `tel` link needs a number and no query.
    public init?(_ raw: String) {
        guard Self.hasSafeCharacters(raw), let components = URLComponents(string: raw), Self.isAllowed(components),
              let serialized = components.string else { return nil }
        url = serialized
    }

    private static func hasSafeCharacters(_ raw: String) -> Bool {
        raw.utf8.count <= maxLength && raw.unicodeScalars.allSatisfy { $0.isASCII && $0.value > 0x20 && $0.value != 0x7F && $0 != "\\" }
    }

    private static func isAllowed(_ components: URLComponents) -> Bool {
        switch components.scheme?.lowercased() {
        case "https"?, "http"?: return isWebAddress(components)
        case "mailto"?: return isMailAddress(components)
        case "tel"?: return isTelephoneNumber(components)
        default: return false
        }
    }

    private static func isWebAddress(_ components: URLComponents) -> Bool {
        guard let host = components.host, host.fullyMatches(#"[A-Za-z0-9.-]{1,253}"#), components.user == nil, components.password == nil else {
            return false
        }
        return [nil, 80, 443].contains(components.port)
    }

    private static func isMailAddress(_ components: URLComponents) -> Bool {
        components.query == nil && components.path.fullyMatches(#"[^@\s,;?]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
    }

    private static func isTelephoneNumber(_ components: URLComponents) -> Bool {
        components.query == nil && components.path.fullyMatches(#"\+?[0-9-]{3,32}"#)
    }
}
