import Foundation   // value types only

/// How the page addresses the recipient. It picks the salutation and the valediction from the language's conventions;
/// `neutral` names nobody ("Dear Sir or Madam").
public enum FormOfAddress: String, Codable, Sendable, CaseIterable { case masculine, feminine, neutral }

/// Whom the letter is written to. The salutation is the page's, written from `formOfAddress` and `familyName`.
public struct LetterRecipient: Codable, Sendable, Equatable {
    public var formOfAddress: FormOfAddress
    /// As printed in the address block.
    public var name: String?
    /// What the salutation names ("Dear Ms Rossi"). Required unless the form of address is neutral.
    public var familyName: String?
    public var company: String?
    public var address: [String]
    public init(formOfAddress: FormOfAddress = .neutral, name: String? = nil, familyName: String? = nil, company: String? = nil, address: [String] = []) {
        self.formOfAddress = formOfAddress; self.name = name; self.familyName = familyName; self.company = company; self.address = address
    }
}

/// A calendar date. Formatting is the page's job, in the document's language.
public struct LetterDate: Codable, Sendable, Equatable {
    public var year: Int, month: Int, day: Int
    public init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }
}

/// The second published document of the exporter, beside `CVDocument` (ADR 0019): a cover letter, rendered in one fixed
/// layout for every design. Plain values and no PrestoCV type (ADR 0002). Its JSON is hand-written and versioned.
///
/// The salutation, the valediction and the date's words are not fields: the page writes them from the language's
/// conventions (R13), so the body holds only what the author says. A field holds one line of text; a paragraph is one
/// element of `body`, and no field carries a line break.
public struct LetterDocument: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    /// The primary language subtags the page has conventions for. A test holds this list to the conventions data.
    public static let supportedLanguages = ["en", "it", "de", "es", "fr", "pt"]

    public let schemaVersion: Int
    public var language: String            // BCP 47, one of `supportedLanguages` by its primary subtag, e.g. "it", "pt-BR"
    public var sender: Person              // the personal details; the page prints them in the letter's head
    public var recipient: LetterRecipient
    public var place: String?
    public var date: LetterDate
    public var reference: String?
    public var subject: String?
    public var body: [String]              // paragraphs, without the salutation and the valediction
    public var closing: String?            // the last paragraph, before the valediction
    public var name: String                // the signature
    public var attachments: [String]

    public init(language: String, sender: Person, recipient: LetterRecipient = LetterRecipient(), place: String? = nil, date: LetterDate,
                reference: String? = nil, subject: String? = nil, body: [String], closing: String? = nil, name: String, attachments: [String] = []) {
        self.schemaVersion = Self.currentSchemaVersion
        self.language = language; self.sender = sender; self.recipient = recipient; self.place = place; self.date = date
        self.reference = reference; self.subject = subject; self.body = body; self.closing = closing; self.name = name; self.attachments = attachments
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, language, sender, recipient, place, date, reference, subject, body, closing, name, attachments
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: c, debugDescription: "unsupported schemaVersion \(version)")
        }
        schemaVersion = version
        language = try c.decode(String.self, forKey: .language)
        sender = try c.decode(Person.self, forKey: .sender)
        recipient = try c.decode(LetterRecipient.self, forKey: .recipient)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        date = try c.decode(LetterDate.self, forKey: .date)
        reference = try c.decodeIfPresent(String.self, forKey: .reference)
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        body = try c.decode([String].self, forKey: .body)
        closing = try c.decodeIfPresent(String.self, forKey: .closing)
        name = try c.decode(String.self, forKey: .name)
        attachments = try c.decode([String].self, forKey: .attachments)
    }
}

/// Anti-corruption layer for letters arriving from outside (a backend request, a file), beside `CVDocumentValidator` (R8,
/// ADR 0019). A letter that passes can be rendered: the rendering writes the salutation from the recipient's form of
/// address, so the family name it needs is checked here.
public enum LetterDocumentValidator {
    public struct Invalid: Error, Equatable, Sendable { public let reason: String }
    /// Bounds in UTF-8 bytes, not characters: a letter followed by any number of combining marks is one character.
    /// A one-page letter is far below them; they only keep a hostile one from costing memory.
    static let maxTextBytes = 4_096, maxDocumentTextBytes = 32_768
    static let maxParagraphs = 40, maxAddressLines = 8, maxAttachments = 20
    /// The largest JSON document `decode` accepts, checked before decoding.
    public static let maxJSONBytes = 131_072

