import Foundation

/// The words of intention that are nouns too (#202), read in the language of the description; in a description of no known
/// language they keep their intention. As nouns they are no words of the modality lists (`Vocabulary.modality`).
///
/// - **English** "plan", "plans" and "planning" say an intention as verbs ("I am planning to learn Rust", "I'm also planning a move",
///   "My plan is to learn Spanish"), and name an activity as nouns ("route planning", "care plans", "responsible for planning"). A verb
///   has "to", "on", an article or a possessive after it, or a subject, a form of "to be", an auxiliary or a possessive before it, past
///   the function words that are no article or preposition ("I'm also planning"). Anything else before it makes it a noun: a content
///   word ("route", "care"), an article, a preposition, or nothing at all, as in a list of skills ("Skills: planning, budgeting").
/// - **German** "plane" is the verb beside "ich" ("Ich plane, Rust zu lernen", "Nächstes Jahr plane ich"); "Plan" and "Pläne" are
///   nouns ("Ich habe einen Plan erstellt", "Pläne für 30 Baustellen"), and "Planung" is no word of intention at all. A possessive
///   before any of them, past the same function words, makes it the person's intention: "Mein Plan ist, Rust zu lernen".
enum IntentionNouns {
    private static let words: Set<String> = ["plan", "plans", "planning"]

    private static let english = Voice.words[.english] ?? Voice.everyWord

    /// What marks a verb right after the word: "planning to", "planning on", "planning a move", "planning my move".
    private static let verbAfter: Set<String> = Set(["to", "on"]).union(english.articles).union(english.possessives)
        .union(english.otherPossessives)

    /// What marks a verb before the word: "I plan", "I am planning", "I have planned", "my plan".
    private static let verbBefore: Set<String> = english.firstPerson.union(english.thirdPerson).union(english.reader)
        .union(english.possessives).union(english.otherPossessives).union(Vocabulary.english.beForms).union(Vocabulary.english.auxiliaries)

    private static let germanWords: Set<String> = ["plan", "plane"]

    private static let german = Voice.words[.german] ?? Voice.everyWord

    /// Whether the word at `index` is a word of intention used as a noun, in a description in `language`.
    static func isANoun(at index: Int, in words: [Word], language: Vocabulary.Language?) -> Bool {
        switch language {
        case .english?: isAnEnglishNoun(at: index, in: words)
        case .german?: isAGermanNoun(at: index, in: words)
        default: false
        }
    }

    private static func isAnEnglishNoun(at index: Int, in words: [Word]) -> Bool {
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

    private static func isAGermanNoun(at index: Int, in words: [Word]) -> Bool {
        let word = words[index]
        guard germanWords.contains(word.folded) else { return false }
        let isTheVerb = word.accented == "plane" && [index - 1, index + 1].contains { words.indices.contains($0) && words[$0].folded == "ich" }
        if isTheVerb { return false }

        for previous in words[..<index].reversed() {
            if german.possessives.contains(previous.accented) { return false }
            let isSkipped = Vocabulary.isNeutral(previous.folded, in: .german) && !german.articles.contains(previous.accented)
                && !german.prepositions.contains(previous.accented)
            if !isSkipped { return true }
        }
        return true
    }
}
