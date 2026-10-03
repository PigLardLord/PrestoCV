/// The languages a CV can be tailored in: a closed set of six (ADR 0013). Any other language is a typed error, never a
/// weaker check that reads as a pass.
public enum TailoringLanguage: String, CaseIterable, Hashable, Sendable {
    case english = "en", german = "de", spanish = "es", french = "fr", italian = "it", portuguese = "pt"

    /// The ISO 639-1 code, which is also the primary language subtag of a BCP 47 tag.
    public var code: String { rawValue }

    /// Reads a BCP 47 tag ("pt-BR") of at most `TailoringLimits.maxLanguageTagBytes`, checked before the tag is split:
    /// every subtag is 1 to 8 ASCII letters or digits, and the primary language subtag, ignoring case, is one of the
    /// six. "pt_BR" is not a BCP 47 tag, and nothing falls back to English (R13).
    public init(bcp47 tag: String) throws(TailoringModelError) {
        guard tag.utf8.count <= TailoringLimits.maxLanguageTagBytes else { throw .unsupportedLanguage }
        let subtags = tag.split(separator: "-", omittingEmptySubsequences: false)
        guard subtags.allSatisfy({ (1...8).contains($0.utf8.count) && $0.unicodeScalars.allSatisfy(Self.isASCIILetterOrDigit) }),
              let primary = subtags.first, let language = Self(rawValue: primary.lowercased()) else { throw .unsupportedLanguage }
        self = language
    }

    private static func isASCIILetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: true
        default: false
        }
    }
}
