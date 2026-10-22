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

    @Test("A certification keeps its brackets, and its issuer, year, link and description reach the CV")
    func certificationFields() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Certifications
        Applied Swift Series (Pro, Level Advanced) — Example Academy (2024)
        https://academy.example/achievement
        Covers actors and structured concurrency in depth.
        Includes a capstone project reviewed by a mentor.
        Our Best Practice (Pro, Remote Edition) — Beispiel Institut (2023)
        """))
        let certifications = draft.cv.certifications

        #expect(certifications.map(\.name) == ["Applied Swift Series (Pro, Level Advanced)", "Our Best Practice (Pro, Remote Edition)"])
        #expect(certifications.map(\.issuer) == ["Example Academy", "Beispiel Institut"])
        #expect(certifications.map(\.year) == [2024, 2023])
        #expect(certifications.map(\.url) == ["https://academy.example/achievement", ""])
        #expect(certifications.map(\.description) == [
            "Covers actors and structured concurrency in depth.\nIncludes a capstone project reviewed by a mentor.", "",
        ])
        #expect(draft.review.isEmpty, "Nothing the rules placed is listed again as text not imported, and nothing is to check")
    }

    @Test("A line that may be a detail of the certification above it stands as a certification of its own, listed to check")
    func certificationToCheck() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Certifications
        First Certificate – Example Academy (2023)
        Certificate https://academy.example/c/123
        """))

        #expect(draft.cv.certifications.map(\.name) == ["First Certificate", "Certificate"])
        #expect(draft.cv.certifications.map(\.url) == ["", "https://academy.example/c/123"])
        #expect(draft.review.items == [ImportReview.Item(field: .certification(2), reason: .certificationOrDetail, text: "Certificate")])
        #expect(draft.review.items.first?.fieldKey == "import.review.field.certification")
        #expect(draft.review.items.first?.reasonKey == "import.review.reason.certification")
        #expect(draft.review.notImported.isEmpty)
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

    @Test("Every reason and field of the review has a text in the string catalog")
    func reviewIsWorded() {
        let items = [
            ImportReview.Item(field: .name, reason: .byPosition, text: ""), ImportReview.Item(field: .title, reason: .partsByOrder, text: ""),
            ImportReview.Item(field: .location, reason: .period, text: ""), ImportReview.Item(field: .summary, reason: .languageNotAdded, text: ""),
            ImportReview.Item(field: .experience(1), reason: .languageLevels, text: ""), ImportReview.Item(field: .education(1), reason: .byPosition, text: ""),
            ImportReview.Item(field: .language, reason: .byPosition, text: ""),
        ]
        for item in items {
            #expect(item.fieldKey.localized != item.fieldKey, "\(item.fieldKey) is missing from the string catalog")
            #expect(item.reasonKey.localized != item.reasonKey, "\(item.reasonKey) is missing from the string catalog")
        }
    }
}
