import Foundation

/// The one rule for the personal details of a published document (R6, R8), applied to a `Person` by `CVDocumentValidator` and by
/// `LetterDocumentValidator` for the sender. The name must say something. Every text is bounded in UTF-8 bytes and follows
/// `DocumentText`, so it may hold line breaks (a location of several lines) and is not trimmed: Authoring keeps the details as
/// the person wrote them, so a CV or a letter that it saves never fails to render for them.
package enum PersonRule {
    package enum Field: CaseIterable, Sendable {
        case name, title, email, phone, location, website

        package var label: String {
            switch self {
            case .name: "name"
            case .title: "title"
            case .email: "email"
            case .phone: "phone"
            case .location: "location"
            case .website: "website"
            }
        }
    }

    package enum Violation: Equatable, Sendable { case nameRequired, text(Field) }

    /// The first thing wrong with `person`, or nil. Each text adds its bytes to `total`, which a document that bounds the whole of
    /// its text carries from one field to the next, and must not pass `maxTotal`.
    package static func violation(in person: Person, maxTextBytes: Int, total: inout Int, maxTotal: Int) -> Violation? {
        guard !person.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .nameRequired }
        let texts: [(Field, String?)] = [(.name, person.name), (.title, person.professionalTitle), (.email, person.email),
                                         (.phone, person.phone), (.location, person.location), (.website, person.website)]
        for (field, text) in texts {
            guard let text else { continue }
            total += text.utf8.count
            guard text.utf8.count <= maxTextBytes, total <= maxTotal, !text.unicodeScalars.contains(where: { DocumentText.refuses($0, allowingLineBreak: true) }) else {
                return .text(field)
            }
        }
        return nil
    }
}
