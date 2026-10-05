import Foundation

/// The rules for one value of a document that need no memory of the others: how many items a list may hold, which
/// ratings, dates and periods are valid, and which characters a text may not hold.
enum DocumentValueRules {
    typealias Invalid = CVDocumentValidator.Invalid

    static let maxItems = 200

    static func requireCount(_ count: Int, _ what: String) throws(Invalid) {
        if count > maxItems { throw Invalid(reason: "too many \(what)") }
    }

    static func requireRating(_ rating: Int?) throws(Invalid) {
        if let rating, !(1...5).contains(rating) { throw Invalid(reason: "rating") }
    }

    static func requireYear(_ year: Int?) throws(Invalid) {
        if let year { try requireDate(DocumentDate(year: year)) }
    }

    static func requireDate(_ date: DocumentDate) throws(Invalid) {
        guard (1900...2200).contains(date.year), date.month.map({ (1...12).contains($0) }) ?? true else { throw Invalid(reason: "date") }
    }

    static func requirePeriod(_ period: DocumentPeriod?) throws(Invalid) {
        guard let period else { return }
        try requireDate(period.start)
        if case .date(let end) = period.end { try requireDate(end) }
        if period.endsBeforeStart { throw Invalid(reason: "end before start") }
    }

    /// Control characters other than a newline are refused. So are the explicit bidirectional embeddings, overrides
    /// and isolates, which reorder what is printed.
    static func hasForbiddenScalar(_ text: String) -> Bool {
        text.unicodeScalars.contains { ($0.properties.generalCategory == .control && $0 != "\n") || reordersText($0) }
    }

    private static func reordersText(_ scalar: Unicode.Scalar) -> Bool {
        (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
    }
}

private extension DocumentPeriod {
    /// A date with no month spans its whole year, so a start counts from its first month and an end up to its last.
    var endsBeforeStart: Bool {
        guard case .date(let end) = end else { return false }
        return (end.year, end.month ?? 12) < (start.year, start.month ?? 1)
    }
}
