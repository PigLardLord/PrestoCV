import Foundation

/// Whether the person mentions a phrase only as leisure (#202), so that a skill that is also one of the draft's interests is a hobby
/// and no ability the person claims.
///
/// Only the person's own clauses count, as the grounding attributes them (`Grounding.speaks(at:)`, the clauses of `spoken`): "My
/// sister teaches chess" neither keeps nor drops the person's chess. A clause of the person that denies, doubts or only wishes ("I
/// don't play chess", "I would like to learn Python") claims nothing, so it keeps no skill either.
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
    /// Whether the clause at a place speaks for the person.
    private let isThePersons: (DescriptionClauses.Place) -> Bool

    init(
        clauses: DescriptionClauses, language: Vocabulary.Language?, interests: [[String]],
        isThePersons: @escaping (DescriptionClauses.Place) -> Bool
    ) {
        self.clauses = clauses
        self.language = language
        self.interests = interests
        self.isThePersons = isThePersons
    }

    /// Whether some clause of the person mentions `phrase` (its folded words), and none of them claims it: each one is a clause of
    /// leisure, or one that denies, doubts or only wishes. When no clause of the person holds the phrase whole (it runs across two
    /// clauses), nothing tells, and the skill stays.
    func mentionsOnlyAsLeisure(_ phrase: [String]) -> Bool {
        let mentioning = clauses.places.filter { isThePersons($0) && clauses.clause(at: $0).contains(phrase) }
        return !mentioning.isEmpty && mentioning.allSatisfy { isLeisure($0) || claimsNothing($0) }
    }

    /// Whether the clause holds a word of negation, doubt or degree, wish, future or condition (`Vocabulary.modality`).
    private func claimsNothing(_ place: DescriptionClauses.Place) -> Bool {
        !Vocabulary.modality(in: clauses.clause(at: place).words, language: language).isEmpty
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
