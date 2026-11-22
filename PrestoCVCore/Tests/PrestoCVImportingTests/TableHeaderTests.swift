import Testing
@testable import PrestoCVImporting

/// A table whose first row names the columns, as chat assistants write experience and education (ADR 0027): the
/// columns are read by the header's words, and the header row and the separator row are markup, never data.
@Suite("Reading a table by its header row")
struct TableHeaderTests {

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func noLoss(_ result: ImportResult) {
        #expect(Coverage.lost(result).isEmpty, "lost \(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("An English table: the header and the separator are markup, the columns are read by their names")
    func english() throws {
        let result = try importText("""
        Experience
        | Period | Employer | Role | Tasks |
        |---|---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant | Supported pupils |
        | 2018 – 2020 | Riverside School | Tutor | Ran workshops |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School"])
        #expect(jobs.map { $0.location?.value } == [nil, nil])
        #expect(jobs.map { $0.details.map(\.value) } == [["Supported pupils"], ["Ran workshops"]])
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018])
        #expect(jobs.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("A German table")
    func german() throws {
        let result = try importText("""
        Berufserfahrung
        | Zeitraum | Unternehmen | Rolle | Aufgaben |
        |---|---|---|---|
        | 2021 – 2023 | Beispiel Werke | Mechatroniker | Wartung von Anlagen |
        | 2018 – 2021 | Muster Technik | Monteur | Montage von Schaltschränken |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Mechatroniker", "Monteur"])
        #expect(jobs.map { $0.employer?.value } == ["Beispiel Werke", "Muster Technik"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Wartung von Anlagen"], ["Montage von Schaltschränken"]])
        #expect(jobs.map { $0.period?.value.start.year } == [2021, 2018])
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("The same table with its columns in another order", arguments: [
        """
        Experience
        | Role | Period | Employer | Tasks |
        |---|---|---|---|
        | Teaching Assistant | 2020 – 2022 | Northgate Academy | Supported pupils |
        | Tutor | 2018 – 2020 | Riverside School | Ran workshops |
        """,
        """
        Experience
        | Tasks | Employer | Role | Period |
        |---|---|---|---|
        | Supported pupils | Northgate Academy | Teaching Assistant | 2020 – 2022 |
        | Ran workshops | Riverside School | Tutor | 2018 – 2020 |
        """,
    ])
    func otherOrder(_ text: String) throws {
        let result = try importText(text)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Supported pupils"], ["Ran workshops"]])
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018])
        noLoss(result)
    }

    @Test("An education table: school, degree and period")
    func education() throws {
        let result = try importText("""
        Education
        | School | Degree | Period |
        |---|---|---|
        | Example University | BSc Biology | 2014 – 2017 |
        | Sample College | Diploma in Nursing | 2011 – 2014 |
        """)
        let studies = result.cv.education
        #expect(studies.map { $0.school?.value } == ["Example University", "Sample College"])
        #expect(studies.map { $0.degree?.value } == ["BSc Biology", "Diploma in Nursing"])
        #expect(studies.map { $0.period?.value.start.year } == [2014, 2011])
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("A table whose header has no known word keeps today's reading, flags its entries and loses nothing")
    func unknownHeader() throws {
        let result = try importText("""
        Experience
        | Alpha | Beta | Gamma |
        |---|---|---|
        | Teaching Assistant | Northgate Academy | 2020 – 2022 |
        | Tutor | Riverside School | 2018 – 2020 |
        """)
        #expect(!result.cv.experience.isEmpty)
        #expect(result.cv.experience.allSatisfy { $0.check != nil })
        noLoss(result)
    }
}
