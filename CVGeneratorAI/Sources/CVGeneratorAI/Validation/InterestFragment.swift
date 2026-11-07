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

    /// The pastime of a German interest that a conjugated verb opens and that goes on with when, where or how (#359, de-norole): the
    /// verb as its noun ("koche am Wochenende für meine Freunde" gives "Kochen", "sammle im Herbst" gives "Sammeln"), or the infinitive
    /// that "gehe" takes ("gehe gern mit meinem Hund spazieren" gives "Spazieren"). The pastime is the verb the person said, so it
    /// states nothing they did not. Nil, and the interest goes, when:
    /// - the person denies it or does it hardly ever: a word of `denials` ("koche nicht am Wochenende", "wandere selten im Winter");
    /// - the verb is no pastime of its own: an auxiliary, a form of "sein", a modal, or one of `notPastimes` ("mache", "habe");
    /// - it is no present of "ich" (no final "e");
    /// - the rest joins a second clause ("und", "oder");
    /// - a noun of the rest has no article, possessive or preposition before it: it is the verb's object, and the pastime would lose
    ///   it ("fahre am Wochenende gern Rad" is no "Fahren").
    static func germanActivity(of interest: String) -> String? {
        let text = Array(Digits.ascii(interest))
        let words = Word.words(in: interest)
        guard words.count > 1, !words.contains(where: { denials.contains($0.folded) }) else { return nil }
        let written = words.map { String(text[$0.range]) }
        let lowered = written.map { $0.lowercased() }
        let german = voice(in: .german)
        let opensANoun = german.articles.union(german.possessives).union(german.prepositions)
        guard !lowered.dropFirst().contains(where: conjunctions.contains),
              written.indices.dropFirst().allSatisfy({ written[$0].first?.isUppercase != true || opensANoun.contains(lowered[$0 - 1]) })
        else { return nil }

        let verb = lowered[0]
        if infinitiveTakers.contains(verb) {
            guard let last = written.last, written.count > 2, last.first?.isLowercase == true, last.count >= 5,
                  ["en", "ern", "eln"].contains(where: last.hasSuffix) else { return nil }
            return capitalized(last)
        }
        guard verb.count >= 4, verb.hasSuffix("e"), !notPastimes.contains(verb), !Vocabulary.isAuxiliary(verb, in: .german),
              !Vocabulary.isBeForm(verb, in: .german) else { return nil }
        let stem = String(verb.dropLast())
        if verb.hasSuffix("iere") { return capitalized(verb + "n") }
        if verb.hasSuffix("ere") { return capitalized(stem + "n") }
        if verb.hasSuffix("le"), let before = stem.dropLast().last, !"aeiouäöü".contains(before) {
            return capitalized(String(stem.dropLast()) + "eln")
        }
        return capitalized(verb + "n")
    }

    /// The verbs of "ich" that take the infinitive of the pastime last: "gehe … spazieren", "fahre … einkaufen".
    private static let infinitiveTakers: Set<String> = ["gehe", "fahre", "lerne"]

    /// The verbs of "ich" whose noun says nothing of a pastime: "Machen", "Haben", "Mögen".
    private static let notPastimes: Set<String> = [
        "mache", "habe", "mag", "liebe", "tue", "finde", "bleibe", "werde", "möchte", "verbringe", "nutze", "treffe", "helfe",
        "kann", "muss", "will", "darf", "soll",
    ]

    private static let conjunctions: Set<String> = ["und", "oder", "sowie"]

    /// The German negations, and the words that say the person does it hardly ever, as `Word.folded` writes them (review round 2).
    private static let denials = WrittenTextWords.of(.german).negations.union(["kaum", "selten", "nimmer", "nirgends", "nirgendwo"])

    private static func capitalized(_ word: String) -> String {
        word.prefix(1).uppercased() + word.dropFirst()
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
