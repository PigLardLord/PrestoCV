import Foundation

/// A language the exported PDF can be written in: the languages the template headings are available in
public enum DocumentLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case italian = "it"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case portuguese = "pt"

    public var id: String { rawValue }

    /// The name of the language in that language, as language pickers show it
    public var nativeName: String {
        switch self {
        case .english: return "English"
        case .italian: return "Italiano"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .french: return "Français"
        case .portuguese: return "Português"
        }
    }

    /// The supported language of a BCP 47 tag, whatever its region (`pt-BR` is Portuguese)
    public init?(languageTag tag: String) {
        guard let code = Locale(identifier: tag).language.languageCode?.identifier else { return nil }
        self.init(rawValue: code)
    }

    /// The language a document is written in.
    /// - Parameters:
    ///   - tag: The language chosen for the CV. A blank tag, or a language the templates have no headings
    ///     for, counts as no choice.
    ///   - preferredLanguages: The languages of the user, most wanted first. With no choice for the CV, the
    ///     first of them that is supported is used, and English when none is.
    public static func resolve(_ tag: String?, preferredLanguages: [String]) -> DocumentLanguage {
        if let tag, let chosen = DocumentLanguage(languageTag: tag) {
            return chosen
        }
        return preferredLanguages.lazy.compactMap { DocumentLanguage(languageTag: $0) }.first ?? .english
    }
}
