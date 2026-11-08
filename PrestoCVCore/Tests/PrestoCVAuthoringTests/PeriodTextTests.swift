import Testing
import PrestoCVDomain

/// A period and a date as the person writes them: the domain reads the text, the editor holds none of the rule.
@Suite("Period text")
struct PeriodTextTests {

    @Test("a year, or a year and a month, is a date; anything else is none")
    func dateText() {
        #expect(PartialDate(reading: "2020") == PartialDate(year: 2020))
        #expect(PartialDate(reading: " 2020-05 ") == PartialDate(year: 2020, month: 5))
        #expect(PartialDate(reading: "2020-13") == nil)
        #expect(PartialDate(reading: "May 2020") == nil)
        #expect(PartialDate(reading: "") == nil)
        #expect(PartialDate(year: 2020, month: 5)?.text == "2020-05")
        #expect(PartialDate(year: 2020)?.text == "2020")
    }

    @Test("a period is read from the start, the end and the current flag, with the typed reasons")
    func periodText() throws {
        #expect(try Period.reading(start: "", end: "", current: false) == nil)
        #expect(try Period.reading(start: "2020-05", end: "", current: true) == Period(start: PartialDate(year: 2020, month: 5)!, end: .current))
        #expect(try Period.reading(start: "2020", end: "", current: false) == Period(start: PartialDate(year: 2020)!, end: .unknown))
        #expect(try Period.reading(start: "2019", end: "2020-03", current: false)?.end == .date(PartialDate(year: 2020, month: 3)!))
        #expect(throws: PeriodError.endBeforeStart) { _ = try Period.reading(start: "2020", end: "2019", current: false) }
        #expect(throws: PeriodError.endWithoutStart) { _ = try Period.reading(start: "", end: "2019", current: false) }
        #expect(throws: PeriodError.currentWithoutStart) { _ = try Period.reading(start: "", end: "", current: true) }
        #expect(throws: PeriodError.currentWithEndDate) { _ = try Period.reading(start: "2019", end: "2020", current: true) }
        #expect(throws: PeriodError.invalidDate) { _ = try Period.reading(start: "last spring", end: "", current: false) }
    }

    @Test("a period is written back as the text it is read from")
    func periodWritesBack() throws {
        for (start, end, current) in [("2019-02", "2020", false), ("2018", "", true), ("2018", "", false)] {
            let period = try #require(try Period.reading(start: start, end: end, current: current))
            #expect(period.startText == start)
            #expect(period.endText == end)
            #expect(period.isCurrent == current)
        }
    }
}
