internal import PrestoCVDomain

/// A language a PDF can be written in, as a BCP 47 tag ("it", "pt-BR"): a code, which the view names (R13).
public struct ExportLanguage: Hashable, Sendable {
    let language: DocumentLanguage

    /// The tag, in canonical case.
    public var tag: String { language.tag }

    /// Nil when `tag` is no language tag.
    public init?(_ tag: String) {
        guard let language = DocumentLanguage(tag) else { return nil }
        self.language = language
    }

    init(language: DocumentLanguage) { self.language = language }
}
