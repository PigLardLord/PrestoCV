import Foundation

/// ADR 0031, D7: a sentence in which the person says, in the present and in the first person, what they do at work with no job
/// ("I rebuild the carburettors and tune the fuel pumps", "Taro le valvole e smonto i riduttori"), which goes word for word into the
/// duties of the current job (`CVDataSanitizer.generalDutyJob(among:)`).
///
/// The sentence is one of the person's own (`Grounding.ownSentences`); here it also opens with the person's verb in the present, and
/// holds no word of the past, of being or staying ("I am", "Sono"), of liking, of speaking a language or playing, of working "as" a
/// title, of a quality at work, and no number, month, duration, negation or qualification (`WrittenTextWords`): those stay where
/// their own rules put them, as qualities, interests, languages or the person's title.
enum GeneralDuty {
    static func holds(_ sentence: String, language: Vocabulary.Language?) -> Bool {
        guard let language else { return false }
        var words = Word.words(in: sentence)
        guard let first = words.first?.folded else { return false }
        if pronouns[language]?.contains(first) == true {
            words.removeFirst()
        } else if requiresPronoun.contains(language) {
            return false
        }
        guard let verb = words.first?.folded, verb.count > 1, !words.isEmpty else { return false }
        let folded = words.map(\.folded)
        let lists = WrittenTextWords.of(language)
        let excluded = stopWords[language] ?? []
        guard !words.contains(where: \.isNumber),
              !folded.contains(where: { excluded.contains($0) || lists.isNumber($0) || lists.months.contains($0) }),
              !folded.contains(where: { lists.seniority.contains($0) || lists.negations.contains($0) || lists.qualifications.contains($0) }),
              !CVDataSanitizer.holdsAQualityAtWork(sentence),
              isPresent(verb, language: language) else { return false }
        return true
    }

    /// Whether `verb`, the sentence's first word after the pronoun, is in the present: an Italian, Spanish or Portuguese first person
    /// in "-o"; an English verb with no "-ed"; any other one that is no auxiliary of the past (`stopWords`).
    private static func isPresent(_ verb: String, language: Vocabulary.Language) -> Bool {
        switch language {
        case .italian, .spanish, .portuguese:
            return CVDataSanitizer.tense(of: verb, language: language) == .present
        case .english:
            return !verb.hasSuffix("ed") && !englishPast.contains(verb)
        case .german, .french:
            return true
        }
    }

    /// The English past forms with no "-ed" that a duty opens with most, folded.
    private static let englishPast: Set<String> = [
        "built", "rebuilt", "ran", "led", "made", "wrote", "taught", "kept", "drove", "sold", "bought", "took", "gave", "brought",
        "found", "held", "met", "sent", "spent", "won", "went", "did", "fixed", "dealt", "oversaw", "drew", "ate", "began", "grew",
    ]

    /// The first-person pronouns, folded.
    private static let pronouns: [Vocabulary.Language: Set<String>] = [
        .english: ["i"], .italian: ["io"], .german: ["ich"], .spanish: ["yo"], .french: ["je", "j"], .portuguese: ["eu"],
    ]

    /// The languages whose sentences keep the subject pronoun.
    private static let requiresPronoun: Set<Vocabulary.Language> = [.english, .german, .french]

    /// The words, folded, that make the sentence no duty: the past and its auxiliaries, being and staying, liking, speaking a
    /// language, playing, and working "as" a title.
    private static let stopWords: [Vocabulary.Language: Set<String>] = [
        .english: [
            "am", "was", "were", "have", "has", "had", "did", "used", "stay", "remain", "like", "love", "enjoy", "speak", "play",
            "as",
        ],
        .italian: [
            "sono", "ero", "stato", "stata", "ho", "avevo", "sto", "resto", "rimango", "piace", "piacciono", "amo", "adoro", "parlo",
            "gioco", "pratico", "come",
        ],
        .german: [
            "bin", "war", "habe", "hatte", "bleibe", "mag", "liebe", "gern", "gerne", "spreche", "spiele", "als",
        ],
        .spanish: [
            "soy", "era", "fui", "estoy", "he", "habia", "gusta", "encanta", "hablo", "juego", "practico", "como",
        ],
        .french: [
            "suis", "etais", "ai", "avais", "reste", "aime", "adore", "parle", "joue", "pratique", "comme",
        ],
        .portuguese: [
            "sou", "era", "fui", "estou", "tenho", "fico", "gosto", "adoro", "amo", "falo", "jogo", "pratico", "como",
        ],
    ]
}
