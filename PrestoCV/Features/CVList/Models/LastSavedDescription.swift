import Foundation

/// Says when a CV was last saved, relative to a moment and in the words of the language of the app: "Edited 2 days ago".
///
/// A save of the same day is told in minutes and hours. A save of an earlier day is told in calendar days, so that a
/// CV saved in the evening reads "yesterday" once midnight has passed, unless it was saved less than an hour ago.
struct LastSavedDescription {
    private static let justNowThreshold: TimeInterval = 60
    private static let hourThreshold: TimeInterval = 3_600

    private let locale: Locale
    private let calendar: Calendar

    /// - Parameter locale: The language of the words of the time. It is the language of the app, which is what the
    ///   rest of the texts are in, and not the region of the device, which can differ from it.
    init(
        locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en"),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.locale = locale
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - savedAt: When the CV was saved.
    ///   - now: The moment the text is for. The caller owns the clock, so that the text can be made again for a later moment.
    func text(for savedAt: Date, relativeTo now: Date) -> String {
        let elapsed = now.timeIntervalSince(savedAt)
        guard elapsed >= Self.justNowThreshold else {
            return "cv.list.edited_just_now".localized
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let isEarlierDay = elapsed >= Self.hourThreshold && !calendar.isDate(savedAt, inSameDayAs: now)
        let relative = isEarlierDay
            ? formatter.localizedString(for: calendar.startOfDay(for: savedAt), relativeTo: calendar.startOfDay(for: now))
            : formatter.localizedString(for: savedAt, relativeTo: now)
        return "cv.list.edited".localizedWithArgs(relative)
    }
}
