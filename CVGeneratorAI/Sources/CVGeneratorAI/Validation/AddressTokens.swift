import Foundation

/// The emails and links of a text, read as whole tokens.
///
/// A token is a run of characters between white space, brackets and quotes, without the sentence punctuation
/// at its end. An email or link counts only if the whole token is one; a token that mentions an address but
/// is not exactly one ("sam!anna@example.com", "see:example.com") is ambiguous, and so reads as neither.
/// An address is never taken out of the middle of a larger token.
struct AddressTokens {
    /// Emails, lowercased.
    let emails: [String]
    /// Links, in the form `normalizedLink` gives.
    let links: [String]
    /// Whether some token mentions an address without being exactly an email or a link.
    let hasAmbiguousAddress: Bool
    /// The text with every address token, clear or ambiguous, replaced by spaces, so that digits inside an
    /// address are not read as numbers.
    let remainder: String

    init(_ text: String) {
        // The tokens are read from a copy where the lookalikes of "." and "@" are the real ones, one character for one character so
        // that the positions stay: "market。io" is a link. `remainder` is still made of the characters as written.
        let original = Array(text)
        let characters = original.map(Self.withoutLookalikes)
        var blanked = original
        var emails: [String] = []
        var links: [String] = []
        var ambiguous = false

        var start = 0
        while start < characters.count {
            if Self.isSeparator(characters[start]) {
                start += 1
                continue
            }
            var end = start
            while end < characters.count && !Self.isSeparator(characters[end]) {
                end += 1
            }

            let token = Self.withoutTrailingPunctuation(String(characters[start..<end]))
            let kind = Self.kind(of: token)
            switch kind {
            case .email:
                emails.append(token.lowercased())
            case .link:
                links.append(Self.normalizedLink(token))
            case .ambiguous:
                ambiguous = true
            case .plain:
                break
            }
            if kind != .plain {
                for index in start..<(start + token.count) {
                    blanked[index] = " "
                }
            }
            start = end
        }

        self.emails = emails
        self.links = links
        self.hasAmbiguousAddress = ambiguous
        self.remainder = String(blanked)
    }

    /// Case, scheme, a leading "www." and a trailing slash do not make a link another link; a query or a fragment does.
    static func normalizedLink(_ link: String) -> String {
        var value = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = value.range(of: "^[a-z][a-z0-9+.\\-]*://", options: .regularExpression) {
            value.removeSubrange(scheme)
        }
        if value.hasPrefix("www.") {
            value.removeFirst(4)
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    // MARK: - Tokens

    /// The full stops of other scripts and the fullwidth and small at signs, which the reader takes for "." and "@".
    private static let lookalikeDots: Set<Character> = ["\u{3002}", "\u{FF0E}", "\u{FF61}", "\u{2024}", "\u{FE52}"]
    private static let lookalikeAts: Set<Character> = ["\u{FF20}", "\u{FE6B}"]

    private static func withoutLookalikes(_ character: Character) -> Character {
        if lookalikeDots.contains(character) { return "." }
        return lookalikeAts.contains(character) ? "@" : character
    }

    private enum Kind {
        case email, link, ambiguous, plain
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character.isWhitespace || "()[]{}<>\"'«»“”‘’".contains(character)
    }

    private static func withoutTrailingPunctuation(_ token: String) -> String {
        var value = token
        while let last = value.last, ".,;:!?".contains(last) {
            value.removeLast()
        }
        return value
    }

    private static func kind(of token: String) -> Kind {
        guard !token.isEmpty else { return .plain }
        if matches(emailPattern, token) { return .email }
        if matches(linkPattern, token) { return .link }
        if token.contains("@") || token.contains("://") || contains(addressInsidePattern, token) { return .ambiguous }
        return .plain
    }

    private static let emailPattern = makePattern("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)+$")
    private static let linkPattern = makePattern(
        "^(?:[A-Za-z][A-Za-z0-9+.\\-]*://)?(?:[A-Za-z0-9\\-]+\\.)+[A-Za-z]{2,}(?::[0-9]+)?(?:[/?#].*)?$"
    )
    private static let addressInsidePattern = makePattern("(?:[A-Za-z0-9\\-]+\\.)+[A-Za-z]{2,}")

    private static func makePattern(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants; every test that reads a token exercises them.
        try! NSRegularExpression(pattern: pattern)
    }

    private static func matches(_ pattern: NSRegularExpression, _ token: String) -> Bool {
        pattern.firstMatch(in: token, range: NSRange(token.startIndex..., in: token))?.range.length == token.utf16.count
    }

    private static func contains(_ pattern: NSRegularExpression, _ token: String) -> Bool {
        pattern.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)) != nil
    }
}
