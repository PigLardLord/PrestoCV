import Foundation
import PrestoCVCore
import struct PrestoCVDomain.PDFFileName

/// Names an exported CV in the language of its PDF, by `PDFFileName`: the title stored in the PDF and the name of the
/// file the person shares, "<Full name> – Lebenslauf.pdf" for a CV printed in German, whatever language the app is in.
struct ExportFileName {
    /// The pattern of the title in a language of the PDF, with %@ where the name goes
    private let titlePattern: (DocumentLanguage) -> String

    /// - Parameter titlePattern: The pattern of the title in each language of the PDF: "%@ – CV" in English.
    init(titlePattern: @escaping (DocumentLanguage) -> String) {
        self.titlePattern = titlePattern
    }

    /// "<Full name> – CV", in the language the CV is printed in
    func title(for cv: CVModel) -> String {
        name(for: cv).title(personName: cv.personalInfo.name, cvName: cv.name)
    }

    /// The title with the PDF extension: "<Full name> – CV.pdf"
    func fileName(for cv: CVModel) -> String {
        name(for: cv).fileName(personName: cv.personalInfo.name, cvName: cv.name)
    }

    /// The CV is printed in the language chosen for it, which the export sheet sets; English without one
    private func name(for cv: CVModel) -> PDFFileName {
        PDFFileName(titlePattern: titlePattern(cv.chosenDocumentLanguage ?? .english))
    }
}

/// The pattern of an exported CV's title in each language of the PDF, as the app's string catalog writes it in that
/// language, whatever language the app is shown in.
struct DocumentTitlePatterns {
    /// The bundle that holds the catalog's languages
    let bundle: Bundle

    func pattern(in language: DocumentLanguage) -> String {
        language.localizedString(forKey: "export.file_name", in: bundle)
    }
}
