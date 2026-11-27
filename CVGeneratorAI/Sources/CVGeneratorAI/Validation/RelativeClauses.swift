import Foundation

/// Where a clause goes on about another subject (#202): from a relative pronoun or a subordinator that brings one in
/// (`Vocabulary.isRelative`). In "I work with a colleague who speaks French", "Ich leite ein Team, das Kotlin nutzt" and "Je travaille
/// avec un collègue qui parle français", what follows the pronoun in its clause is the other subject's, and claims nothing for the person
/// (see `Grounding`).
///
/// - The person stays the subject when a pronoun of the first person follows ("which I use", "das ich nutze", "que je parle"), or, in the
///   languages that drop the pronoun, a listed form of a verb that only the person says ("che uso", "que hablo", "que falo").
/// - Spanish and Portuguese "que" brings in no subject after a form of "tener" or "ter" that the person can say: it makes their
///   periphrasis of obligation, whose infinitive is the person's ("tengo que hablar", "he tenido que hablar", "tenho que falar").
/// - A word that only ends the way an infinitive does keeps no person: it is often a finite form of the subject the relative brings in
///   ("qui prépare", "qui offre", "che appare", "que requer", "quem souber"). An infinitive after a relative outside the periphrasis
///   claims nothing either, an accepted loss: "hay que hablar inglés" says what a job needs, and "un team con cui parlare inglese"
///   gives no English.
/// - German "der", "die" and "das" are articles too: they bring in a subject only at the start of a clause that a comma or a conjunction
///   split off, or right after a preposition there ("mit dem"), and only when a verb follows, in their clause or in the clauses that go
///   on with it: a relative clause or one with a subject of its own has one ("das Kotlin und Swift nutzt", "und die Kollegen pflegten
///   die Parkanlagen"), a list of nouns has none ("mit dem Verlegen von Pflasterflächen und dem Einbau von Bewässerungsanlagen", #359).
/// - English "that" is a demonstrative too: it brings in a subject only after the first word of its clause, and before a verb, a pronoun
///   of the third person, a possessive or an article ("a team that uses", "that my team chose"), never before a noun ("in that role").
/// - The pronoun reads the same when the person is the subject it brings in: "I am a developer who knows Swift" claims no Swift, an
///   accepted loss.
enum RelativeClauses {
    /// The relatives that are German articles as well.
    private static let articles = Vocabulary.relatives(of: .german)
    /// The relatives that are demonstratives as well.
    private static let demonstratives: Set<String> = ["that"]
    /// The forms of Spanish "tener" and Portuguese "ter" that the person can say, alone or with the auxiliary of their perfect, as
    /// `Word.folded` writes them: "que" after one of them makes the periphrasis of obligation.
    private static let obligations: [Vocabulary.Language: [[String]]] = [
        .spanish: [["tengo"], ["tenia"], ["tuve"], ["he", "tenido"], ["habia", "tenido"]],
        .portuguese: [["tenho"], ["tinha"], ["tive"], ["tenho", "tido"], ["tinha", "tido"]],
    ]
    private static let everyObligation: [[String]] = obligations.values.flatMap { $0 }

    /// The position in `clause` of the word from which it speaks of another subject, or nil when it speaks of none.
    ///
    /// - Parameter later: The later clauses of the sentence that go on with `clause`, split off by a comma or a conjunction, up to one
    ///   that opens a clause of its own: where the verb of a German relative clause may stand ("das Kotlin und / Swift nutzt").
    static func start(in clause: Clause, goingOnWith later: [Clause], language: Vocabulary.Language?) -> Int? {
        let words = clause.words
        return words.indices.dropLast().first { index in
            let word = words[index].folded
            guard Vocabulary.isRelative(word, in: language), !keepsThePerson(words[index + 1], language: language),
                  !makesAnObligation(at: index, in: words, language: language) else { return false }
            if articles.contains(word) {
                return startsTheClause(index, clause, language: language)
                    && (hasAVerb(clause, after: index, language: language) || later.contains { hasAVerb($0, after: -1, language: language) })
            }
            if demonstratives.contains(word) { return index > 0 && bringsInASubject(words[index + 1], language: language) }
            return true
        }
    }

    /// Whether the word after a relative keeps the person as the subject: a pronoun of the first person, or, where the pronoun is
    /// dropped, a listed form of a verb that is no form of another person and none that a noun can be the subject of.
    private static func keepsThePerson(_ next: Word, language: Vocabulary.Language?) -> Bool {
        if rules(of: language).firstPerson.contains(next.accented) { return true }
        let isListed = Vocabulary.isVerb(next.folded, in: language) || Vocabulary.isAuxiliary(next.accented, in: language)
            || Vocabulary.isBeForm(next.accented, in: language)
        return isListed && !Vocabulary.isOtherPerson(next.accented, in: language) && !Vocabulary.canTakeANounSubject(next.accented, in: language)
    }

    /// Whether the relative at `index` is the "que" of a periphrasis of obligation: right after a form of "tener" or "ter" that the person
    /// can say ("tengo que hablar", "tenho que falar").
    private static func makesAnObligation(at index: Int, in words: [Word], language: Vocabulary.Language?) -> Bool {
        guard words[index].folded == "que" else { return false }
        let before = words[..<index].map(\.folded)
        let forms = language.map { obligations[$0] ?? [] } ?? everyObligation
        return forms.contains { form in before.count >= form.count && before.suffix(form.count).elementsEqual(form) }
    }

    /// Whether the relative at `index` starts a clause that a comma or a conjunction split off, alone or after a preposition.
    private static func startsTheClause(_ index: Int, _ clause: Clause, language: Vocabulary.Language?) -> Bool {
        guard !clause.isAnchored else { return false }
        return index == 0 || (index == 1 && rules(of: language).prepositions.contains(clause.words[0].accented))
    }

    /// Whether a word of the German `clause` after `index` may be a verb: a word written in lower case, as German writes every noun with
    /// a capital letter ("Verlegen" is a noun, whatever the device tags), and no number, that the device tags or a list holds as a verb,
    /// or that is no function word and no word of time.
    static func hasAVerb(_ clause: Clause, after index: Int, language: Vocabulary.Language?) -> Bool {
        clause.words.indices.dropFirst(index + 1).contains { position in
            let word = clause.words[position]
            guard !word.isNumber, !clause.isCapitalised(position) else { return false }
            return word.isTaggedVerb || Vocabulary.isVerb(word.folded, in: language) || Vocabulary.isAuxiliary(word.accented, in: language)
                || Vocabulary.isBeForm(word.accented, in: language) || !Vocabulary.isNeutral(word.folded, in: language)
        }
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
