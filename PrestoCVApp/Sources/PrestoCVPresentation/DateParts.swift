internal import PrestoCVDomain

/// A date of the form as the person picks it: a month, or none, and the year as they type it. The year is text, empty
/// until they write one, never "0". The domain reads the parts and writes them (R6): the form never parses a date.
public struct DateParts: Hashable, Sendable {
    public var year: String
    /// The month, 1 for January; nil for none.
    public var month: Int?
}

/// The period of a row as the person picks it: its start, its end, and whether it goes on. A period that goes on has no
/// end: turning it on clears the end, and the form no longer asks for one.
public struct PeriodParts: Hashable, Sendable {
    public var start: DateParts
    public var end: DateParts
    public var isCurrent: Bool {
        didSet { if isCurrent { end = .none } }
    }

    /// Whether the form asks for the end: not while the period goes on.
    public var asksForEnd: Bool { !isCurrent }
}

extension DateParts {
    static let none = DateParts(year: "", month: nil)

    /// The parts of "2020" or "2020-05"; no parts for text the domain cannot read as a date.
    init(text: String) {
        guard let date = PartialDate(reading: text) else {
            self = .none
            return
        }
        self.init(year: String(date.year), month: date.month)
    }

    /// The text the domain reads ("2020", "2020-05"): blank when nothing is picked, nil when the parts make no date, such
    /// as a year still being typed or a month without a year.
    var text: String? {
        guard !isBlank else { return "" }
        guard let year = PartialDate(reading: year), year.month == nil,
              let date = PartialDate(year: year.year, month: month) else { return nil }
        return date.text
    }

    var isBlank: Bool { year.isBlank && month == nil }
}

extension PeriodParts {
    static let none = PeriodParts(start: .none, end: .none, isCurrent: false)

    init(_ period: Period?) {
        self.init(start: DateParts(text: period?.startText ?? ""), end: DateParts(text: period?.endText ?? ""),
                  isCurrent: period?.isCurrent ?? false)
    }

    /// The period the CV stores: nil when there is none, or when the domain cannot read the parts (`problem` says why).
    var stored: Period? {
        do {
            return try read()
        } catch {
            return nil
        }
    }

    /// Why the domain cannot read the parts as a period; nil when it can, or when there is nothing to read.
    var problem: FieldProblem.Code? {
        do {
            _ = try read()
            return nil
        } catch PeriodError.endBeforeStart {
            return .endBeforeStart
        } catch {
            return .unreadable
        }
    }

    var isBlank: Bool { start.isBlank && end.isBlank && !isCurrent }

    private func read() throws(PeriodError) -> Period? {
        guard let start = start.text, let end = end.text else { throw .invalidDate }
        return try Period.reading(start: start, end: end, current: isCurrent)
    }
}
