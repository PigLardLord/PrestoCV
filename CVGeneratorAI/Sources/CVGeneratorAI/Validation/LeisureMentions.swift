import Foundation

/// Whether the person mentions a phrase only as leisure (#202), so that a skill that is also one of the draft's interests is a hobby
/// and no ability the person claims.
///
/// Only the clauses that claim something for the person count, as the grounding reads them (`Grounding.claims(at:)`, the clauses
/// that skills, interests and languages are grounded in): "My sister teaches chess" and "I don't play chess" neither keep nor drop
/// the person's chess.
///
/// A clause of leisure holds a word of leisure ("free time", "hobby", "like"; "tempo libero", "piacciono"; "Freizeit", "mag"; "tiempo
/// libre", "gustan"; "temps libre", "aime"; "tempo livre", "gosto"), and nothing else but the quotes of the draft's interests and
/// function or time words: "In my free time I like chess". A fragment of interests and function words that a comma or a conjunction
/// split off from a clause of leisure is one too: "and hiking". Any other clause that mentions the phrase claims it: "I am proficient
/// in Python", "where I do portrait photography", "My skills include chess".
struct LeisureMentions {
    /// The words of leisure of each language, as `DescriptionText.normalized` writes them.
    private static let wordsByLanguage: [Vocabulary.Language: Set<String>] = [
        .english: [
            "free", "spare", "leisure", "hobby", "hobbies", "pastime", "pastimes", "like", "likes", "enjoy", "enjoys", "love", "loves",
        ],
        .italian: ["tempo", "libero", "hobby", "passatempo", "passatempi", "piace", "piacciono", "amo", "adoro"],
        .german: ["freizeit", "hobby", "hobbys", "hobbies", "mag", "liebe"],
        .spanish: [
            "tiempo", "libre", "ocio", "aficion", "aficiones", "pasatiempo", "pasatiempos", "gusta", "gustan", "encanta", "encantan",
        ],
        .french: ["temps", "libre", "loisir", "loisirs", "passe", "aime", "adore"],
        .portuguese: ["tempo", "livre", "lazer", "passatempo", "passatempos", "hobby", "hobbies", "gosto", "adoro", "amo"],
    ]

    private static let everyWord: Set<String> = wordsByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    private let clauses: DescriptionClauses
    private let language: Vocabulary.Language?
    /// The folded words of the draft's interests that the description gives.
    private let interests: [[String]]
    /// Whether the clause at a place claims something for the person.
    private let isClaimed: (DescriptionClauses.Place) -> Bool

    init(
        clauses: DescriptionClauses, language: Vocabulary.Language?, interests: [[String]],
        isClaimed: @escaping (DescriptionClauses.Place) -> Bool
    ) {
        self.clauses = clauses
        self.language = language
        self.interests = interests
        self.isClaimed = isClaimed
    }

    /// Whether some clause that claims something for the person mentions `phrase` (its folded words), and every one that does is a
    /// clause of leisure. When none holds the phrase whole (it runs across two clauses), nothing tells, and the skill stays.
    func mentionsOnlyAsLeisure(_ phrase: [String]) -> Bool {
        let mentioning = clauses.places.filter { isClaimed($0) && clauses.clause(at: $0).contains(phrase) }
        return !mentioning.isEmpty && mentioning.allSatisfy(isLeisure)
    }

    private func isLeisure(_ place: DescriptionClauses.Place) -> Bool {
        let clause = clauses.clause(at: place)
        let quoted = clause.positions(inside: interests)
        let leisure = Set(clause.words.indices.filter { isLeisureWord(clause.words[$0].folded) })
        let isMadeOfLeisure = clause.words.indices.allSatisfy { index in
            quoted.contains(index) || leisure.contains(index) || Vocabulary.isNeutral(clause.words[index].folded, in: language)
        }
        guard isMadeOfLeisure else { return false }
        if !leisure.isEmpty { return true }
        return !quoted.isEmpty && !clause.isAnchored && place.clause > 0
            && isLeisure(DescriptionClauses.Place(sentence: place.sentence, clause: place.clause - 1))
    }

    private func isLeisureWord(_ word: String) -> Bool {
        (language.map { Self.wordsByLanguage[$0] ?? [] } ?? Self.everyWord).contains(word)
    }
}
