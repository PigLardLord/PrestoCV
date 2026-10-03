/// The job advert a CV is tailored to: its text, as pasted, and its language (ADR 0013).
public struct Advert: Hashable, Sendable {
    public let text: String
    public let language: TailoringLanguage

    /// The text must say something, and holds at most `TailoringLimits.maxAdvertBytes` UTF-8 bytes (R8).
    public init(text: String, language: TailoringLanguage) throws(TailoringModelError) {
        try Bounds.requiredText(text, .advert, maxBytes: TailoringLimits.maxAdvertBytes)
        self.text = text
        self.language = language
    }
}
