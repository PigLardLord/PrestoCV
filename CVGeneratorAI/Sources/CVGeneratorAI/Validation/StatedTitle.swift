import Foundation

/// A title the person states as what they are (#354): "I am a plumber", "Sono uno sviluppatore iOS", "Ich bin Bäckerin", "Soy
/// camarero", "Je suis comptable", "Sou motorista de caminhão".
///
/// The model sometimes writes such a title as a job with no employer and no date, which the sanitiser drops (ADR 0023 (c)): a title
/// alone is no job. The title is still the person's headline when a clause that claims it says it in this shape: the lead-in of a
/// quote at the start of the clause (`LeadIn`: nothing, or "I", "where I", "io"...) ending in the present of "to be" in the first
/// person ("am", "sono", "bin", "soy", "suis", "sou"), then at most an indefinite article, then the title, then the end of the
/// sentence or "and" and a clause of the person: one that opens with "I" ("I am a plumber and I fix pipes"), or, in the languages that
/// drop the pronoun, with a verb in the first person ("Sono uno sviluppatore iOS e scrivo", "Ich bin Bäckerin und backe": `opensWithAVerbOfI`).
/// "I like long walks", "I want to be a nurse", "I am not a nurse", "My mother is a nurse", "I'm looking for a job as a nurse" and "I am
/// a nurse assistant" state no "nurse"; "I was a nurse", "J'étais étudiant en 2015" and "Ich bin Bäckerin gewesen" state a title the
/// person had. A word after the title can make it no role the person holds ("Je suis médecin dans un jeu vidéo", "I am a nurse, but only
/// in a game", "Sono infermiere e soltanto in un videogioco"), so nothing but "and" and a clause of the person may follow it in its
/// sentence: "I am a nurse in Leeds" gives no headline either, the safe way to fail. What follows the title is read in the sentence as
/// the person wrote it, not as the claimed clauses leave it: they leave out a clause that denies ("I am a nurse, but not in real life"),
/// and the title would end its sentence there.
enum StatedTitle {
    /// `title` when a sentence states it as above both in `claimed`, the clauses that claim something for the person, and in `source`,
    /// the description as written, sentence by sentence (`claimed` keeps one sentence for each of `source`); otherwise nil.
    static func title(_ title: String?, in claimed: DescriptionText, said source: DescriptionText) -> String? {
        guard let title = claimed.named(title), claimed.sentences.count == source.sentences.count else { return nil }
        let wanted = EntryEvidence.foldedWords(of: title)
        let language = claimed.explainer.language

        let isStated = claimed.sentences.indices.contains { index in
            states(wanted, in: claimed.sentences[index].raw, language: language)
                && states(wanted, in: source.sentences[index].raw, language: language)
        }
        return isStated ? title : nil
    }