    static let textReason = "a field is too long, the letter is too large, or it has control or hidden characters"

    /// The entry point for a letter that arrives as JSON: the size is checked before decoding, and the decoded letter is validated.
    public static func decode(json: Data) throws(Invalid) -> LetterDocument {
        guard json.count <= maxJSONBytes else { throw Invalid(reason: "document is too large") }
        let letter: LetterDocument
        do { letter = try JSONDecoder().decode(LetterDocument.self, from: json) }
        catch let DecodingError.dataCorrupted(context) where context.codingPath.last?.stringValue == LetterDocument.CodingKeys.schemaVersion.rawValue {
            throw Invalid(reason: "unsupported schema version")
        } catch { throw Invalid(reason: "not a letter document") }
        try validate(letter)
        return letter
    }

    /// A character that is not shown, or that changes what is shown: controls (a line break among them), the line and
    /// paragraph separators, and every format character, which takes in the bidirectional overrides and isolates that
    /// reorder what is printed, the zero-width characters and the tag characters. None belongs to a letter in the six languages.
    static func hidesOrReorders(_ s: Unicode.Scalar) -> Bool {
        switch s.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator: true
        default: false
        }
    }

    /// The primary language subtag of a BCP 47-shaped tag is one of the supported languages.
    static func isSupported(language: String) -> Bool {
        let subtags = language.split(separator: "-", omittingEmptySubsequences: false)
        guard let primary = subtags.first, (2...3).contains(primary.count), primary.unicodeScalars.allSatisfy({ $0.isASCII && $0.properties.isAlphabetic }),
              subtags.count <= 4, subtags.dropFirst().allSatisfy({ (2...8).contains($0.count) && $0.unicodeScalars.allSatisfy { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0)) } })
        else { return false }
        return LetterDocument.supportedLanguages.contains(primary.lowercased())
    }

    static func isCalendarDate(_ d: LetterDate) -> Bool {
        guard (1900...2200).contains(d.year), (1...12).contains(d.month), d.day >= 1 else { return false }
        let leap = (d.year % 4 == 0 && d.year % 100 != 0) || d.year % 400 == 0
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return d.day <= days[d.month - 1]
    }

    private static func blank(_ s: String?) -> Bool { s?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }

    public static func validate(_ d: LetterDocument) throws(Invalid) {
        guard isSupported(language: d.language) else { throw Invalid(reason: "language is not supported") }
        guard !blank(d.name) else { throw Invalid(reason: "the name is required") }
        guard !blank(d.sender.name) else { throw Invalid(reason: "the sender's name is required") }
        guard d.body.contains(where: { !blank($0) }) else { throw Invalid(reason: "a paragraph is required") }
        guard d.recipient.formOfAddress == .neutral || !blank(d.recipient.familyName) else { throw Invalid(reason: "the recipient's family name is required") }
        guard isCalendarDate(d.date) else { throw Invalid(reason: "the date does not exist") }
        guard d.body.count <= maxParagraphs else { throw Invalid(reason: "too many paragraphs") }
        guard d.recipient.address.count <= maxAddressLines else { throw Invalid(reason: "too many address lines") }
        guard d.attachments.count <= maxAttachments else { throw Invalid(reason: "too many attachments") }

        var total = 0
        func text(_ s: String?) throws(Invalid) {
            guard let s else { return }
            total += s.utf8.count
            guard s.utf8.count <= maxTextBytes, total <= maxDocumentTextBytes, !s.unicodeScalars.contains(where: hidesOrReorders) else {
                throw Invalid(reason: textReason)
            }
        }
        for value in [d.sender.name, d.name] { try text(value) }
        for value in [d.sender.professionalTitle, d.sender.email, d.sender.phone, d.sender.location, d.sender.website] { try text(value) }
        for value in [d.recipient.name, d.recipient.familyName, d.recipient.company, d.place, d.reference, d.subject, d.closing] { try text(value) }
        for value in d.recipient.address + d.body + d.attachments { try text(value) }
    }
}
