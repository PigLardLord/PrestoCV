import SwiftUI

/// The order in which a locale writes a date's month and year: how a date is worded belongs to the app's edge, not to the
/// presentation layer.
enum MonthOrder {
    /// Whether a date's month stands before its year in `locale`, as in "March 2019", or after it, as in "2019年3月": the
    /// order the locale writes a month and a year in, its quoted words left out. Month first when the locale has none.
    static func monthBeforeYear(in locale: Locale) -> Bool {
        guard let pattern = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: locale) else { return true }
        let fields = pattern.split(separator: "'", omittingEmptySubsequences: false).enumerated()
            .filter { $0.offset.isMultiple(of: 2) }.map(\.element).joined()
        guard let month = fields.firstIndex(of: "M"), let year = fields.firstIndex(of: "y") else { return true }
        return month < year
    }
}
