import PrestoCVCore

extension CVEditorViewModel {

    /// The language chosen for the PDF of this CV. Nil is automatic: the language the CV is written in, or the app's.
    /// A stored language the app has no headings for shows as automatic, which is what the export does with it.
    var documentLanguageSelection: DocumentLanguage? {
        get { cv.chosenDocumentLanguage }
        set { cv.documentLanguage = newValue?.rawValue }
    }

    /// The automatic choice with the language it stands for with the CV as it is now: "Automatic (English)"
    var automaticDocumentLanguageTitle: String {
        documentLanguageDetector.automaticLanguage(for: cv).automaticTitle
    }

    /// What the row of the document language shows: the language chosen, or what automatic stands for
    var documentLanguageTitle: String {
        documentLanguageSelection?.nativeName ?? automaticDocumentLanguageTitle
    }
}
