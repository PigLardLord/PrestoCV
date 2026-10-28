import Foundation

/// A title the person states as what they are (#354): "I am a plumber", "Sono uno sviluppatore iOS", "Ich bin Bäckerin", "Soy
/// camarero", "Je suis comptable", "Sou motorista de caminhão".
///
/// The model sometimes writes such a title as a job with no employer and no date, which the sanitiser drops (ADR 0023 (c)): a title
/// alone is no job. The title is still the person's headline when a clause that claims it says it in this shape: the lead-in of a
/// quote at the start of the clause (`LeadIn`: nothing, or "I", "where I", "io"...) ending in the present of "to be" in the first
/// person ("am", "sono", "bin", "soy", "suis", "sou"), then at most an indefinite article, then the title, then the end of the
/// sentence or "and" and the clause it starts ("I am a plumber and I fix pipes"). "I like long walks", "I want to be a nurse", "I am
/// not a nurse", "My mother is a nurse", "I'm looking for a job as a nurse" and "I am a nurse assistant" state no "nurse"; "I was a
/// nurse", "J'étais étudiant en 2015" and "Ich bin Bäckerin gewesen" state a title the person had. A word after the title can make it
/// no role the person holds ("Je suis médecin dans un jeu vidéo", "I am a nurse, but only in a game"), so nothing but "and" may
/// follow it in its sentence: "I am a nurse in Leeds" gives no headline either, the safe way to fail.
enum StatedTitle {
    /// `title` when a clause of `claimed`, the clauses that claim something for the person, states it as above; otherwise nil.
    static func title(_ title: String?, in claimed: DescriptionText) -> String? {
        guard let title = claimed.named(title) else { return nil }
        let wanted = EntryEvidence.foldedWords(of: title)
        let language = claimed.explainer.language

        let sentences = DescriptionClauses(sentences: claimed.sentences.map(\.raw), protecting: [wanted], language: language).sentences
        let isStated = sentences.contains { clauses in
            clauses.indices.contains { index in
                let words = clauses[index].words
                guard words.count >= wanted.count, words.suffix(wanted.count).map(\.folded) == wanted else { return false }
                guard index == clauses.count - 1 || endsWithAnd(clauses[index], in: language) else { return false }
                return isSaid(before: words.count - wanted.count, in: words, language: language)
            }
        }
        return isStated ? title : nil
    }

    /// Whether the words before `start` say the title as what the person is now: the lead-in, the present of "to be" in the first
    /// person, at most an indefinite article.
    private static func isSaid(before start: Int, in words: [Word], language: Vocabulary.Language?) -> Bool {
        var end = start
        if end > 0, EntryWording.isIndefiniteArticle(words[end - 1].folded, in: language) { end -= 1 }
        guard end > 0, isPresentFirstPersonBe(words[end - 1].accented, in: language) else { return false }
        return LeadIn.holds(words[..<end], in: language)
    }

    /// Whether the clause ends at "and": its source holds the conjunction that ends it; a comma or a semicolon is none.
    private static func endsWithAnd(_ clause: Clause, in language: Vocabulary.Language?) -> Bool {
        guard let last = Word.words(in: clause.source).last else { return false }
        return forms(ands, in: language).contains(last.accented)
    }

    /// The present of "to be" in the first person, as `Word.accented` writes it ("I'm" is "i" and "m"). The past ("was", "ero",
    /// "war", "era", "étais", "fui") and the other persons are none: a title the person had, or another person's, is no headline.
    private static let presentFirstPersonBe: [Vocabulary.Language: Set<String>] = [
        .english: ["am", "m"], .italian: ["sono"], .german: ["bin"], .spanish: ["soy"], .french: ["suis"], .portuguese: ["sou"],
    ]

    /// "And", the one word that may follow the title: it starts another clause about the person. A German perfect ("Ich bin Bäckerin
    /// gewesen") has its participle after the title, so it is none.
    private static let ands: [Vocabulary.Language: Set<String>] = [
        .english: ["and"], .italian: ["e", "ed"], .german: ["und"], .spanish: ["y", "e"], .french: ["et"], .portuguese: ["e"],
    ]

    private static func isPresentFirstPersonBe(_ word: String, in language: Vocabulary.Language?) -> Bool {
        forms(presentFirstPersonBe, in: language).contains(word)
    }

    private static func forms(_ table: [Vocabulary.Language: Set<String>], in language: Vocabulary.Language?) -> Set<String> {
        language.map { table[$0] ?? [] } ?? table.values.reduce(into: []) { $0.formUnion($1) }
    }
}
