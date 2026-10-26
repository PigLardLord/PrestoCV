import Foundation

/// What explains a word of the description: the closed vocabulary, in the forms it lists.
struct Explainer {
    let language: Vocabulary.Language?

    /// A number is explained: what it counts must be.
    func explains(_ word: Word) -> Bool {
        word.isNumber || Vocabulary.explains(word.folded, in: language)
    }

    /// Whether the word may stand in a pure time phrase: a year or a number, or a word of the time-phrase list.
    func isTimePhrase(_ word: Word) -> Bool {
        word.isNumber || Vocabulary.isTimePhrase(word.folded, in: language)
    }

    /// Whether the word says graduating or completing a course.
    func saysGraduating(_ word: Word) -> Bool {
        Vocabulary.isGraduating(word.folded, in: language)
    }

    /// Whether the words are a graduation phrase: a time phrase that also holds words of graduating and the words that go with
    /// them, and at least one word of graduating.
    func isGraduationPhrase(_ words: [Word]) -> Bool {
        isGraduationPhrase(folded: words.map(\.folded))
    }

    /// The same for the folded words of a quote: a number is a year or a count, and stands in a time phrase.
    func isGraduationPhrase(folded words: [String]) -> Bool {
        words.contains { Vocabulary.isGraduating($0, in: language) }
            && words.allSatisfy { word in
                word.allSatisfy(\.isNumber) || Vocabulary.isTimePhrase(word, in: language)
                    || Vocabulary.isGraduating(word, in: language) || Vocabulary.isGraduationFrame(word, in: language)
            }
    }

    func isVerb(_ word: String) -> Bool {
        Vocabulary.isVerb(word, in: language)
    }
}
