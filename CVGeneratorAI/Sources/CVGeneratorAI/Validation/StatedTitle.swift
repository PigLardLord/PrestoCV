import Foundation

/// A title the person states as what they are (#354): "I am a plumber", "Sono uno sviluppatore iOS", "Ich bin Bäckerin", "Soy
/// camarero", "Je suis comptable", "Sou motorista de caminhão".
///
/// The model sometimes writes such a title as a job with no employer and no date, which the sanitiser drops (ADR 0023 (c)): a title
/// alone is no job. The title is still the person's headline when a clause that claims it says it in this shape: the lead-in of a
/// quote at the start of the clause (`LeadIn`: nothing, or "I", "where I", "io"...) ending in the present of "to be" in the first
/// person ("am", "sono", "bin", "soy", "suis", "sou"), then at most an indefinite article, then the title, then nothing or a function
/// word ("in Leeds"). "I like long walks", "I want to be a nurse", "I am not a nurse", "My mother is a nurse", "I'm looking for a job
/// as a nurse" and "I am a nurse assistant" state no "nurse"; "I was a nurse", "J'étais étudiant en 2015" and "Ich bin Bäckerin
/// gewesen" state a title the person had, which is no headline.
enum StatedTitle {
    /// `title` when a clause of `claimed`, the clauses that claim something for the person, states it as above; otherwise nil.
    static func title(_ title: String?, in claimed: DescriptionText) -> String? {
        guard let title = claimed.named(title) else { return nil }
        let wanted = EntryEvidence.foldedWords(of: title)
        let language = claimed.explainer.language

        let clauses = DescriptionClauses(sentences: claimed.sentences.map(\.raw), protecting: [wanted], language: language).sentences
        let isStated = clauses.joined().contains { clause in
            let words = clause.words
            return words.indices.contains { start in
                let after = start + wanted.count
                guard after <= words.count, words[start..<after].map(\.folded) == wanted else { return false }
                guard after == words.count || Vocabulary.isNeutral(words[after].folded, in: language) else { return false }
                var end = start
                if end > 0, EntryWording.isIndefiniteArticle(words[end - 1].folded, in: language) { end -= 1 }
                guard end > 0, isPresentFirstPersonBe(words[end - 1].accented, in: language) else { return false }
                guard !words[after...].contains(where: { isPastParticipleOfBe($0.accented, in: language) }) else { return false }
                return LeadIn.holds(words[..<end], in: language)
            }
        }
        return isStated ? title : nil
    }

    /// The present of "to be" in the first person, as `Word.accented` writes it ("I'm" is "i" and "m"). The past ("was", "ero",
    /// "war", "era", "étais", "fui") and the other persons are none: a title the person had, or another person's, is no headline.
    private static let presentFirstPersonBe: [Vocabulary.Language: Set<String>] = [
        .english: ["am", "m"], .italian: ["sono"], .german: ["bin"], .spanish: ["soy"], .french: ["suis"], .portuguese: ["sou"],
    ]

    /// The past participle of "to be" that makes a German perfect of the present "bin" ("Ich bin Bäckerin gewesen").
    private static let pastParticipleOfBe: [Vocabulary.Language: Set<String>] = [.german: ["gewesen"]]

    private static func isPresentFirstPersonBe(_ word: String, in language: Vocabulary.Language?) -> Bool {
        forms(presentFirstPersonBe, in: language).contains(word)
    }

    private static func isPastParticipleOfBe(_ word: String, in language: Vocabulary.Language?) -> Bool {
        forms(pastParticipleOfBe, in: language).contains(word)
    }

    private static func forms(_ table: [Vocabulary.Language: Set<String>], in language: Vocabulary.Language?) -> Set<String> {
        language.map { table[$0] ?? [] } ?? table.values.reduce(into: []) { $0.formUnion($1) }
    }
}
