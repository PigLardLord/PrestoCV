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

/// A line of dates alone goes to the neighbour that has no dates of its own, whichever way the section begins (#461).
/// The direction of the section only decides when both neighbours are alike.
@Suite("A period on its own line goes to the entry that lacks one")
struct PeriodOwnershipTests {

    struct Sample: Sendable, CustomTestStringConvertible {
        let language: String
        let heading: String
        let bachelor: String
        let master: String
        let certification: String
        let datedCertification: String
        var testDescription: String { language }
    }

    static let samples = [
        Sample(
            language: "en", heading: "Education & Certifications", bachelor: "BSc Physics — University of Leipzig",
            master: "MSc Physics — University of Leipzig", certification: "Certified Scrum Master — Scrum Alliance",
            datedCertification: "Certified Scrum Master — Scrum Alliance, 2021"),
        Sample(
            language: "de", heading: "Ausbildung & Zertifizierungen", bachelor: "BSc Physik — Universität Leipzig",
            master: "MSc Physik — Universität Leipzig", certification: "Zertifizierter Scrum Master — Scrum Alliance",
            datedCertification: "Zertifizierter Scrum Master — Scrum Alliance, 2021"),
        Sample(
            language: "it", heading: "Istruzione e certificazioni", bachelor: "Laurea in Fisica — Università di Pisa",
            master: "Laurea Magistrale in Fisica — Università di Pisa", certification: "Certificazione Scrum Master — Scrum Alliance",
            datedCertification: "Certificazione Scrum Master — Scrum Alliance, 2021"),
    ]

