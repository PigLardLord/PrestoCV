import SwiftUI

/// The name of a language in the language the app shows: how a language is worded belongs to the app's edge, not to the
/// presentation layer, which gives only its tag (R13).
enum LanguageName {
    /// The name as it stands inside a sentence, "inglese" in "Titoli in inglese"; the tag in capitals when the locale
    /// has no name for it.
    static func inSentence(_ tag: String, in locale: Locale) -> String {
        locale.localizedString(forLanguageCode: tag) ?? tag.uppercased()
    }

    /// The name as it stands alone, in a list: its first letter in capitals, "Inglese".
    static func alone(_ tag: String, in locale: Locale) -> String {
        let name = inSentence(tag, in: locale)
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// The name of the language the app shows, in itself, as it stands inside a sentence: "italiano" in Italian
    static func appLanguage(in locale: Locale) -> String {
        inSentence(locale.language.languageCode?.identifier ?? "", in: locale)
    }
}
