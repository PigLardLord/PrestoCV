import CVDesignCatalog

/// The cover letter's classes (ADR 0019): the closed set the builder emits and the only ones its built-in stylesheet may name.
/// None is in the markup contract's table of what a design may select, so a design's CSS cannot select any of them.
enum LetterClass: String, CaseIterable {
    case letter
    case sender = "letter-sender", senderName = "letter-sender-name", senderTitle = "letter-sender-title", senderEmail = "letter-sender-email"
    case senderPhone = "letter-sender-phone", senderLocation = "letter-sender-location", senderWebsite = "letter-sender-website"
    case recipient = "letter-recipient", recipientName = "letter-recipient-name", recipientTitle = "letter-recipient-title"
    case recipientCompany = "letter-recipient-company"
    case recipientAddress = "letter-recipient-address"
    case dateline = "letter-dateline"
    case reference = "letter-reference", referenceLabel = "letter-reference-label", referenceValue = "letter-reference-value"
    case subject = "letter-subject", salutation = "letter-salutation", paragraph = "letter-paragraph", closing = "letter-closing"
    case valediction = "letter-valediction", signature = "letter-signature"
    case attachments = "letter-attachments", attachmentsTitle = "letter-attachments-title", attachment = "letter-attachment"
}

/// The structure of the cover letter, specified in markup-contract.md beside the CV's. The selectors are all the CSS policy
/// needs to know about it.
enum LetterMarkup {
    static let elements: Set<String> = ["main", "header", "section", "h1", "h2", "p", "span", "a"]
    static let classes = Set(LetterClass.allCases.map(\.rawValue))
    /// No attribute selectors and no pseudo-classes: the letter's stylesheet styles by element and class alone.
    static let vocabulary = SelectorVocabulary(name: "the cover letter's structure", elements: elements, classes: classes, sectionKinds: [], ratings: [], pseudoClasses: [])
}
