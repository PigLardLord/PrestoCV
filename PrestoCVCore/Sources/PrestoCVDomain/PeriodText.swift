import Foundation

// A date and a period as the person writes them in a form: "2020" or "2020-05". The one reading (R6): an editor holds the
// text and asks the domain, so that it never decides what a period may be.

extension PartialDate {
    /// Reads "2020" or "2020-05", white space around it ignored. Nil for any other text, and for a date out of range.
    public init?(reading text: String) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }),
              let year = Int(parts[0]) else { return nil }
        guard parts.count == 2 else { self.init(year: year); return }
        guard let month = Int(parts[1]) else { return nil }
        self.init(year: year, month: month)
    }

    /// The text `init(reading:)` reads back: "2020" or "2020-05".
    public var text: String {
        guard let month else { return String(year) }
        return String(year) + (month < 10 ? "-0" : "-") + String(month)
    }
}

extension Period {
    /// A period from the text of its start and its end and whether it goes on. Blank text is no date. The combinations
    /// are `make(start:end:current:)`'s, and its typed reasons; a text that is no date is `invalidDate`.
    public static func reading(start: String, end: String, current: Bool) throws(PeriodError) -> Period? {
        func date(_ text: String) throws(PeriodError) -> (year: Int, month: Int?)? {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            guard let read = PartialDate(reading: text) else { throw .invalidDate }
            return (read.year, read.month)
        }
        return try make(start: try date(start), end: try date(end), current: current)
    }

    /// The text of the start, as `PartialDate.text` writes it.
    public var startText: String { start.text }

    /// The text of the end: blank while it goes on or is not known.
    public var endText: String {
        guard case .date(let date) = end else { return "" }
        return date.text
    }

    /// Whether the period goes on.
    public var isCurrent: Bool { end == .current }
}
