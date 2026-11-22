import Testing
import Foundation
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVImportingTestSupport
import PrestoCVIntegration
import PrestoCVWorkflowPorts

private let mapper = ImportedCVMapper()
private let id = FixedID(9).id

private func marked(_ places: [ValuePlace]) -> [ValuePlace: ValueOrigin] {
    Dictionary(uniqueKeysWithValues: places.map { ($0, ValueOrigin.imported) })
}

@Suite("ADR 0009 · what the import marks and keeps as text not placed")
struct ImportOriginsTests {
    private let full = mapper.map(FullImport.result, id: id)

    @Test("every value the full import writes is marked as imported, and nothing else is")
    func fullImportMarksEveryValueItWrites() {
        let personal: [ValuePlace] = [.personal(.fullName), .personal(.professionalTitle), .personal(.email), .personal(.phone),
                                      .personal(.location), .personal(.website), .personal(.summary)]
        let entries: [(EntryField, [Int])] = [
            (.experienceRole, [0, 1]), (.experienceCompany, [0, 1]), (.experienceLocation, [0]), (.experiencePeriod, [0]),
            (.experienceDescription, [0, 1]),
            (.educationDegree, [0]), (.educationSchool, [0]), (.educationPeriod, [0]), (.educationDescription, [0]),
            (.skillName, [0, 1]), (.languageName, [0, 1]), (.languageProficiency, [0, 1]),
            (.certificationName, [0]), (.certificationIssuer, [0]), (.certificationIssued, [0]), (.certificationLink, [0]),
            (.certificationDescription, [0]),
            (.profilePlatform, [0, 1, 2]), (.profileLink, [0, 1, 2]), (.interest, [0]),
        ]
        let places = personal + entries.flatMap { field, rows in rows.map { ValuePlace.entry(field, index: $0) } }
        #expect(full.cv.draft?.origins == marked(places))
    }

    @Test("a value the CV does not hold has no mark: a language with no level, an entry with no period")
    func noMarkWhereNoValue() {
        let origins = full.cv.draft?.origins ?? [:]
        #expect(origins[.entry(.languageName, index: 2)] == nil)
        #expect(origins[.entry(.experiencePeriod, index: 1)] == nil)
        #expect(origins[.entry(.experienceLocation, index: 1)] == nil)
    }

    @Test("the text the import could not place and the values the CV cannot hold are the not-placed list, in order, with their headings")
    func notPlacedListsUnplacedThenLeftOutValues() {
        let listed = full.cv.draft?.notPlaced.map { [$0.text, $0.heading ?? "-"] }
        #expect(listed == [["Volunteering at the harbour clean-up.", "-"], ["2015 -", "-"], ["Aveiro, Portugal", "Education"],
                           ["Spanish — fluent", "Languages"], ["https://blog.miravaldez.example.org", "Contact"]])
    }

    @Test("the text not imported is the not-placed texts joined, so the two cannot differ")
    func notImportedIsTheJoinedNotPlacedTexts() {
        #expect(full.notImported == (full.cv.draft?.notPlaced ?? []).map(\.text).joined(separator: "\n"))
    }

    @Test("a text the text rule changes reads the same in both: the control character is gone, a blank text is in neither")
    func notImportedFollowsTheTextRule() {
        let f = ImportFixture(text: "Alpha Beta\u{7}Gamma   ")
        var cv = ImportedCV()
        cv.person.name = f.quoted("Alpha")
        let outcome = mapper.map(f.result(cv, unplaced: [f.unplaced("Beta\u{7}Gamma"), f.unplaced("   ")]), id: id)
        #expect(outcome.cv.draft?.notPlaced.map(\.text) == ["BetaGamma"])
        #expect(outcome.notImported == "BetaGamma")
    }

    @Test("an import that reads one value marks that value only, and has no not-placed text")
    func smallestImport() {
        let f = ImportFixture(text: "Alpha")
        var cv = ImportedCV()
        cv.person.name = f.quoted("Alpha")
        let outcome = mapper.map(f.result(cv), id: id)
        #expect(outcome.cv.draft == DraftBlock(origins: marked([.personal(.fullName)]), notPlaced: []))
        #expect(outcome.notImported == "")
    }

    @Test("an entry left out of the CV leaves no mark, and the next entry's marks sit on its own row")
    func marksFollowTheRowsTheCVHolds() {
        let f = ImportFixture(text: "2015 - Beta Co")
        var cv = ImportedCV()
        cv.experience = [
            f.experience(period: f.sourced(ImportedPeriod(start: yearMonth(2015), end: .unstated), quoting: "2015 -", reading: .period)),
            f.experience(role: f.quoted("Beta"), employer: f.quoted("Co")),
        ]
        let outcome = mapper.map(f.result(cv), id: id)
        #expect(outcome.cv.sections.experiences.map(\.role) == ["Beta"])
        #expect(outcome.cv.draft?.origins == marked([.entry(.experienceRole, index: 0), .entry(.experienceCompany, index: 0)]))
    }
}

