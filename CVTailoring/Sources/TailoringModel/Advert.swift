/// The job advert a CV is tailored to: its text, as pasted, and its language (ADR 0013).
public struct Advert: Hashable, Sendable {
    public let text: String
    public let language: TailoringLanguage

    /// The text must say something, and holds at most `TailoringLimits.maxAdvertBytes` UTF-8 bytes (R8).
    public init(text: String, language: TailoringLanguage) throws(TailoringModelError) {
        guard text.contains(where: { !$0.isWhitespace }) else { throw .emptyField(.advert) }
        guard text.utf8.count <= TailoringLimits.maxAdvertBytes else { throw .tooLarge(.advert) }
        self.text = text
        self.language = language
    }
}
