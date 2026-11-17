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

    @Test("Text that fits no field is kept by where it stood, and a section the CV has no field for is named")
    func passagesByPlace() throws {
        let review = ImportedCVMapper().map(try importedText(text)).review

        #expect(review.passages == [
            ImportReview.Passage(place: .section("Sprachen"), text: "Englisch — verhandlungssicher", isWholeSection: false),
            ImportReview.Passage(place: .section("Ehrenamt"), text: "Trainerin im Kletterverein", isWholeSection: true),
        ])
        #expect(review.sectionsNotImported == ["Ehrenamt"])
    }

    @Test("A language the CV cannot take stands where the CV wrote it, under its heading, before a later section left out (#452)")
    func languageLeftOutInTheOrderOfTheCV() throws {
        let review = ImportedCVMapper().map(try importedText("""
        # Tobias Renn
        **Mobile Developer**

        ## Languages
        - German: native
        - Italian – fluent

        ## OWN VENTURES
        **Tidepool Notes** | 2021 – today
        - A note app for divers
        """)).review

        #expect(review.passages == [
            ImportReview.Passage(place: .section("Languages"), text: "Italian — fluent", isWholeSection: false),
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today\nA note app for divers", isWholeSection: true),
        ])
        #expect(review.notImported == "Italian — fluent\nTidepool Notes | 2021 – today\nA note app for divers")
    }

    @Test("A section with an unknown heading, a combined heading and the header lines left out are each named to check (#452)")
    func sectionsLeftOutAreNamed() throws {
        let review = ImportedCVMapper().map(try importedText("""
        # Tobias Renn
        **Mobile Developer · Swift and Kotlin**
        Leipzig, Germany · tobias.renn@example.com · +49 170 0000202
        EU citizen · available from March 2026

        ## Experience
        **Senior Developer** | Kestrel Cloud | Hamburg | 08/2019 – today
        - Built the offline sync of the field app

        ## OWN VENTURES
        **Tidepool Notes** | 2021 – today
        - A note app for divers
        **Harbor Timer** | 2018 – 2020
        - A tide timer for sailors

        ## VOLUNTEERING
        2015 – 2017: Rowing coach, Hamburg Rowing Club
        """)).review

        #expect(review.passages == [
            ImportReview.Passage(place: .top, text: "Swift and Kotlin\nEU citizen\navailable from March 2026", isWholeSection: false),
            ImportReview.Passage(
                place: .section("OWN VENTURES"),
                text: "Tidepool Notes | 2021 – today\nA note app for divers\nHarbor Timer | 2018 – 2020\nA tide timer for sailors",
                isWholeSection: true
            ),
            ImportReview.Passage(place: .section("VOLUNTEERING"), text: "2015 – 2017: Rowing coach, Hamburg Rowing Club", isWholeSection: true),
        ])
        #expect(review.sectionsNotImported == ["OWN VENTURES", "VOLUNTEERING"])
    }

    @Test("A review keeps its passages through the file it is kept in")
    func reviewIsKeptWhole() throws {
        let review = ImportReview(
            items: [ImportReview.Item(field: .experience(2), reason: .partsByOrder, text: "Night Shift — Corner Market Example")],
            passages: [
                ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false),
                ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes", isWholeSection: true),
                ImportReview.Passage(place: .elsewhere, text: "Englisch — verhandlungssicher", isWholeSection: false),
            ]
        )

        let kept = try JSONDecoder().decode(ImportReview.self, from: JSONEncoder().encode(review))

        #expect(kept == review)
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

    @Test("A website after the first is kept in the text not imported, at the top where the CV wrote it, never dropped")
    func websiteAfterTheFirst() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Tobias Renn
        tobias.renn@example.com · +49 151 2345 6789
        linkedin.com/in/tobiasrenn · github.com/tobiasrenn · tobiasrenn.dev · tobiasrenn.example.org

        Education
        BSc Computer Science — University of Northbridge
        2014 – 2017
        """))

        #expect(draft.cv.personalInfo.portfolio == "https://tobiasrenn.dev")
        #expect(draft.cv.social.map(\.platform) == ["LinkedIn", "GitHub"])
        #expect(draft.review.passages == [
            ImportReview.Passage(place: .top, text: "https://tobiasrenn.example.org", isWholeSection: false),
        ])
    }

    @Test("A website after the first, in a section of contacts, is kept in the text not imported under that section's heading")
    func websiteInAContactSection() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Tobias Renn
        tobias.renn@example.com · tobiasrenn.dev

        Education
        BSc Computer Science — University of Northbridge
        2014 – 2017

        Contact
        https://blog.tobiasrenn.example.org
        """))

        #expect(draft.cv.personalInfo.portfolio == "https://tobiasrenn.dev")
        #expect(draft.review.passages == [
            ImportReview.Passage(place: .section("Contact"), text: "https://blog.tobiasrenn.example.org", isWholeSection: false),
        ])
    }

    @Test("A study's place has no field in the CV: it is listed to check with the study's number and kept in the text not imported")
    func placeOfAStudy() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Tobias Renn
        tobias.renn@example.com · tobiasrenn.dev

        Education
        MSc Software Engineering — University of Northbridge
        2017 – 2019
        BSc Computer Science — Leipzig Vocational Institute, Leipzig
        2014 – 2017
        """))

        #expect(draft.cv.education.map(\.school) == ["University of Northbridge", "Leipzig Vocational Institute"])
        #expect(draft.review.items == [ImportReview.Item(field: .education(2), reason: .placeNotKept, text: "Leipzig")])
        #expect(draft.review.passages == [ImportReview.Passage(place: .section("Education"), text: "Leipzig", isWholeSection: false)])
    }

    @Test("One website and a study without a place leave nothing to check and nothing in the text not imported")
    func oneWebsiteAndAStudyWithoutAPlace() throws {
        let draft = ImportedCVMapper().map(try importedText("""
        Tobias Renn
        tobias.renn@example.com · tobiasrenn.dev

        Education
        BSc Computer Science — University of Northbridge
        2014 – 2017
        """))

        #expect(draft.cv.personalInfo.portfolio == "https://tobiasrenn.dev")
        #expect(draft.review.items.isEmpty)
        #expect(draft.review.passages.isEmpty)
    }

    @Test("Every reason and field of the review has a text in the string catalog")
    func reviewIsWorded() {
        let items = [
            ImportReview.Item(field: .name, reason: .byPosition, text: ""), ImportReview.Item(field: .title, reason: .partsByOrder, text: ""),
            ImportReview.Item(field: .location, reason: .period, text: ""), ImportReview.Item(field: .summary, reason: .languageNotAdded, text: ""),
            ImportReview.Item(field: .experience(1), reason: .languageLevels, text: ""), ImportReview.Item(field: .education(1), reason: .byPosition, text: ""),
            ImportReview.Item(field: .language, reason: .byPosition, text: ""), ImportReview.Item(field: .experience(2), reason: .entryBounds, text: ""),
            ImportReview.Item(field: .education(2), reason: .placeNotKept, text: ""),
        ]
        for item in items {
            #expect(item.fieldKey.localized != item.fieldKey, "\(item.fieldKey) is missing from the string catalog")
            #expect(item.reasonKey.localized != item.reasonKey, "\(item.reasonKey) is missing from the string catalog")
        }
    }
}
