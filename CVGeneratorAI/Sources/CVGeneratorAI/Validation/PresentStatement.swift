import Foundation

/// Whether a clause of the description says that a thing goes on now.
///
/// A word for the present (now, currently, today, attualmente, derzeit...) says it, and so does "since" when the whole sentence
/// holds exactly one year. Two years in the clause, a negation or a hedge, or an end ("until", "formerly") deny it. A clause with
/// two years or an end, and no word for the present, says that the thing is over (`ended`).
enum PresentStatement {
    /// - Parameters:
    ///   - text: The clause, with the clauses of nothing but time next to it, as `DescriptionText.normalized` writes it.
    ///   - sentenceYears: How many different years the sentence writes in the clauses that count for the entry: those that back an
    ///     entry or join this one.
    ///   - language: The language of the description, when it is known: a hedge of another language may be a word of it ("Mai").
    static func holds(in text: String, sentenceYears: Int, language: Vocabulary.Language? = nil) -> Bool {
        guard distinctYears(in: text) < 2, !DescriptionText.hedgesOrNegates(text, language: language),
              !DescriptionText.containsAny(StatementWords.ends, in: text) else { return false }

        if DescriptionText.containsAny(StatementWords.presents, in: text) {
            return true
        }
        return DescriptionText.containsAny(StatementWords.since, in: text) && sentenceYears == 1
    }

    /// Whether a clause says that a thing is over: it writes two different years ("from 2014 to 2018") or an end ("until",
    /// "formerly"), and no word for the present. A hedge does not make the thing go on here: what asks this keeps less when it is
    /// true, and losing a fact beats inventing one.
    ///
    /// - Parameter text: The clause, with the clauses of nothing but time next to it, as `DescriptionText.normalized` writes it.
    static func ended(in text: String) -> Bool {
        guard !DescriptionText.containsAny(StatementWords.presents, in: text) else { return false }
        return distinctYears(in: text) >= 2 || DescriptionText.containsAny(StatementWords.ends, in: text)
    }

    private static func distinctYears(in text: String) -> Int {
        Set(Digits.runs(in: Digits.ascii(text)).filter { $0.count == 4 }).count
    }
}
