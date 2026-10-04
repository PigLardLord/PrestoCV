import Foundation

/// How a letter addresses its recipient, as a code the page words (R13). A form of address is used only when the advert
/// writes one before the contact's name: it is never guessed from a first name.
public enum FormOfAddress: String, Hashable, Sendable, CaseIterable { case ms, mr, neutral }

/// Whom a cover letter is addressed to, as the advert writes it. Every text is bounded and optional, and an empty one is
/// absent (R6).
public struct LetterRecipient: Hashable, Sendable {
    public let company: String?, contactName: String?
    public let formOfAddress: FormOfAddress
    public let title: String?, surname: String?, role: String?
    public let address: [String]

    public init(company: String? = nil, contactName: String? = nil, formOfAddress: FormOfAddress = .neutral, title: String? = nil,
                surname: String? = nil, role: String? = nil, address: [String] = []) throws(ApplicationError) {
        let line = CoverLetter.maxLineBytes
        self.company = try ApplicationTextRule.optional(company, .recipientCompany, maxBytes: line)
        self.contactName = try ApplicationTextRule.optional(contactName, .recipientContactName, maxBytes: line)
        self.formOfAddress = formOfAddress
        self.title = try ApplicationTextRule.optional(title, .recipientTitle, maxBytes: line)
        self.surname = try ApplicationTextRule.optional(surname, .recipientSurname, maxBytes: line)
        self.role = try ApplicationTextRule.optional(role, .recipientRole, maxBytes: line)
        self.address = try ApplicationTextRule.list(address, .recipientAddress, maxCount: CoverLetter.maxAddressLines, maxBytes: line)
    }
}

/// The letter that a tailoring wrote and that the user keeps and edits: whom it is addressed to, its reference, position and
/// subject, its opening, its body paragraphs, its closing and its attachments (ADR 0019). It is Authoring's own type, as
/// Tailoring has one of its own, and it is never built from Tailoring's (R1). It stores no salutation and no valediction:
/// the page writes them, from the recipient's form of address and the language (#141, #187).
///
/// Its parts validate on creation, so an invalid letter cannot exist (R6). To edit a letter is to build the edited one,
/// which the application then keeps (`Application.setLetter`).
public struct CoverLetter: Hashable, Sendable {
    /// What a single line holds, in UTF-8 bytes, and what a paragraph holds.
    public static let maxLineBytes = 256, maxParagraphBytes = 4_000
    public static let maxAddressLines = 6, maxParagraphs = 20, maxAttachments = 10

    public let recipient: LetterRecipient
    public let reference: String?, position: String?, subject: String?
    public let opening: String?, paragraphs: [String], closing: String?
    public let attachments: [String]

    public init(recipient: LetterRecipient, reference: String? = nil, position: String? = nil, subject: String? = nil,
                opening: String? = nil, paragraphs: [String] = [], closing: String? = nil, attachments: [String] = []) throws(ApplicationError) {
        self.recipient = recipient
        self.reference = try ApplicationTextRule.optional(reference, .reference, maxBytes: Self.maxLineBytes)
        self.position = try ApplicationTextRule.optional(position, .position, maxBytes: Self.maxLineBytes)
        self.subject = try ApplicationTextRule.optional(subject, .subject, maxBytes: Self.maxLineBytes)
        self.opening = try ApplicationTextRule.optional(opening, .opening, maxBytes: Self.maxParagraphBytes, multiline: true)
        self.paragraphs = try ApplicationTextRule.list(paragraphs, .paragraph, maxCount: Self.maxParagraphs, maxBytes: Self.maxParagraphBytes, multiline: true)
        self.closing = try ApplicationTextRule.optional(closing, .closing, maxBytes: Self.maxParagraphBytes, multiline: true)
        self.attachments = try ApplicationTextRule.list(attachments, .attachment, maxCount: Self.maxAttachments, maxBytes: Self.maxLineBytes)
    }
}
