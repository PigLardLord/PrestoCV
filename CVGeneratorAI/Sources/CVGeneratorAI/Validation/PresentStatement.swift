import Foundation

/// Whether a clause of the description says that a thing goes on now.
///
/// A word for the present (now, currently, today, attualmente, derzeit...) says it, and so does "since" when the whole sentence
/// holds exactly one year. Two years in the clause, a negation or a hedge, or an end ("until", "formerly") deny it.
enum PresentStatement {
    /// - Parameters:
    ///   - text: The clause, with the clauses of nothing but time next to it, as `DescriptionText.normalized` writes it.
    ///   - sentenceYears: How many different years the sentence writes in the clauses that count for the entry: those that back an
    ///     entry or join this one.
    static func holds(in text: String, sentenceYears: Int) -> Bool {
        guard distinctYears(in: text) < 2, !DescriptionText.hedgesOrNegates(text), !DescriptionText.containsAny(StatementWords.ends, in: text) else { return false }

        if DescriptionText.containsAny(StatementWords.presents, in: text) {
            return true
        }
        return DescriptionText.containsAny(StatementWords.since, in: text) && sentenceYears == 1
    }

    private static func distinctYears(in text: String) -> Int {
        Set(Digits.runs(in: Digits.ascii(text)).filter { $0.count == 4 }).count
    }
}
