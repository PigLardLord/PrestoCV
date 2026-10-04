import Foundation

/// A field of an application, of its cover letter or of the letter defaults whose value was refused. The field names the
/// place, never a text (R7, R13).
public enum ApplicationField: Hashable, Sendable {
    case letterDefault(LetterDefaults.Field)
    case recipientCompany, recipientContactName, recipientTitle, recipientSurname, recipientRole, recipientAddress
    case reference, position, subject, opening, paragraph, closing, attachment
}

/// Why a value of an application, of its cover letter or of the letter defaults is refused (R6). A code, never a text:
/// presentation words it (R13).
public enum ApplicationError: Error, Equatable, Sendable {
    case empty(ApplicationField)
    case tooLong(ApplicationField)
    case tooMany(ApplicationField)
    case forbiddenCharacters(ApplicationField)
}

/// The one rule for a text that a person or a tailoring wrote and that is stored and printed (R6): trimmed, bounded in
/// UTF-8 bytes (a letter followed by any number of combining marks is one character), and free of what could hide or
/// reorder it. It is as strict as `CVDocumentValidator`, so what Authoring keeps is never refused by the letter's
/// validator for its characters.
enum TextRule {
    static func trimmed(_ raw: String, _ field: ApplicationField, maxBytes: Int, multiline: Bool = false) throws(ApplicationError) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.count <= maxBytes else { throw .tooLong(field) }
        guard !text.unicodeScalars.contains(where: { forbidden($0, multiline: multiline) }) else { throw .forbiddenCharacters(field) }
        return text
    }

    /// A text that must say something.
    static func required(_ raw: String, _ field: ApplicationField, maxBytes: Int, multiline: Bool = false) throws(ApplicationError) -> String {
        let text = try trimmed(raw, field, maxBytes: maxBytes, multiline: multiline)
        guard !text.isEmpty else { throw .empty(field) }
        return text
    }

    /// A text that may be absent: an empty one is absent, never an empty string.
    static func optional(_ raw: String?, _ field: ApplicationField, maxBytes: Int, multiline: Bool = false) throws(ApplicationError) -> String? {
        guard let raw else { return nil }
        let text = try trimmed(raw, field, maxBytes: maxBytes, multiline: multiline)
        return text.isEmpty ? nil : text
    }

    /// A bounded list of texts that must each say something.
    static func list(_ raws: [String], _ field: ApplicationField, maxCount: Int, maxBytes: Int, multiline: Bool = false) throws(ApplicationError) -> [String] {
        guard raws.count <= maxCount else { throw .tooMany(field) }
        return try raws.map { (raw) throws(ApplicationError) in try required(raw, field, maxBytes: maxBytes, multiline: multiline) }
    }

    private static func forbidden(_ scalar: Unicode.Scalar, multiline: Bool) -> Bool {
        let control = scalar.properties.generalCategory == .control && !(multiline && scalar == "\n")
        let reorders = (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
        return control || reorders
    }
}
