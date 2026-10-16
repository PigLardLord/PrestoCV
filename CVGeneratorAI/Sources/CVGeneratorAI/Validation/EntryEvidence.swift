import Foundation

/// What the description lets a draft say about one entry (ADR 0023, rule (c)): the words of the clauses that back it, and of the
/// clauses of nothing but a time phrase that join them.
struct EntryEvidence {
    /// The clauses that back the entry.
    let backing: [Clause]
    /// The backing clauses and the joining clauses that are pure time phrases (years and the words of the time-phrase list): where
    /// the entry's dates stand.
    let dated: [Clause]
    /// The joining clauses that are graduation phrases, for a study: they give its end date, and no other date.
    let graduation: [Clause]
    /// Whether the entry goes on now.
    let statesCurrent: Bool
    /// What its role text, study text and achievements may quote: the clauses that back it, outside any purpose tail, and those of
    /// nothing but time and the graduation phrases that join them.
    let quotable: ProseQuotes
    /// What an achievement that begins with a verb of a CV may quote besides: the other clauses that join the entry.
    let quotableByAchievements: ProseQuotes
    /// The achievements of the draft (by position) that begin with a verb of a CV.
    let verbAchievements: Set<Int>

    /// What the achievement at `number` may quote.
    func quotable(byAchievement number: Int) -> ProseQuotes {
        verbAchievements.contains(number) ? quotable.adding(quotableByAchievements) : quotable
    }

    /// Whether `phrase` (as `DescriptionText.normalized` writes it) stands in a clause that backs the entry: a place, an issuer.
    func backs(_ phrase: String) -> Bool {
        let words = Self.foldedWords(of: phrase)
        return backing.contains { $0.contains(words) }
    }

    /// The links a clause that backs the entry writes.
    var links: Set<String> {
        backing.reduce(into: Set<String>()) { $0.formUnion($1.links) }
    }

    /// The dates the description gives the entry, in the order they are asked for. A date with a year is kept if each of its
    /// years stands in the entry's clauses, and only as often as it stands there: a year that is written once backs one date. A
    /// date the description does not write that way is cut to its years ("2016-01-01" is "2016"); a date without a year (a
    /// month, "last spring") is kept only if the description writes it so.
    ///
    /// - Parameter graduationDate: The place, among `dates`, of the one that a graduation phrase may give: the end date of a
    ///   study. No other date takes a year of a graduation phrase.
    func supportedDates(_ dates: [String?], graduationDate: Int? = nil) -> [String?] {
        var budget = YearBudget(pure: Self.yearCounts(of: dated), graduation: Self.yearCounts(of: graduation))
        return dates.enumerated().map { index, date in
            guard let date = date.presentValue else { return nil }
            return supported(date, spending: &budget, mayTakeGraduation: index == graduationDate)
        }
    }

    // MARK: - Dates

    /// How many times each year stands in the clauses, and how many of them a date may still take.
    private struct YearBudget {
        var pure: [String: Int]
        var graduation: [String: Int]

        /// Takes one occurrence of each year, from a graduation phrase first when the date may, and says whether there was one.
        mutating func spend(_ years: [String], mayTakeGraduation: Bool) -> Bool {
            var attempt = self
            for year in years {
                if mayTakeGraduation, attempt.graduation[year, default: 0] > 0 {
                    attempt.graduation[year, default: 0] -= 1
                } else if attempt.pure[year, default: 0] > 0 {
                    attempt.pure[year, default: 0] -= 1
                } else {
                    return false
                }
            }
            self = attempt
            return true
        }
    }

    private static func yearCounts(of clauses: [Clause]) -> [String: Int] {
        clauses.flatMap(\.words).filter { $0.isNumber && $0.folded.count == 4 }.reduce(into: [:]) { $0[$1.folded, default: 0] += 1 }
    }

    private func supported(_ date: String, spending budget: inout YearBudget, mayTakeGraduation: Bool) -> String? {
        let years = Digits.runs(in: Digits.ascii(date)).filter { $0.count == 4 }
        let words = Self.foldedWords(of: date)
        let isWritten = Digits.ascii(date) == date && (dated + (mayTakeGraduation ? graduation : [])).contains { $0.contains(words) }
        guard !years.isEmpty else { return isWritten ? date : nil }

        guard budget.spend(years, mayTakeGraduation: mayTakeGraduation) else { return nil }
        return isWritten ? date : years.joined(separator: " – ")
    }

    static func foldedWords(of text: String) -> [String] {
        Word.words(in: text).map(\.folded)
    }
}
