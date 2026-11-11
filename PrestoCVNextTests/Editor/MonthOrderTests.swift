import Testing
import SwiftUI
@testable import PrestoCVNext

/// A date's month and year stand in the order of the person's locale: how a date is worded is the app's.
@Suite("MonthOrder")
struct MonthOrderTests {

    @Test("the month comes before the year where the locale writes it so, and after it where the locale writes the year first")
    func monthAndYearInTheLocaleOrder() {
        #expect(MonthOrder.monthBeforeYear(in: Locale(identifier: "en_US")))
        #expect(MonthOrder.monthBeforeYear(in: Locale(identifier: "de_DE")))
        #expect(!MonthOrder.monthBeforeYear(in: Locale(identifier: "ja_JP")))
        #expect(!MonthOrder.monthBeforeYear(in: Locale(identifier: "hu_HU")))
    }
}
