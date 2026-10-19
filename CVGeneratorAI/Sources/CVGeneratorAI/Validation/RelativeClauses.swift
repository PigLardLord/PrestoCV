import Foundation

/// Where a clause goes on about another subject (#202): from a relative pronoun or a subordinator that brings one in
/// (`Vocabulary.isRelative`). In "I work with a colleague who speaks French", "Ich leite ein Team, das Kotlin nutzt" and "Je travaille
/// avec un collègue qui parle français", what follows the pronoun in its clause is the other subject's, and claims nothing for the person
/// (see `Grounding`).
///
/// - The person stays the subject when a pronoun of the first person follows ("which I use", "das ich nutze", "que je parle"), or, in the
///   languages that drop the pronoun, a listed form of a verb that only the person says ("che uso", "que hablo", "que falo"), or an
///   infinitive, which has no subject of its own ("tengo que hablar").
/// - German "der", "die" and "das" are articles too: they bring in a subject only at the start of a clause that a comma or a conjunction
///   split off, or right after a preposition there ("mit dem").
/// - English "that" is a demonstrative too: it brings in a subject only after the first word of its clause, and before a verb, a pronoun
///   of the third person, a possessive or an article ("a team that uses", "that my team chose"), never before a noun ("in that role").
/// - The pronoun reads the same when the person is the subject it brings in: "I am a developer who knows Swift" claims no Swift, an
///   accepted loss.
enum RelativeClauses {
    /// The relatives that are German articles as well.
    private static let articles = Vocabulary.relatives(of: .german)
    /// The relatives that are demonstratives as well.
    private static let demonstratives: Set<String> = ["that"]

    /// The position in `clause` of the word from which it speaks of another subject, or nil when it speaks of none.
    static func start(in clause: Clause, language: Vocabulary.Language?) -> Int? {
        let words = clause.words
        return words.indices.dropLast().first { index in
            let word = words[index].folded
            guard Vocabulary.isRelative(word, in: language), !keepsThePerson(words[index + 1], language: language) else { return false }
            if articles.contains(word) { return startsTheClause(index, clause, language: language) }
            if demonstratives.contains(word) { return index > 0 && bringsInASubject(words[index + 1], language: language) }
            return true
        }
    }

    /// Whether the word after a relative keeps the person as the subject: a pronoun of the first person, an infinitive, or, where the
    /// pronoun is dropped, a listed form of a verb that is no form of another person and none that a noun can be the subject of.
    private static func keepsThePerson(_ next: Word, language: Vocabulary.Language?) -> Bool {
        if rules(of: language).firstPerson.contains(next.accented) || VerbForms.hasInfinitiveEnding(next, in: language) { return true }
        let isListed = Vocabulary.isVerb(next.folded, in: language) || Vocabulary.isAuxiliary(next.accented, in: language)
            || Vocabulary.isBeForm(next.accented, in: language)
        return isListed && !Vocabulary.isOtherPerson(next.accented, in: language) && !Vocabulary.canTakeANounSubject(next.accented, in: language)
    }

    /// Whether the relative at `index` starts a clause that a comma or a conjunction split off, alone or after a preposition.
    private static func startsTheClause(_ index: Int, _ clause: Clause, language: Vocabulary.Language?) -> Bool {
        guard !clause.isAnchored else { return false }
        return index == 0 || (index == 1 && rules(of: language).prepositions.contains(clause.words[0].accented))
    }

    /// Whether the word after a demonstrative relative starts a clause of its own: a verb, a pronoun of the third person, a possessive
    /// or an article.
    private static func bringsInASubject(_ next: Word, language: Vocabulary.Language?) -> Bool {
        let rules = rules(of: language)
        let isAVerb = next.isTaggedVerb || Vocabulary.isVerb(next.folded, in: language) || Vocabulary.isBeForm(next.accented, in: language)
            || Vocabulary.isAuxiliary(next.accented, in: language) || Vocabulary.isEverydayVerb(next.accented, in: language)
            || !Vocabulary.modality(in: [next], language: language).isEmpty
        let opensASubject = [rules.thirdPerson, rules.otherPeople, rules.possessives, rules.otherPossessives, rules.articles]
            .contains { $0.contains(next.accented) }
        return isAVerb || opensASubject
    }

    private static func rules(of language: Vocabulary.Language?) -> Voice.Words {
        language.flatMap { Voice.words[$0] } ?? Voice.everyWord
    }
}
