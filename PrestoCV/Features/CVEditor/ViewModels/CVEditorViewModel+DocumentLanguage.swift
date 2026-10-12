import PrestoCVCore

extension CVEditorViewModel {

    /// The language chosen for the PDF of this CV. Nil is automatic: the PDF follows the language of the app.
    /// A stored language the app has no headings for shows as automatic, which is what the export does with it.
    var documentLanguageSelection: DocumentLanguage? {
        get { cv.documentLanguage.flatMap { DocumentLanguage(languageTag: $0) } }
        set { cv.documentLanguage = newValue?.rawValue }
    }
}