    /// Whether a clause of `sentence` says the title as above, with nothing after it in the sentence but "and" and a clause of the person.
    private static func states(_ wanted: [String], in sentence: String, language: Vocabulary.Language?) -> Bool {
        let clauses = DescriptionClauses(sentences: [sentence], protecting: [wanted], language: language).sentences.first ?? []
        return clauses.indices.contains { index in
            let words = clauses[index].words
            guard words.count >= wanted.count, words.suffix(wanted.count).map(\.folded) == wanted else { return false }
            let endsTheSentence = index == clauses.count - 1
            guard endsTheSentence || (endsWithAnd(clauses[index], in: language) && isOfThePerson(clauses[index + 1], in: language)) else {
                return false
            }
            return isSaid(before: words.count - wanted.count, in: words, language: language)
        }
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

    /// Whether the clause after "and" is the person's own claim: it opens with the first-person pronoun ("I fix pipes"), or with a verb
    /// in the first person where the pronoun is dropped. "Only in a video game" is a qualifier, which may say the role is not the person's.
    /// A clause that holds a negation or a word that limits ("not", "only", "nur", "solo", "apenas") anywhere may say so too, after an
    /// adverb that reads like a verb ("und bedauerlicherweise nur in einem Videospiel"): it is no claim, the safe way to fail.
    private static func isOfThePerson(_ clause: Clause, in language: Vocabulary.Language?) -> Bool {
        guard let first = clause.words.first else { return false }
        let denials = WrittenTextWords.of(language).negations.union(language.flatMap { limiters[$0] } ?? [])
        guard !clause.words.contains(where: { denials.contains($0.folded) }) else { return false }
        return forms(firstPersonPronouns, in: language).contains(first.folded) || opensWithAVerbOfI(clause, in: language)
    }

    /// Words that limit what comes before to a part of it, as `Word.folded` writes them, beside the negations of `WrittenTextWords`.
    private static let limiters: [Vocabulary.Language: Set<String>] = [
        .english: ["only", "just", "merely", "solely"],
        .italian: ["solo", "soltanto", "solamente", "unicamente", "appena", "neanche", "neppure", "nemmeno"],
        .spanish: ["solo", "solamente", "unicamente", "apenas", "tampoco"],
        .portuguese: ["so", "apenas", "somente", "unicamente", "tampouco"],
        .german: ["nur", "lediglich", "bloss", "bloß", "ausschliesslich", "ausschließlich", "kaum"],
        .french: ["seulement", "uniquement"],
    ]

    /// Whether the clause opens with a verb in the first person of the present, in a language that drops the pronoun after "and"
    /// (#354): a word written in lower case of at least 4 letters with the ending of that person ("scrivo", "atiendo", "faço",
    /// "backe"), and none of the words with that ending that qualify the title or start a phrase ("solo", "soltanto", "tampoco", "não",
    /// "keine", "alleine"). German writes its nouns with a capital, so "und Mutter" is no verb. English and French keep the pronoun,
    /// and a description of no known language has no ending to read: no verb there.
    private static func opensWithAVerbOfI(_ clause: Clause, in language: Vocabulary.Language?) -> Bool {
        guard let language, let ending = firstPersonPresentEndings[language],
              let first = Word.words(in: clause.source).first, !first.isNumber else { return false }
        let written = Array(Digits.ascii(clause.source))
        guard written.indices.contains(first.range.lowerBound), written[first.range.lowerBound].isLowercase else { return false }
        return first.folded.count >= 4 && first.folded.hasSuffix(ending) && !(notVerbs[language]?.contains(first.folded) ?? false)
            && !(adverbEndings[language] ?? []).contains { first.folded.count > $0.count && first.folded.hasSuffix($0) }
    }

    /// The endings of a family of adverbs that grows with each word, longer than the ending itself: German "bedauerlicherweise",
    /// "normalerweise", "mittlerweile". A closed list cannot hold them.
    private static let adverbEndings: [Vocabulary.Language: [String]] = [.german: ["weise", "weile"]]

    /// The ending of the first person of the present, as `Word.folded` writes it, in the languages that drop the pronoun.
    private static let firstPersonPresentEndings: [Vocabulary.Language: String] = [
        .italian: "o", .spanish: "o", .portuguese: "o", .german: "e",
    ]

    /// Words of at least 4 letters with that ending that are no verb, as `Word.folded` writes them: the ones that qualify what comes
    /// before ("solo", "soltanto", "nemmeno", "tampoco", "keine", "alleine"), and the common ones that start a phrase ("quando",
    /// "como", "questo", "meine", "diese").
    private static let notVerbs: [Vocabulary.Language: Set<String>] = [
        .italian: [
            "solo", "soltanto", "pero", "percio", "tanto", "quanto", "poco", "molto", "troppo", "spesso", "quando", "questo",
            "quello", "tutto", "proprio", "certo", "mezzo", "ovvio", "davvero", "almeno", "nemmeno", "nello", "dello", "dallo",
            "sullo", "dopo", "dentro", "sotto", "verso", "presso", "secondo", "intorno", "accanto", "nessuno", "qualcuno",
            "ciascuno", "ognuno", "altro", "primo", "ultimo", "nuovo", "vecchio", "lungo", "anzitutto", "soprattutto",
        ],
        .spanish: [
            "solo", "tampoco", "pero", "como", "mucho", "poco", "todo", "tanto", "cuanto", "luego", "medio", "cuando", "claro",
            "mismo", "demasiado", "algo", "ello", "esto", "aquello", "dentro", "ninguno", "alguno", "otro", "primero", "ultimo",
            "nuevo", "incluso", "debajo",
        ],
        .portuguese: [
            "como", "muito", "pouco", "todo", "tanto", "quanto", "quando", "claro", "certo", "mesmo", "logo", "isso", "isto",
            "aquilo", "pelo", "dentro", "nisso", "disso", "nisto", "disto", "outro", "primeiro", "ultimo", "novo", "sobretudo",
            "tampouco",
        ],
        .german: [
            "eine", "keine", "meine", "deine", "seine", "ihre", "unsere", "eure", "diese", "jene", "jede", "welche", "manche",
            "alle", "beide", "solche", "gerne", "ohne", "alleine", "nahe", "lange", "heute", "ganze", "einige", "mehrere",
            "andere", "viele", "wenige", "gerade",
        ],
    ]


    /// The present of "to be" in the first person, as `Word.accented` writes it ("I'm" is "i" and "m"). The past ("was", "ero",
    /// "war", "era", "étais", "fui") and the other persons are none: a title the person had, or another person's, is no headline.
    private static let presentFirstPersonBe: [Vocabulary.Language: Set<String>] = [
        .english: ["am", "m"], .italian: ["sono"], .german: ["bin"], .spanish: ["soy"], .french: ["suis"], .portuguese: ["sou"],
    ]

    /// The first-person subject pronouns, as `Word.folded` writes them ("j'" is "j").
    private static let firstPersonPronouns: [Vocabulary.Language: Set<String>] = [
        .english: ["i"], .italian: ["io"], .german: ["ich"], .spanish: ["yo"], .french: ["je", "j"], .portuguese: ["eu"],
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
