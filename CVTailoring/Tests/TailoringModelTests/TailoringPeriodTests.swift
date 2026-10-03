import Testing
import TailoringModel

@Suite("ADR 0013 / R6 · dates and periods")
struct TailoringPeriodTests {
    static let validYears: [Int] = {
        var years: [Int] = []
        years.append(contentsOf: [1900, 1999, 2020, 2200])
        return years
    }()

    @Test("a year from 1900 to 2200 is a date, with or without a month", arguments: validYears)
    func years(year: Int) throws {
        #expect(try TailoringDate(year: year).month == nil)
        #expect(try TailoringDate(year: year, month: 6).year == year)
    }

    static let invalidYears: [Int] = {
        var years: [Int] = []
        years.append(contentsOf: [Int.min, -1, 0, 1899, 2201, Int.max])
        return years
    }()

    @Test("a year outside 1900 to 2200 is an invalid date", arguments: invalidYears)
    func yearsOutOfRange(year: Int) {
        #expect(throws: TailoringModelError.invalidDate) { try TailoringDate(year: year) }
    }

    @Test("a month from 1 to 12 is a date", arguments: 1...12)
    func months(month: Int) throws {
        #expect(try TailoringDate(year: 2020, month: month).month == month)
    }

    static let invalidMonths: [Int] = {
        var months: [Int] = []
        months.append(contentsOf: [Int.min, -1, 0, 13, 100, Int.max])
        return months
    }()

    @Test("a month outside 1 to 12 is an invalid date", arguments: invalidMonths)
    func monthsOutOfRange(month: Int) {
        #expect(throws: TailoringModelError.invalidDate) { try TailoringDate(year: 2020, month: month) }
    }

    private func date(_ year: Int, _ month: Int? = nil) throws -> TailoringDate { try TailoringDate(year: year, month: month) }

    @Test("a period ends when it is current, unknown, or on a date that is not before its start")
    func validPeriods() throws {
        let start = try date(2020, 5)
        #expect(try TailoringPeriod(start: start, end: .current).end == .current)
        #expect(try TailoringPeriod(start: start, end: .unknown).end == .unknown)
        #expect(try TailoringPeriod(start: start, end: .date(try date(2021, 1))).start == start)
        #expect(try TailoringPeriod(start: start, end: .date(try date(2020, 5))).end == .date(try date(2020, 5)))
        #expect(try TailoringPeriod(start: start, end: .date(try date(2020, 6))).start == start)
    }

    static let endsBeforeStart: [(Int, Int, Int, Int)] = {
        var cases: [(Int, Int, Int, Int)] = []
        cases.append((2020, 5, 2019, 12))
        cases.append((2020, 5, 2020, 4))
        cases.append((2020, 12, 2020, 1))
        cases.append((2021, 1, 2020, 12))
        return cases
    }()

    @Test("an end date before the start is an invalid period", arguments: endsBeforeStart)
    func endBeforeStart(startYear: Int, startMonth: Int, endYear: Int, endMonth: Int) throws {
        let start = try date(startYear, startMonth), end = try date(endYear, endMonth)
        #expect(throws: TailoringModelError.invalidPeriod) { try TailoringPeriod(start: start, end: .date(end)) }
    }

    @Test("an end year before the start year is an invalid period, whatever the months")
    func endYearBefore() throws {
        #expect(throws: TailoringModelError.invalidPeriod) { try TailoringPeriod(start: try date(2020), end: .date(try date(2019))) }
        #expect(throws: TailoringModelError.invalidPeriod) { try TailoringPeriod(start: try date(2020, 1), end: .date(try date(2019))) }
        #expect(throws: TailoringModelError.invalidPeriod) { try TailoringPeriod(start: try date(2020), end: .date(try date(2019, 12))) }
    }

    @Test("months are compared only when both are known")
    func partialDates() throws {
        // "May 2020 to 2020" and "2020 to January 2020" are ordered: the missing month proves nothing.
        _ = try TailoringPeriod(start: try date(2020, 5), end: .date(try date(2020)))
        _ = try TailoringPeriod(start: try date(2020), end: .date(try date(2020, 1)))
        _ = try TailoringPeriod(start: try date(2020), end: .date(try date(2020)))
    }
}