    private func importText(_ sample: Sample, _ body: String) throws -> ImportResult {
        let text = "Tobias Renn\ntobias.renn@example.com\n\n\(sample.heading)\n\(body)"
        return try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func range(_ start: Int, _ end: Int) -> ImportedPeriod {
        ImportedPeriod(start: YearMonth(year: start, month: nil), end: .date(YearMonth(year: end, month: nil)))
    }

    private func expectNothingLost(_ found: ImportResult) {
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("Dates first, then two studies and a dated certification: each keeps its period", arguments: PeriodOwnershipTests.samples)
    func theReviewInput(sample: Sample) throws {
        let body = "2010–2014\n\(sample.bachelor)\n\(sample.master)\n2015–2017\n\(sample.datedCertification)"
        let found = try importText(sample, body)

        #expect(found.cv.education.map { $0.period?.value } == [range(2010, 2014), range(2015, 2017)])
        #expect(found.cv.education.compactMap { $0.degree?.value }.count == 2, "a study with no name was made")
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("Dates first, a trailing period with nothing below goes to the certification above", arguments: PeriodOwnershipTests.samples)
    func trailingPeriodOfACertification(sample: Sample) throws {
        let found = try importText(sample, "2010–2014\n\(sample.bachelor)\n\(sample.certification)\n2019–2021")

        #expect(found.cv.education.map { $0.period?.value } == [range(2010, 2014)])
        #expect(found.cv.education.compactMap { $0.degree?.value }.count == 1, "a study with no name was made")
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("Dates first, a trailing period goes to the study above it", arguments: PeriodOwnershipTests.samples)
    func trailingPeriodOfAStudy(sample: Sample) throws {
        let found = try importText(sample, "2010–2014\n\(sample.bachelor)\n\(sample.master)\n2015–2017")

        #expect(found.cv.education.map { $0.period?.value } == [range(2010, 2014), range(2015, 2017)])
        #expect(found.cv.education.compactMap { $0.degree?.value }.count == 2, "a study with no name was made")
        expectNothingLost(found)
    }

    @Test("Dates first with a date line over each entry stays as it was", arguments: PeriodOwnershipTests.samples)
    func everyEntryHasItsDatesAbove(sample: Sample) throws {
        let body = "2010–2014\n\(sample.bachelor)\n2015–2017\n\(sample.master)\n2019–2021\n\(sample.certification)"
        let found = try importText(sample, body)

        #expect(found.cv.education.map { $0.period?.value } == [range(2010, 2014), range(2015, 2017)])
        #expect(found.cv.education.compactMap { $0.degree?.value }.count == 2)
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("Dates after with a date line under each entry stays as it was", arguments: PeriodOwnershipTests.samples)
    func everyEntryHasItsDatesBelow(sample: Sample) throws {
        let body = "\(sample.bachelor)\n2010–2014\n\(sample.master)\n2015–2017\n\(sample.certification)\n2019–2021"
        let found = try importText(sample, body)

        #expect(found.cv.education.map { $0.period?.value } == [range(2010, 2014), range(2015, 2017)])
        #expect(found.cv.education.compactMap { $0.degree?.value }.count == 2)
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("A period between a dated certification above and a study below goes to the study", arguments: PeriodOwnershipTests.samples)
    func periodBetweenADatedEntryAndABareOne(sample: Sample) throws {
        let body = "\(sample.datedCertification)\n2015–2017\n\(sample.master)"
        let found = try importText(sample, body)

        #expect(found.cv.education.map { $0.period?.value } == [range(2015, 2017)])
        #expect(found.cv.education.compactMap { $0.degree?.value }.count == 1)
        #expect(found.cv.certifications.map { $0.year?.value } == [2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("Dates first with two certifications: a trailing period goes to the one above it", arguments: PeriodOwnershipTests.samples)
    func trailingPeriodOfTheSecondCertification(sample: Sample) throws {
        let other = sample.certification.replacingFirst("Scrum Master", with: "Product Owner")
        let found = try importText(sample, "2018\n\(sample.certification)\n\(other)\n2021")

        #expect(found.cv.education.isEmpty)
        #expect(found.cv.certifications.map { $0.year?.value } == [2018, 2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("Dates first, a period between two certifications goes to the one that has none", arguments: PeriodOwnershipTests.samples)
    func interiorPeriodOfACertification(sample: Sample) throws {
        let owner = sample.certification.replacingFirst("Scrum Master", with: "Product Owner")
        let third = sample.certification.replacingFirst("Scrum Master", with: "Cloud Practitioner")
            .replacingFirst("Scrum Alliance", with: "Meridian Board")
        let found = try importText(sample, "2018\n\(sample.certification)\n\(owner)\n2019–2020\n\(third), 2021")

        #expect(found.cv.education.isEmpty, "a study with no name was made")
        #expect(found.cv.certifications.map(\.name.value).count == 3)
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Scrum Alliance", "Scrum Alliance", "Meridian Board"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2018, 2020, 2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("Dates after, a period between a dated certification and a bare one goes to the bare one", arguments: PeriodOwnershipTests.samples)
    func interiorPeriodOfTheCertificationBelow(sample: Sample) throws {
        let owner = sample.certification.replacingFirst("Scrum Master", with: "Product Owner")
        let third = sample.certification.replacingFirst("Scrum Master", with: "Cloud Practitioner")
            .replacingFirst("Scrum Alliance", with: "Meridian Board")
        let found = try importText(sample, "\(sample.datedCertification.replacingFirst("2021", with: "2018"))\n2019–2020\n\(owner)\n\(third), 2021")

        #expect(found.cv.education.isEmpty, "a study with no name was made")
        #expect(found.cv.certifications.map(\.name.value).count == 3)
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Scrum Alliance", "Scrum Alliance", "Meridian Board"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2018, 2020, 2021])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        expectNothingLost(found)
    }

    @Test("A period between two entries without dates follows the direction of the section", arguments: PeriodOwnershipTests.samples)
    func periodBetweenTwoBareEntries(sample: Sample) throws {
        let after = try importText(sample, "\(sample.certification)\n2019–2021\n\(sample.bachelor)\n2010–2014")
        #expect(after.cv.certifications.map { $0.year?.value } == [2021])
        #expect(after.cv.education.map { $0.period?.value } == [range(2010, 2014)])
        expectNothingLost(after)

        let first = try importText(sample, "2019–2021\n\(sample.certification)\n2010–2014\n\(sample.bachelor)")
        #expect(first.cv.certifications.map { $0.year?.value } == [2021])
        #expect(first.cv.education.map { $0.period?.value } == [range(2010, 2014)])
        expectNothingLost(first)
    }
}

private extension String {
    func replacingFirst(_ target: String, with other: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return replacingCharacters(in: range, with: other)
    }
}
