import Testing
@testable import PrestoCVImporting

/// Two-digit years and an expected end, read through the whole import. Every value here is invented (the corpus README).
@Suite("Short years and an expected end in an import")
struct ShortYearImportTests {

    private func imported(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    @Test("Experience: an entry dated with two-digit years keeps its period, and the next entry stays an entry")
    func experience() throws {
        let found = try imported("""
        Berufserfahrung
        09/19 – 08/21    Buchhalter, Muster GmbH, Berlin
        10/21 – heute    Leiter Buchhaltung, Beispiel AG, Hamburg
        """)
        #expect(found.cv.experience.count == 2)
        #expect(found.cv.experience.allSatisfy { $0.period != nil })
    }

    @Test("Education: an expected end belongs to the period, not to the degree")
    func education() throws {
        let found = try imported("""
        Education
        08/2020 – expected 06/2024  Bachelor of Science, University of Leeds
        """)
        let study = try #require(found.cv.education.first)
        #expect(study.period != nil)
        #expect(study.degree?.value == "Bachelor of Science")
    }
}
