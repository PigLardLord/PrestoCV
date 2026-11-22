import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// A period that stands alone on the line below (or above) an entry of a section that holds studies and certifications
/// belongs to that entry, whatever kind the entry is, and never makes a study of its own (#461). Every value here is
/// invented (the corpus README).
@Suite("A period on its own line beside a certification")
struct PeriodLineTests {

    private static let headings = ["Education & Certifications", "EDUCATION & TRAINING"]

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func ym(_ year: Int) -> YearMonth { YearMonth(year: year, month: nil) }

    private func cv(heading: String, body: String) -> String {
        """
        Tobias Renn
        tobias.renn@example.com

        \(heading)
        \(body)
        """
    }

    // MARK: Dates after the entry

    @Test("The period under a certification is its year, and no study of its own is made", arguments: PeriodLineTests.headings)
    func periodUnderACertification(heading: String) throws {
        let found = try importText(cv(heading: heading, body: "Certified Scrum Master — Scrum Alliance\n2019 – 2021"))

        #expect(found.cv.education.map { $0.period?.value } == [], "a study with no name or school was made")
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Master"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Scrum Alliance"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    static let linesOfNoKind: [(name: String, period: String)] = [
        ("Certified Nursing Assistant Diploma — University of Northbridge", "2020 – 2022"),
        ("Certified Nursing Assistant Diploma, University of Northbridge", "2020–2022"),
    ]

    @Test(
        "A line of no kind the reading can tell keeps its period: both stay in the text not imported",
        arguments: PeriodLineTests.headings, PeriodLineTests.linesOfNoKind
    )
    func periodUnderALineOfNoKind(heading: String, line: (name: String, period: String)) throws {
        let found = try importText(cv(heading: heading, body: "\(line.name)\n\(line.period)"))

        #expect(found.cv.education.map { $0.period?.value } == [], "a study with no name or school was made")
        #expect(found.cv.certifications.map(\.name.value) == [])
        let kept = found.unplaced.map(\.text).joined(separator: "\n")
        #expect(kept.contains(line.name), "\(found.unplaced.map(\.text))")
        #expect(kept.contains(line.period), "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A degree under a heading of the studies keeps the period below it")
    func periodUnderADegreeOfAStudy() throws {
        let found = try importText(cv(heading: "EDUCATION & TRAINING", body: "MBA Certificate — Meridian Board\n2019 – 2021"))

        #expect(found.cv.education.count == 1)
        #expect(found.cv.education.map { $0.degree?.value } == ["MBA Certificate"])
        #expect(found.cv.education.map { $0.period?.value } == [ImportedPeriod(start: ym(2019), end: .date(ym(2021)))])
        #expect(found.cv.certifications.isEmpty)
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
    }

    @Test("A degree of no kind under a heading that joins both keeps the period below it in the text not imported")
    func periodUnderADegreeOfNoKind() throws {
        let found = try importText(cv(heading: "Education & Certifications", body: "MBA Certificate — Meridian Board\n2019 – 2021"))

        #expect(found.cv.education.map { $0.period?.value } == [], "a study with no name or school was made")
        #expect(found.cv.certifications.isEmpty)
        let kept = found.unplaced.map(\.text).joined(separator: "\n")
        #expect(kept.contains("MBA Certificate — Meridian Board"), "\(found.unplaced.map(\.text))")
        #expect(kept.contains("2019 – 2021"), "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("Each entry keeps the period below it, a study before a certification", arguments: PeriodLineTests.headings)
    func studyThenCertification(heading: String) throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            Certified Scrum Master — Scrum Alliance
            2019 – 2021
            """
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.education.map { $0.period?.value } == [ImportedPeriod(start: ym(2010), end: .date(ym(2014)))])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Master"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("Each entry keeps the period below it, a certification before a study", arguments: PeriodLineTests.headings)
    func certificationThenStudy(heading: String) throws {
        let body = """
            Certified Scrum Master — Scrum Alliance
            2019 – 2021
            BSc Computer Science — University of Leipzig
            2010 – 2014
            """
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.education.map { $0.period?.value } == [ImportedPeriod(start: ym(2010), end: .date(ym(2014)))])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Master"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    // MARK: Dates before the entry

    @Test("A CV that puts the dates first keeps each period with the entry below it", arguments: PeriodLineTests.headings)
    func datesFirstAfterAYear(heading: String) throws {
        let body = """
            2019
            Certified Scrum Master — Scrum Alliance
            2010 – 2014
            BSc Computer Science — University of Leipzig
            """
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.education.map { $0.period?.value } == [ImportedPeriod(start: ym(2010), end: .date(ym(2014)))])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Master"])
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A CV that puts the dates first and starts with a period gives it to the certification below", arguments: PeriodLineTests.headings)
    func datesFirstStartingWithAPeriod(heading: String) throws {
        let body = """
            2019 – 2021
            Certified Scrum Master — Scrum Alliance
            2010 – 2014
            BSc Computer Science — University of Leipzig
            """
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.education.map { $0.period?.value } == [ImportedPeriod(start: ym(2010), end: .date(ym(2014)))])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Master"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    // MARK: A period the certification cannot take

    @Test("A period under a certification that has its year already stays in the text not imported", arguments: PeriodLineTests.headings)
    func periodUnderADatedCertification(heading: String) throws {
        let found = try importText(cv(heading: heading, body: "Certified Scrum Master — Scrum Alliance, 2019\n2020 – 2022"))

        #expect(found.cv.education.isEmpty)
        #expect(found.cv.certifications.map { $0.year?.value } == [2019])
        #expect(found.unplaced.map(\.text) == ["2020 – 2022"])
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A period above a certification that has its year already stays in the text not imported", arguments: PeriodLineTests.headings)
    func periodAboveADatedCertification(heading: String) throws {
        let body = "2020 – 2022\nCertified Scrum Master — Scrum Alliance, 2019\n2010 – 2014\nBSc Computer Science — University of Leipzig"
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2019])
        #expect(found.unplaced.map(\.text) == ["2020 – 2022"])
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }
}
