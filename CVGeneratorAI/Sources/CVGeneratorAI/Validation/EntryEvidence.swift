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
    /// The names of the employers and schools of the draft: their words say nothing but the name (ADR 0023, rule (b)).
    let holders: [[String]]
    /// The name of the entry's own employer or school: the whole of it says nothing but the name either, unless the clause writes
    /// it once more. Nil for an entry with none (a certification).
    let ownHolder: [String]?
    /// The text of the clauses that back the entry and those that join it, in the order of the description.
    var context: [String] = []
    /// What a written duty of the entry may quote besides: the clause that names its employer alone (rule (a))
    /// and the relative clauses after it that only it holds (rule (b), "where ..."); never a shared tail (rule (c)).
    var quotableByAttribution: ProseQuotes? = nil
    /// ADR 0031, D1: the relative clauses that only continue the sentence naming the job: their years back its dates, and
    /// nothing else of them.
    var continuedDated: [Clause] = []
    /// ADR 0031, D3: every clause attributed to the job, shared tails among them: a duty that quotes one word for word may
    /// keep its acronyms, number words and seniority words.
    var ownClauseQuotes: ProseQuotes? = nil
    /// Whether the description says that the job is over: no clause of it says it goes on, and one writes two years or an end with
    /// no word for the present ("Dal 2013 al 2017 sono stata impiegata"). The duty check keeps its duties in the past (#362). Never
    /// true for a study.
    var statesEnded: Bool = false

    /// What the achievement at `number` may quote.
    func quotable(byAchievement number: Int) -> ProseQuotes {
        verbAchievements.contains(number) ? quotable.adding(quotableByAchievements) : quotable
    }

    /// Whether `phrase` (as `DescriptionText.normalized` writes it) stands in a clause that backs the entry, as itself and not as a
    /// word of the name of an employer or a school, nor as the whole of the entry's own: a place, an issuer. "Vale Verde" is not the
    /// place of a job that the description only places at the "Centro de Saúde de Vale Verde", nor "Bristol" of one at "Bristol".
    func backs(_ phrase: String) -> Bool {
        let words = Self.foldedWords(of: phrase)
        return backing.contains { !$0.spans(of: words, besideNames: holders, ownName: ownHolder).isEmpty }
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
        var budget = YearBudget(pure: Self.yearCounts(of: dated + continuedDated), graduation: Self.yearCounts(of: graduation))
        return dates.enumerated().map { index, date in
            guard let date = date.presentValue else { return nil }
            return supported(date, spending: &budget, mayTakeGraduation: index == graduationDate)
        }
    }

    /// The year the graduation clauses give the study, when they give one alone and none of `dates` holds it: the year the person
    /// says they finished it ("2011 meine Ausbildung abgeschlossen"), for a study whose end date the model wrote with another year or
    /// left out (#354). Nil when the clauses give no year, or more than one.
    func completionYear(besides dates: [String?]) -> String? {
        let years = Set(Self.yearCounts(of: graduation).keys)
        let held = Set(dates.compactMap { $0 }.flatMap { Digits.runs(in: Digits.ascii($0)).filter { $0.count == 4 } })
        guard years.count == 1, let year = years.first, !held.contains(year) else { return nil }
        return year
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
