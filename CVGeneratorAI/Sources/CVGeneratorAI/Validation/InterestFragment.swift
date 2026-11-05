import Foundation

/// Whether an interest the draft quotes is a piece of a clause, no hobby (#359). The description holds it word for word, so it passes
/// the quote check: "Wandern in den" of "Wandern in den Bergen", "am Wochenende für meine Freunde" of "koche am Wochenende für meine
/// Freunde". By rules, with the articles and prepositions `Voice` reads a subject by:
///
/// - An interest that ends on an article or a preposition ("hiking in the", "la randonnée dans les") lacks its noun. A particle that
///   ends an English phrasal verb ("working out") is none of them.
/// - What is left of a conjugated verb's clause is a hobby only when it starts, past its articles, with its noun ("spiele das Klavier"
///   gives "Klavier"). A rest that starts with a preposition ("am Wochenende für meine Freunde", "in den Bergen") or an adverb ("gern
///   mit meinem Hund spazieren") tells when, where or how, and is no hobby.
enum InterestFragment {
    /// The particles of an English phrasal verb: "working out", "hanging around".
    private static let particles: Set<String> = ["out", "off", "up", "down", "over", "around", "along", "through"]

    /// Whether `interest` ends on an article or a preposition, written in lower case ("D&D" and "Plan B" do not).
    static func endsOnALinkWord(_ interest: String, in language: Vocabulary.Language?) -> Bool {
        guard let last = Word.words(in: interest).last, Array(Digits.ascii(interest))[last.range.lowerBound].isLowercase else { return false }
        return !particles.contains(last.accented) && (articles(in: language).contains(last.accented) || linkWords(in: language).contains(last.accented))
    }

    /// `words` without the articles they start with.
    static func withoutArticles(_ words: ArraySlice<Word>, in language: Vocabulary.Language) -> ArraySlice<Word> {
        words.drop { articles(in: language).contains($0.accented) }
    }

    /// Whether `word` of `interest`, which starts what a conjugated verb leaves, is a preposition or an adverb.
    static func tellsHowOrWhere(_ word: Word, in interest: String, language: Vocabulary.Language) -> Bool {
        if linkWords(in: language).contains(word.accented) { return true }
        let written = String(Array(Digits.ascii(interest))[word.range])
        switch language {
        case .german: return CVDataSanitizer.isGermanAdverb(written)
        case .english: return written.count > 4 && written.hasSuffix("ly")
        case .italian, .spanish, .french, .portuguese: return false
        }
    }

    private static func voice(in language: Vocabulary.Language?) -> Voice.Words {
        language.flatMap { Voice.words[$0] } ?? Voice.everyWord
    }

    private static func articles(in language: Vocabulary.Language?) -> Set<String> {
        voice(in: language).articles
    }

    /// The prepositions, simple and written out ("de", "do", "dans", "per"), but for the articles and possessives that share a form.
    private static func linkWords(in language: Vocabulary.Language?) -> Set<String> {
        let words = voice(in: language)
        return words.prepositions.union(words.nounSigns).subtracting(words.possessives).subtracting(words.articles)
    }
}
