/// Noise the import leaves out on purpose, each piece with its reason, so that nothing goes without a trace
/// (ADR 0027). Text the rules could not place is not noise: it is `UnplacedText`.
public struct LeftOutText: Hashable, Sendable {
    public enum Reason: String, Hashable, Sendable {
        /// Markdown rules and the separators of tables.
        case markup
        /// A chat assistant's opening or closing sentence.
        case chatter
        /// A page number, or "Page 2 of 3".
        case pageNumber
        /// A header or footer that repeats on every page.
        case repeatedOnPages
        /// A duration LinkedIn computes, such as "(2 years 3 months)".
        case computedDuration
        /// The place and date of a signature, and the name under it.
        case signature
        /// The Italian consent to the processing of personal data, and its kind.
        case consent
        /// The title of the document: "Curriculum Vitae", "Lebenslauf".
        case documentTitle
        /// A template's placeholder in brackets, such as "[Your phone number]".
        case placeholder
        /// The label of a group of skills, such as "Tools:", or of a value that follows it, such as a certification's "Credential:".
        case categoryLabel
        /// The explanations a template prints, such as the formato europeo's "[Indicare la madrelingua]".
        case templateText
    }

    public let text: String
    /// Where it is in the canonical text; nil when the normalisation took it out of the text.
    public let span: SourceSpan?
    public let reason: Reason

    public init(text: String, span: SourceSpan?, reason: Reason) {
        self.text = text
        self.span = span
        self.reason = reason
    }
}
