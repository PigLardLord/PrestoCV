import Testing
@testable import CVGeneratorAI

/// The latest job is read one way wherever the draft takes it: the year of the end date, whatever else the date says; a job that goes
/// on now is the latest of all; the year of the start settles a tie. All names and dates are invented.
@Suite("The latest job of a draft")
struct JobRecencyTests {
    @Test("The jobs are read latest first: the current ones, then by end and start, the earlier in the draft first on a tie")
    func latestFirst() {
        let jobs = [
            Experience(title: "a", startDate: "2013", endDate: "2016"), Experience(title: "b", startDate: "2016", endDate: "2019"),
            Experience(title: "c", startDate: "2021", current: true), Experience(title: "d", startDate: "2016", endDate: "2019"),
        ]
        #expect(JobRecency.latestFirst(jobs) == [2, 1, 3, 0])
    }

    @Test("The jobs are read latest first by the year of the end, whatever else the date says: a month, a name of a month, a bare year")
    func latestFirstByTheYearOfTheEnd() {
        let mixed = [
            Experience(title: "a", startDate: "March 2012", endDate: "March 2015"),
            Experience(title: "b", startDate: "2016", endDate: "2018"),
        ]
        let italian = [
            Experience(title: "a", startDate: "settembre 2013", endDate: "marzo 2016"),
            Experience(title: "b", startDate: "gennaio 2016", endDate: "gennaio 2018"),
        ]
        let sameYear = [
            Experience(title: "a", startDate: "March 2010", endDate: "2015"),
            Experience(title: "b", startDate: "2012", endDate: "June 2015"),
        ]
        let current = [
            Experience(title: "a", startDate: "2010", endDate: "2019"), Experience(title: "b", startDate: "March 2012", current: true),
        ]
        let noEnd = [
            Experience(title: "a", startDate: "2010", endDate: "2019"), Experience(title: "b", startDate: "March 2012"),
        ]

        #expect(JobRecency.latestFirst(mixed) == [1, 0], "2018 is later than March 2015")
        #expect(JobRecency.latestFirst(italian) == [1, 0], "gennaio 2018 is later than marzo 2016")
        #expect(JobRecency.latestFirst(sameYear) == [1, 0], "The start year decides a tie of the end year")
        #expect(JobRecency.latestFirst(current) == [1, 0], "A current job is the latest of all")
        #expect(JobRecency.latestFirst(noEnd) == [1, 0], "A job with no end date goes on")
    }

    struct YearRow: Sendable, CustomTestStringConvertible {
        let date: String?
        let year: Int?
        var testDescription: String { date ?? "nil" }
    }

    static let years: [YearRow] = [
        YearRow(date: "2018", year: 2018), YearRow(date: "March 2015", year: 2015), YearRow(date: "gennaio 2018", year: 2018),
        YearRow(date: "12/03/2016", year: 2016), YearRow(date: "2012-2019", year: 2019), YearRow(date: "'99", year: nil),
        YearRow(date: "recently", year: nil), YearRow(date: nil, year: nil),
    ]

    @Test("The year of a date is its latest run of four digits", arguments: years)
    func year(row: YearRow) {
        #expect(JobRecency.year(in: row.date) == row.year)
    }
}
