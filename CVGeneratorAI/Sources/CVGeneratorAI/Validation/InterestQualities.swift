extension CVDataSanitizer {
    /// Whether an interest is a quality of the person at work, not a pastime (#354): a clause in which the person speaks ("sono
    /// paziente e mi piace lavorare in gruppo"), a liking of some work ("like working with the chefs"), or the words of a quality
    /// ("keep calm with the guests"). A hobby keeps the person's own things ("long walks with my dog"), and the words of planning,
    /// managing and precision, which also name pastimes ("organic gardening"), tell nothing here.
    static func isQualityAtWork(_ interest: String, in language: Vocabulary.Language?) -> Bool {
        let words = Word.words(in: interest).map(\.folded)
        let subjects = language.map { interestSubjects[$0] ?? [] } ?? interestSubjects.values.reduce(into: []) { $0.formUnion($1) }
        if words.contains(where: subjects.contains) { return true }
        if words.contains(where: likingWords.contains), words.contains(where: workWords.contains) { return true }
        let normalized = DescriptionText.normalized(interest)
        return qualityStems.contains { stem in
            stem.contains(" ") ? normalized.contains(stem) : words.contains { $0.hasPrefix(stem) }
        }
    }

    /// The words with which the person is the subject of a clause: the pronoun, and the first person of to be.
    private static let interestSubjects: [Vocabulary.Language: Set<String>] = [
        .english: ["i", "am"], .italian: ["io", "sono"], .german: ["ich", "bin"], .spanish: ["yo", "soy"],
        .french: ["je", "j", "suis"], .portuguese: ["eu", "sou"],
    ]

    /// The verbs of liking of an interest written as a clause ("like working ...", "mi piace lavorare ...").
    private static let likingWords: Set<String> = [
        "like", "love", "enjoy", "piace", "adoro", "amo", "mag", "liebe", "gusta", "encanta", "aime", "adore", "gosto",
    ]

    /// The words of working, which a pastime does not hold after a verb of liking.
    private static let workWords: Set<String> = [
        "work", "working", "lavorare", "lavoro", "arbeiten", "arbeit", "trabajar", "trabajo", "travailler", "travail", "trabalhar",
        "trabalho",
    ]

    /// The stems of the qualities at work (`softStems`), folded, without those of planning, managing and precision.
    private static let qualityStems: [String] = {
        let pastimes = ["organi", "management", "gestion", "gestao", "planung", "pianifica", "planifica", "planeja", "coordina", "koordin"]
        return softStems.map { DescriptionText.normalized($0) }.filter { stem in
            !pastimes.contains(stem) && !stem.hasPrefix("precis") && !stem.hasPrefix("prazis")
        }
    }()

    /// ADR 0031, D8: the work the person says they like doing, in their own words, as a soft skill: the words from the verb of
    /// working or collaborating right after a verb of liking to the end of its clause ("I like working closely with directors" gives
    /// "working closely with directors", "mi piace lavorare in squadra" gives "lavorare in squadra"). Any other liking stays an
    /// interest ("I like baking bread"); a wish ("I would like to work as…") and the work "as" a title give none.
    static func workLikings(in description: String) -> [String] {
        var found: [String] = []
        for sentence in SentenceSplitter.sentences(in: description) {
            let characters = Array(Digits.ascii(sentence))
            let words = Word.words(in: sentence)
            for index in words.indices where likingWords.contains(words[index].folded) {
                guard index == 0 || !wishWords.contains(words[index - 1].folded), !words[index].endsWithABreak else { continue }
                var verb = index + 1
                if verb < words.count, likingLinks.contains(words[verb].folded) { verb += 1 }
                guard verb + 1 < words.count, workingVerbs.contains(words[verb].folded), !words[verb].endsWithABreak,
                      !asWords.contains(words[verb + 1].folded) else { continue }
                var end = verb + 1
                while end + 1 < words.count, !words[end].endsWithABreak, !clauseConjunctions.contains(words[end + 1].folded) {
                    end += 1
                }
                guard end - verb + 1 <= mostSkillWords, !words[verb...end].contains(where: \.isNumber) else { continue }
                found.append(String(characters[words[verb].range.lowerBound..<words[end].range.upperBound]))
            }
        }
        return found
    }

    /// The words of working and collaborating, folded, that a liking of the work holds (ADR 0031, D8).
    private static let workingVerbs: Set<String> = [
        "work", "working", "lavorare", "arbeiten", "trabajar", "travailler", "trabalhar", "collaborate", "collaborating",
        "collaborare", "zusammenarbeiten", "colaborar", "collaborer",
    ]

    /// The words between a verb of liking and the verb it takes ("like to work", "gosto de trabalhar"), folded.
    private static let likingLinks: Set<String> = ["to", "de", "di", "a"]

    /// The words before a verb of liking that make it a wish ("I would like", "I'd like"), folded.
    private static let wishWords: Set<String> = ["would", "d", "should"]

    /// The words after a verb of working that name a title ("working as a guide"), folded: no quality.
    private static let asWords: Set<String> = ["as", "come", "als", "como", "comme"]

    /// The conjunctions that start another clause, folded.
    private static let clauseConjunctions: Set<String> = ["and", "but", "e", "ma", "und", "aber", "y", "pero", "et", "mais", "mas"]
}
