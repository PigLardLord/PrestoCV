import Testing
@testable import PrestoCVPresentation

/// A date of the form as the parts the person picks: the domain reads the text into them and writes them back (R6), so
/// the form never parses a date.
@Suite("Date parts")
struct DatePartsTests {

    @Test("a year alone gives the year and no month")
    func readsYearOnly() {
        #expect(DateParts(text: "2020") == DateParts(year: "2020", month: nil))
    }

    @Test("a year and a month give both")
    func readsYearAndMonth() {
        #expect(DateParts(text: "2020-05") == DateParts(year: "2020", month: 5))
    }

    @Test("the parts are written back as the domain reads them: the month with two digits")
    func writesTwoDigitMonth() {
        #expect(DateParts(year: "2020", month: 5).text == "2020-05")
        #expect(DateParts(year: "2020", month: 11).text == "2020-11")
        #expect(DateParts(year: "2020", month: nil).text == "2020")
    }

    @Test("text the domain cannot read gives no parts: an empty year, never 0, and no month")
    func unreadableTextGivesNoParts() {
        for text in ["last spring", "0", "2020-13", ""] {
            #expect(DateParts(text: text) == DateParts(year: "", month: nil), "\(text)")
        }
    }

    @Test("parts that make no date have no text: a year still being typed, a month without a year; no parts are blank")
    func noTextWithoutADate() {
        #expect(DateParts(year: "20", month: nil).text == nil)
        #expect(DateParts(year: "", month: 5).text == nil)
        #expect(DateParts(year: "", month: nil).text == "")
    }

    @Test("the month menu offers the twelve months a date can have, January first")
    func monthsAreTheOnesADateCanHave() {
        #expect(EditorChoices.months == Array(1...12))
        #expect(EditorChoices.months.allSatisfy { DateParts(year: "2020", month: $0).text != nil })
    }
}
