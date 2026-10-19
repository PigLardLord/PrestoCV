extension Certification {
    /// The year as its field shows it. A certification without a year has an empty field, so the placeholder "Year"
    /// is read instead of "0", and typing a year does not add it after a 0. Only the first four digits of what is
    /// typed or pasted count: a year has four, and a longer number would not be one.
    public var yearText: String {
        get { year == Certification().year ? "" : String(year) }
        set { year = Int(String(newValue.filter(\.isASCIIDigit).prefix(Self.yearDigits))) ?? Certification().year }
    }

    private static let yearDigits = 4
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isWholeNumber }
}
