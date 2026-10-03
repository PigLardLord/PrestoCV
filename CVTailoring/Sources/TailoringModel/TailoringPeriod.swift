/// A year, or a year and a month. Only a partial order exists between dates of different precision.
public struct TailoringDate: Hashable, Sendable {
    public let year: Int
    public let month: Int?

    public init(year: Int, month: Int? = nil) throws(TailoringModelError) {
        guard (1900...2200).contains(year), month.map({ (1...12).contains($0) }) ?? true else { throw .invalidDate }
        self.year = year
        self.month = month
    }

    /// "May 2020" and "2020" are ordered: months are compared only when both are known.
    fileprivate func isNotAfter(_ other: TailoringDate) -> Bool {
        if year != other.year { return year < other.year }
        guard let month, let otherMonth = other.month else { return true }
        return month <= otherMonth
    }
}

/// When an experience, a degree or a role took place. A period always has a start.
public struct TailoringPeriod: Hashable, Sendable {
    /// How a period ends. `unknown` means it has ended and its end date was not given; the model never invents one.
    public enum End: Hashable, Sendable { case current, date(TailoringDate), unknown }

    public let start: TailoringDate
    public let end: End

    /// An end date before the start is refused. Months are compared only when both are known.
    public init(start: TailoringDate, end: End) throws(TailoringModelError) {
        if case .date(let endDate) = end, !start.isNotAfter(endDate) { throw .invalidPeriod }
        self.start = start
        self.end = end
    }
}
