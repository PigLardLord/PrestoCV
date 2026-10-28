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
}
