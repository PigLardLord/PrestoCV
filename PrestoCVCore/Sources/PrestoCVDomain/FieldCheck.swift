import Foundation

/// What a rule of the editor says about the text of a field. White space around the text does not count.
public enum FieldCheck: Equatable, Sendable {
    /// Nothing is written in the field: there is nothing to say about it.
    case empty
    /// The text reads as what the field asks for.
    case plausible
    /// The text cannot be what the field asks for.
    case implausible

    /// An e-mail address is one `EmailAddress` accepts: a local part, an at sign and a domain with its top-level label.
    public static func email(_ text: String) -> FieldCheck {
        check(text) { EmailAddress($0) != nil }
    }

    /// A web address is one `WebLink` accepts: http or https, with a host and no credentials.
    public static func webAddress(_ text: String) -> FieldCheck {
        check(text) { WebLink($0) != nil }
    }

    /// A phone number has a digit: from text without one, such as "call me", no number can be called. How the number is
    /// written is up to the person, so that an extension or a note beside it is no reason to doubt it.
    public static func phoneNumber(_ text: String) -> FieldCheck {
        check(text) { $0.contains(where: \.isWholeNumber) }
    }

    private static func check(_ text: String, passes rule: (String) -> Bool) -> FieldCheck {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        return rule(trimmed) ? .plausible : .implausible
    }
}
