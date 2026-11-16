import Testing
import Foundation
@testable import PrestoCV
import PrestoCVCore
import PrestoCVImporting

/// A PDF reader for the app's tests: it hands over the layout it was given, or throws.
struct ScriptedPDFReader: PDFTextExtracting {
    var layout: ExtractedLayout = .pages([])
    var error: (any Error & Sendable)?

    func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout {
        if let error { throw error }
        return layout
    }
}

/// The import of a pasted text, through the real core.
func importedText(_ text: String) throws -> ImportResult {
    try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
}

@Suite("ImportedCVMapper - the imported CV as the editor opens it")
struct ImportedCVMapperTests {

    private let text = """
    # Lena Hartmann
    **Elektrikerin**
    Leipzig, Deutschland · lena.hartmann@example.com · +49 170 0000101 · linkedin.com/in/lena-example · https://lena.example.com

    ## Profil
    Elektrikerin mit zehn Jahren Erfahrung in der Gebäudetechnik.

    ## Berufserfahrung
    **Projektleiterin** | Beispiel GmbH | Leipzig | 03/2019 – heute
    - Planung von Elektroinstallationen
    - Leitung eines Teams von fünf Monteuren

    ## Ausbildung
    2012 – 2015: Ausbildung zur Elektronikerin, Berufsschule Leipzig

    ## Kenntnisse
    KNX, AutoCAD

    ## Sprachen
    - Deutsch: Muttersprache
    - Englisch: verhandlungssicher

    ## Zertifikate
    - Elektrofachkraft – TÜV Beispiel (2020)

    ## Hobbys
    Klettern, Fotografie

    ## Ehrenamt
    Trainerin im Kletterverein
    """

    @Test("Every value of the import reaches the CV, in the person's own words")
    func everyValueReachesTheCV() throws {
        let draft = ImportedCVMapper().map(try importedText(text))
        let cv = draft.cv

        #expect(cv.name.isEmpty, "The list calls the CV by its person until it is renamed")
        #expect(cv.personalInfo.name == "Lena Hartmann")
        #expect(cv.personalInfo.title == "Elektrikerin")
        #expect(cv.personalInfo.location == "Leipzig, Deutschland")
        #expect(cv.personalInfo.email == "lena.hartmann@example.com")
        #expect(cv.personalInfo.phone == "+49 170 0000101")
        #expect(cv.personalInfo.portfolio == "https://lena.example.com")
        #expect(cv.personalInfo.profile == "Elektrikerin mit zehn Jahren Erfahrung in der Gebäudetechnik.")
        #expect(cv.social.map(\.platform) == ["LinkedIn"])
        #expect(cv.social.map(\.url) == ["https://linkedin.com/in/lena-example"])

        let job = try #require(cv.relevant_experience.first)
        #expect(job.title == "Projektleiterin")
        #expect(job.company == "Beispiel GmbH")
        #expect(job.location == "Leipzig")
        #expect(job.period == "03/2019 – heute", "The period keeps the CV's own words")
        #expect(job.description == "• Planung von Elektroinstallationen\n• Leitung eines Teams von fünf Monteuren")

        #expect(cv.education.map(\.degree) == ["Ausbildung zur Elektronikerin"])
        #expect(cv.education.map(\.school) == ["Berufsschule Leipzig"])
        #expect(cv.education.map(\.period) == ["2012 – 2015"])
        #expect(cv.skills.map(\.name) == ["KNX", "AutoCAD"])
        #expect(cv.skills.allSatisfy { $0.level == 0 }, "No level is invented for a skill")
        #expect(cv.certifications.map(\.name) == ["Elektrofachkraft"])
        #expect(cv.certifications.map(\.issuer) == ["TÜV Beispiel"])
        #expect(cv.certifications.map(\.year) == [2020])
        #expect(cv.interests == ["Klettern", "Fotografie"])
        #expect(cv.documentLanguage == "de")
    }

    @Test("A language without a CEFR level is not added, since the CV needs one: it is listed to check and kept to copy")
    func languageWithoutLevel() throws {
        let draft = ImportedCVMapper().map(try importedText(text))

        #expect(draft.cv.languages.map(\.name) == ["Deutsch"])
        #expect(draft.cv.languages.map(\.level) == [.native])
        #expect(draft.review.items.contains(ImportReview.Item(field: .language, reason: .languageNotAdded, text: "Englisch — verhandlungssicher")))
        #expect(draft.review.notImported.contains("Englisch — verhandlungssicher"))
    }

    @Test("Text that fits no field is kept, ready to copy")
    func textNotImported() throws {
        let draft = ImportedCVMapper().map(try importedText(text))

        #expect(draft.review.notImported.contains("Trainerin im Kletterverein"))
    }

    @Test("Values the rules are unsure of are listed to check, with the entry's number as the editor counts")
    func valuesToCheck() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Experience
        Customer Service Manager | Acme Ltd | 2019 – 2021
        Night Shift | Corner Market Example | 2016 – 2018
        """))

        #expect(draft.review.items == [ImportReview.Item(field: .experience(2), reason: .partsByOrder, text: "Night Shift — Corner Market Example")])
    }

    @Test("Entries whose lines could be read with the date before or after them are listed to check")
    func entryBoundsToCheck() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Experience
        2018 – 2019
        Developer at Acme Ltd
        2020 – 2025
        Cleaner at Verdi Ltd
        2010 – 2020
        """))

        #expect(draft.review.items.map(\.field) == [.experience(1), .experience(2), .experience(3)])
        #expect(draft.review.items.allSatisfy { $0.reason == .entryBounds })
    }

    @Test("A job that may have taken a heading the import does not know is listed to check")
    func headingToCheck() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Lena Okafor
        lena.okafor@example.com
        SUMMARY
        Field technician.
        EXPERIENCE
        2020 – Present
        Technician
        BRACKEN MILLS
        • Serviced pumps.
        2016 – 2020
        Technician — Marlow Studio
        • Serviced boilers.
        SKILLS
        Welding
        """))

        #expect(draft.review.items.filter { $0.reason == .heading }.map(\.field) == [.experience(1)], "\(draft.review.items)")
    }

    @Test("Every reason and field of the review has a text in the string catalog")
    func reviewIsWorded() {
        let items = [
            ImportReview.Item(field: .name, reason: .byPosition, text: ""), ImportReview.Item(field: .title, reason: .partsByOrder, text: ""),
            ImportReview.Item(field: .location, reason: .period, text: ""), ImportReview.Item(field: .summary, reason: .languageNotAdded, text: ""),
            ImportReview.Item(field: .experience(1), reason: .languageLevels, text: ""), ImportReview.Item(field: .education(1), reason: .byPosition, text: ""),
            ImportReview.Item(field: .language, reason: .byPosition, text: ""), ImportReview.Item(field: .experience(2), reason: .entryBounds, text: ""),
            ImportReview.Item(field: .experience(3), reason: .heading, text: ""),
        ]
        for item in items {
            #expect(item.fieldKey.localized != item.fieldKey, "\(item.fieldKey) is missing from the string catalog")
            #expect(item.reasonKey.localized != item.reasonKey, "\(item.reasonKey) is missing from the string catalog")
        }
    }
}
