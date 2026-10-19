import Foundation

/// The English words of intention that are nouns too (#202): "plan", "plans" and "planning" say an intention as verbs ("I am planning
/// to learn Rust", "I'm also planning a move", "My plan is to learn Spanish"), and name an activity as nouns ("route planning", "care
/// plans", "responsible for planning"). As nouns they are no words of the modality lists (`Vocabulary.modality`) in an English
/// description; in a description of no known language they keep their intention.
///
/// - A verb has "to", "on", an article or a possessive after it, or a subject, a form of "to be", an auxiliary or a possessive before
///   it, past the function words that are no article or preposition ("I'm also planning").
/// - Anything else before it makes it a noun: a content word ("route", "care"), an article, a preposition, or nothing at all, as in a
///   list of skills ("Skills: planning, budgeting").
enum IntentionNouns {
    private static let words: Set<String> = ["plan", "plans", "planning"]

    private static let english = Voice.words[.english] ?? Voice.everyWord

    /// What marks a verb right after the word: "planning to", "planning on", "planning a move", "planning my move".
    private static let verbAfter: Set<String> = Set(["to", "on"]).union(english.articles).union(english.possessives)
        .union(english.otherPossessives)

    /// What marks a verb before the word: "I plan", "I am planning", "I have planned", "my plan".
    private static let verbBefore: Set<String> = english.firstPerson.union(english.thirdPerson).union(english.reader)
        .union(english.possessives).union(english.otherPossessives).union(Vocabulary.english.beForms).union(Vocabulary.english.auxiliaries)

    /// Whether the word at `index` is "plan", "plans" or "planning" used as a noun.
    static func isANoun(at index: Int, in words: [Word]) -> Bool {
        guard Self.words.contains(words[index].folded) else { return false }
        if index + 1 < words.count, verbAfter.contains(words[index + 1].folded) { return false }

        for previous in words[..<index].reversed() {
            let word = previous.folded
            if verbBefore.contains(word) { return false }
            let isSkipped = Vocabulary.isNeutral(word, in: .english) && !english.articles.contains(word) && !english.prepositions.contains(word)
            if !isSkipped { return true }
        }
        return true
    }
}
