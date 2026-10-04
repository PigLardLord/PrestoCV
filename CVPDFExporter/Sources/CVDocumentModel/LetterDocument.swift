import Foundation   // value types only

/// How the page addresses the recipient. It picks the salutation and the valediction from the language's conventions;
/// `neutral` names nobody ("Dear Sir or Madam").
public enum FormOfAddress: String, Codable, Sendable, CaseIterable { case masculine, feminine, neutral }

/// Whom the letter is written to. The salutation is the page's, written from `formOfAddress` and `familyName`.
public struct LetterRecipient: Codable, Sendable, Equatable {
    public var formOfAddress: FormOfAddress
    /// "Dr." or "Dott.ssa", as the advert writes it: printed before the name, on its line. It is a field of its own, so a title and a
    /// name that Authoring keeps at their bounds are never joined into one that no field holds.
    public var title: String?
    /// As printed in the address block.
    public var name: String?
    /// What the salutation names ("Dear Ms Rossi"). Required unless the form of address is neutral.
    public var familyName: String?
    public var company: String?
    public var address: [String]
    public init(formOfAddress: FormOfAddress = .neutral, title: String? = nil, name: String? = nil, familyName: String? = nil, company: String? = nil,
                address: [String] = []) {
        self.formOfAddress = formOfAddress; self.title = title; self.name = name; self.familyName = familyName; self.company = company
        self.address = address
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
/// conventions (R13), so the body holds only what the author says. A field holds one line of text, except the
/// paragraphs of `body` and the `closing`, which may hold line breaks; a paragraph is one element of `body`.
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
    /// They are what Authoring can keep, so a letter it saves is one this accepts (ADR 0019): a line or a paragraph of up to
    /// 10,000 bytes, an opening and 20 paragraphs (which make the body), 20 attachments and 6 address lines (8 are accepted).
    /// A letter that is too long for its page is not invalid: the export refuses it, with the number of pages it needed.
    static let maxTextBytes = 10_000
    static let maxParagraphs = 1 + 20, maxAddressLines = 8, maxAttachments = 20
    /// The most text a letter holds, with every field at its bound: the sender's 6 fields at the CV's bound of 16,384 bytes, and 36
    /// fields of one line (the signature, the recipient's four, the address lines, the place, the reference, the subject and the
    /// attachments) and 22 of several (the paragraphs and the closing) at 10,000. That is 98,304 + 580,000 = 678,304 bytes.
    static let maxLetterTextBytes = 6 * CVDocumentValidator.maxTextBytes
        + (1 + 4 + maxAddressLines + 3 + maxAttachments + maxParagraphs + 1) * maxTextBytes
    /// The largest JSON document `decode` accepts, checked before decoding. A producer that escapes every scalar outside
    /// ASCII writes a scalar of four bytes in twelve, so a letter at its bounds takes up to three times its text,
    /// 2,034,912 bytes, and the keys and punctuation take under 10,000 more.
    public static let maxJSONBytes = 2_100_000

    /// The reasons name the field, as the CV validator's do.
    static func textReason(_ what: String) -> String { "\(what) is too long, or it has control characters or bidirectional overrides" }
    static func whitespaceReason(_ what: String) -> String { "\(what) starts or ends with white space" }

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
        guard d.recipient.formOfAddress == .neutral || !blank(d.recipient.familyName) else { throw Invalid(reason: "the recipient's family name is required") }
        guard isCalendarDate(d.date) else { throw Invalid(reason: "the date does not exist") }
        guard d.body.count <= maxParagraphs else { throw Invalid(reason: "too many paragraphs") }
        guard d.recipient.address.count <= maxAddressLines else { throw Invalid(reason: "too many address lines") }
        guard d.attachments.count <= maxAttachments else { throw Invalid(reason: "too many attachments") }

        /// A field of one line refuses every control character, a line break among them, by the rule that CV text follows, and
        /// is trimmed: Authoring trims what it keeps, so only a JSON client sends one that is not. A paragraph and the closing
        /// may hold line breaks.
        func text(_ s: String?, _ what: String, multiline: Bool = false) throws(Invalid) {
            guard let s else { return }
            guard s.utf8.count <= maxTextBytes, !s.unicodeScalars.contains(where: { DocumentText.refuses($0, allowingLineBreak: multiline) }) else {
                throw Invalid(reason: textReason(what))
            }
            if !multiline, s != s.trimmingCharacters(in: .whitespacesAndNewlines) { throw Invalid(reason: whitespaceReason(what)) }
        }
        try text(d.name, "the name")
        // The sender is held to the rule that a CV's person follows, whose bound is the CV's: it is applied by the one function that
        // both validators share. A letter has no total over its text, since its counts and field bounds already limit it.
        var total = 0
        switch PersonRule.violation(in: d.sender, maxTextBytes: CVDocumentValidator.maxTextBytes, total: &total, maxTotal: Int.max) {
        case .nameRequired?: throw Invalid(reason: "the sender's name is required")
        case .text(let field)?: throw Invalid(reason: textReason("the sender's \(field.label)"))
        case nil: break
        }
        try text(d.recipient.title, "the recipient's title"); try text(d.recipient.name, "the recipient's name"); try text(d.recipient.familyName, "the recipient's family name"); try text(d.recipient.company, "the recipient's company")
        try text(d.place, "the place"); try text(d.reference, "the reference"); try text(d.subject, "the subject")
        for line in d.recipient.address { try text(line, "an address line") }
        for attachment in d.attachments { try text(attachment, "an attachment") }
        for paragraph in d.body { try text(paragraph, "a paragraph", multiline: true) }
        try text(d.closing, "the closing", multiline: true)
    }
}
