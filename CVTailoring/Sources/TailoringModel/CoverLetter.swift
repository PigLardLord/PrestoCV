/// How a letter addresses its recipient. The wording of each form belongs to the language of the letter.
public enum FormOfAddress: Hashable, Sendable {
    case ms, mr, neutral
}

/// Who a letter is for. The company has no default; the rest is empty unless the advert or the user gave it.
public struct LetterRecipient: Hashable, Sendable {
    public let company: String
    public let contactName: String
    public let form: FormOfAddress?
    public let title: String
    public let surname: String
    public let role: String
    public let address: [String]

    /// An address has at most `TailoringLimits.maxAddressLines` lines (R8).
    public init(company: String, contactName: String = "", form: FormOfAddress? = nil, title: String = "", surname: String = "",
                role: String = "", address: [String] = []) throws(TailoringModelError) {
        try Bounds.text(company, .company)
        try Bounds.text(contactName, .contactName)
        try Bounds.text(title, .title)
        try Bounds.text(surname, .surname)
        try Bounds.text(role, .role)
        try Bounds.texts(address, .addressLine, atMost: TailoringLimits.maxAddressLines, .addressLines)
        self.company = company
        self.contactName = contactName
        self.form = form
        self.title = title
        self.surname = surname
        self.role = role
        self.address = address
    }
}

/// The cover letter a tailoring produces (ADR 0013). It checks sizes only; what the letter says is for the provenance
/// gate, so a letter that fails it must still be a value.
public struct CoverLetter: Hashable, Sendable {
    public let recipient: LetterRecipient
    public let reference: String
    public let position: String
    public let subject: String
    public let opening: String
    public let body: [String]
    public let closing: String
    public let attachments: [String]

    /// The body has at most `TailoringLimits.maxParagraphs` paragraphs and the attachments at most
    /// `TailoringLimits.maxAttachments` (R8).
    public init(recipient: LetterRecipient, reference: String, position: String, subject: String, opening: String, body: [String],
                closing: String, attachments: [String]) throws(TailoringModelError) {
        try Bounds.text(reference, .reference)
        try Bounds.text(position, .position)
        try Bounds.text(subject, .subject)
        try Bounds.text(opening, .opening)
        try Bounds.texts(body, .paragraph, atMost: TailoringLimits.maxParagraphs, .paragraphs)
        try Bounds.text(closing, .closing)
        try Bounds.texts(attachments, .attachment, atMost: TailoringLimits.maxAttachments, .attachments)
        self.recipient = recipient
        self.reference = reference
        self.position = position
        self.subject = subject
        self.opening = opening
        self.body = body
        self.closing = closing
        self.attachments = attachments
    }
}

/// What the user wants every letter to say, as the user wrote it. A letter never states one the user did not give.
public struct LetterDefaults: Hashable, Sendable {
    public let salaryExpectation: String?
    public let startDate: String?
    public let note: String?

    public init(salaryExpectation: String? = nil, startDate: String? = nil, note: String? = nil) throws(TailoringModelError) {
        try Bounds.optionalText(salaryExpectation, .salaryExpectation)
        try Bounds.optionalText(startDate, .startDate)
        try Bounds.optionalText(note, .note)
        self.salaryExpectation = salaryExpectation
        self.startDate = startDate
        self.note = note
    }
}