@Suite("ADR 0009 · a date the CV cannot take keeps the heading it stood under")
struct RejectedPeriodHeadingTests {
    private static let text = "Cook 2015 Nurse 2019 - Baker 2020 - 2018 Dentist Teacher Optician 1850 Welder 2012 Tiler"

    private let f = ImportFixture(text: RejectedPeriodHeadingTests.text)

    private func period(_ piece: String, start: Int, end: ImportedPeriod.End?) -> Sourced<ImportedPeriod> {
        f.sourced(ImportedPeriod(start: yearMonth(start), end: end), quoting: piece, reading: .period)
    }

    private func rejected() -> [Sourced<ImportedPeriod>] {
        [period("2015", start: 2015, end: nil), period("2019 -", start: 2019, end: .unstated),
         period("2020 - 2018", start: 2020, end: .date(yearMonth(2018)))]
    }

    private func notPlaced(_ cv: ImportedCV) -> [[String]] {
        mapper.map(f.result(cv), id: id).cv.draft?.notPlaced.map { [$0.text, $0.heading ?? "-"] } ?? []
    }

    @Test("a single date, an open end and an end before the start of a job keep the heading of its section")
    func experiencePeriodsKeepTheirHeading() {
        var cv = ImportedCV()
        cv.experience = zip(["Cook", "Nurse", "Baker"], rejected()).map {
            f.experience(role: f.quoted($0), period: $1, heading: "Work history")
        }
        #expect(notPlaced(cv) == [["2015", "Work history"], ["2019 -", "Work history"], ["2020 - 2018", "Work history"]])
    }

    @Test("a single date, an open end and an end before the start of a study keep the heading of its section")
    func educationPeriodsKeepTheirHeading() {
        var cv = ImportedCV()
        cv.education = zip(["Cook", "Nurse", "Baker"], rejected()).map {
            f.education(degree: f.quoted($0), period: $1, heading: "Studies")
        }
        #expect(notPlaced(cv) == [["2015", "Studies"], ["2019 -", "Studies"], ["2020 - 2018", "Studies"]])
    }

    @Test("a certification year the CV cannot hold keeps the heading of its section")
    func certificationYearKeepsItsHeading() {
        var cv = ImportedCV()
        cv.certifications = [f.certification(f.quoted("Optician"), year: f.sourced(1850, quoting: "1850", reading: .year), heading: "Credentials")]
        #expect(notPlaced(cv) == [["1850", "Credentials"]])
    }

    @Test("an entry left out of the CV keeps the heading on each date it could not place")
    func leftOutEntriesKeepTheirHeading() {
        var cv = ImportedCV()
        cv.experience = [f.experience(period: period("2015", start: 2015, end: nil), heading: "Work history"),
                         f.experience(period: period("2019 -", start: 2019, end: .unstated), heading: "Work history")]
        cv.education = [f.education(period: period("2020 - 2018", start: 2020, end: .date(yearMonth(2018))), heading: "Studies")]
        let outcome = mapper.map(f.result(cv), id: id)
        #expect(outcome.cv.sections.experiences.isEmpty && outcome.cv.sections.education.isEmpty)
        #expect(notPlaced(cv) == [["2015", "Work history"], ["2019 -", "Work history"], ["2020 - 2018", "Studies"]])
    }
}
