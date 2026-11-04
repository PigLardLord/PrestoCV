import Foundation
import PrestoCVCore

extension DocumentLanguage {
    /// "Automatic (English)": the automatic choice with the language it stands for, named as the choices next to it are
    var automaticTitle: String {
        String(format: String(localized: "language.automatic"), nativeName)
    }

    /// The name of the language in the language the app is shown in: "inglese" in Italian, "Englisch" in German
    func name(in appLocale: Locale) -> String {
        appLocale.localizedString(forLanguageCode: rawValue) ?? nativeName
    }

    /// The text of a key of the app's string catalog in this language, whatever language the app is shown in
    func localizedString(forKey key: String, in bundle: Bundle) -> String {
        let languageBundle = bundle.path(forResource: rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        return languageBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
