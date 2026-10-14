import Testing
import Foundation
@testable import PrestoCV

@Suite("LastSavedDescription Tests - when a CV was last saved, in words")
struct LastSavedDescriptionTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// A moment of November 2023, in UTC.
    private func moment(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2023, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func describe(saved: Date, viewedAt now: Date, _ locale: String = "en") -> String {
        LastSavedDescription(locale: Locale(identifier: locale), calendar: calendar).text(for: saved, relativeTo: now)
    }

    private func described(_ relative: String) -> String {
        "cv.list.edited".localizedWithArgs(relative)
    }

    /// The moment of the tests that count the time that went by: the middle of a day, so that a few hours before it are of the same day.
    private var noon: Date { moment(14, 12) }

    private func describe(_ locale: String = "en", savedAgo seconds: TimeInterval) -> String {
        describe(saved: noon.addingTimeInterval(-seconds), viewedAt: noon, locale)
    }

    // MARK: - Minutes and hours

    @Test("A CV saved less than a minute ago was saved just now", arguments: [0.0, 1, 30, 59])
    func recentSaveIsJustNow(seconds: TimeInterval) {
        #expect(describe(savedAgo: seconds) == "cv.list.edited_just_now".localized)
    }

    @Test("A time after now, which a clock that moved back leaves, reads as just now")
    func timeAfterNowIsJustNow() {
        #expect(describe(savedAgo: -3_600) == "cv.list.edited_just_now".localized)
    }

    @Test("A save of the same day is described in minutes and hours", arguments: [
        (60.0, "1 minute ago"),
        (300.0, "5 minutes ago"),
        (3 * 3_600.0, "3 hours ago"),
    ])
    func sameDaySaveIsMinutesAndHours(seconds: TimeInterval, relative: String) {
        #expect(describe(savedAgo: seconds) == described(relative))
    }

    // MARK: - Days

    @Test("A save of an earlier day is described in calendar days", arguments: [
        (86_400.0, "yesterday"),
        (2 * 86_400.0, "2 days ago"),
    ])
    func earlierDaySaveIsDays(seconds: TimeInterval, relative: String) {
        #expect(describe(savedAgo: seconds) == described(relative))
    }

    @Test("A save of the evening before, seen after midnight, reads yesterday", arguments: [
        (22, 30, 0, 30),
        (22, 30, 8, 0),
        (23, 0, 23, 30),
    ])
    func eveningSaveSeenAfterMidnightIsYesterday(savedHour: Int, savedMinute: Int, seenHour: Int, seenMinute: Int) {
        let saved = moment(14, savedHour, savedMinute)
        let seen = moment(15, seenHour, seenMinute)

        #expect(describe(saved: saved, viewedAt: seen) == described("yesterday"))
    }

    @Test("A save minutes before midnight, seen minutes after it, is still described in minutes")
    func saveJustBeforeMidnightIsMinutes() {
        #expect(describe(saved: moment(14, 23, 50), viewedAt: moment(15, 0, 20)) == described("30 minutes ago"))
    }

    @Test("Days count by the calendar, not by 24 hours")
    func daysCountByTheCalendar() {
        #expect(describe(saved: moment(9, 23, 0), viewedAt: moment(14, 1, 0)) == described("5 days ago"))
    }

    @Test("A save of several days ago is described in days, whatever the time of the day it is seen")
    func saveOfDaysAgo() {
        #expect(describe(saved: moment(10, 9, 0), viewedAt: moment(13, 9, 0)) == described("3 days ago"))
        #expect(describe(saved: moment(10, 9, 0), viewedAt: moment(13, 23, 59)) == described("3 days ago"))
    }

    // MARK: - Time zone

    @Test("The days are those of the calendar given: two moments of different days in one zone can be of one day in another")
    func daysFollowTheTimeZoneOfTheCalendar() {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let saved = moment(14, 23)
        let seen = moment(15, 1)
        let words = { (calendar: Calendar) in
            LastSavedDescription(locale: Locale(identifier: "en"), calendar: calendar).text(for: saved, relativeTo: seen)
        }

        #expect(words(calendar) == described("yesterday"))
        #expect(words(losAngeles) == described("2 hours ago"))
    }

    // MARK: - Language

    @Test("The words of the time follow the language given", arguments: [
        ("de", "vor 3 Tagen"),
        ("it", "3 giorni fa"),
        ("fr", "il y a 3 jours"),
        ("es", "hace 3 días"),
        ("pt", "há 3 dias"),
    ])
    func wordsFollowTheLocale(locale: String, relative: String) {
        #expect(describe(locale, savedAgo: 3 * 86_400) == described(relative))
    }

    @Test("The day before yesterday has a word of its own where the language has one")
    func dayBeforeYesterdayHasItsOwnWord() {
        #expect(describe("de", savedAgo: 2 * 86_400) == described("vorgestern"))
    }
}
