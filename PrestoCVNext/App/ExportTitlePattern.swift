import SwiftUI
import PrestoCVPresentation

/// The title of a CV's PDF in a language, with "%@" where the CV's title goes: read from the catalog in that language,
/// not in the language the app shows, since the file goes out with the document (R13).
enum ExportTitlePattern {
    static func pattern(in language: ExportLanguage) -> String { pattern(inLanguageTagged: language.tag) }

    /// The pattern in the language with this tag.
    static func pattern(inLanguageTagged tag: String) -> String {
        var resource = LocalizedStringResource("export.file_name")
        resource.locale = Locale(identifier: tag)
        return String(localized: resource)
    }
}
