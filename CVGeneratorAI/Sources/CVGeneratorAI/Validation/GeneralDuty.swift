import Foundation

/// ADR 0031, D7: a sentence in which the person says, in the present and in the first person, what they do at work with no job
/// ("I rebuild the carburettors and tune the fuel pumps", "Taro le valvole e smonto i riduttori"), which goes word for word into the
/// duties of the current job (`CVDataSanitizer.generalDutyJob(among:)`).
///
/// The sentence is one of the person's own (`Grounding.ownSentences`); here it also opens with the person's verb in the present, and
/// holds no word of the past, of being or staying ("I am", "Sono"), of knowing ("Ich kenne mich mit … aus"), of liking, of speaking a language or playing, of working "as" a
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
    /// in "-o"; an English verb with no "-ed"; a French verb with no ending of the past or the future ("-ais", "-ai"); a German first
    /// person in "-e" with no "-te" of the preterite.
    ///
    /// Known limit: a German weak preterite whose stem does not end in "t" or "-ier" ("plante", "lagerte") reads as a present, because
    /// the two end alike ("warte") and no German tense tagger tells them apart.
    private static func isPresent(_ verb: String, language: Vocabulary.Language) -> Bool {
        switch language {
        case .italian, .spanish, .portuguese:
            return CVDataSanitizer.tense(of: verb, language: language) == .present
        case .english:
            return !verb.hasSuffix("ed") && !englishPast.contains(verb)
        case .french:
            // The imperfect and the conditional end in "-ais", the simple past and the future in "-ai"; the present forms in "-ais"
            // are few, and a suffix would take the imperfect of "faire" ("faisais") and of "freiner" ("freinais") for them.
            return !verb.hasSuffix("ai") && (!verb.hasSuffix("ais") || frenchPresentsInAis.contains(verb))
        case .german:
            let isPreterite = verb.hasSuffix("ierte") || (verb.hasSuffix("ete") && !germanPresentsInEte.contains(where: verb.hasSuffix))
            return verb.hasSuffix("e") && !isPreterite
        }
    }

    /// The French first persons of the present that end in "-ais", folded.
    private static let frenchPresentsInAis: Set<String> = [
        "fais", "refais", "defais", "satisfais", "vais", "reconnais", "parais", "apparais", "disparais", "plais", "tais", "hais",
    ]

    /// The endings of the German first persons of the present in "-ete" (beten, kneten, treten and its compounds), folded.
    private static let germanPresentsInEte = ["bete", "knete", "trete"]

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

    /// The words, folded, that make the sentence no duty: the past and its auxiliaries, being and staying, knowing or mastering
    /// (a skill, not a duty), liking, speaking a language, playing, and working "as" a title.
    private static let stopWords: [Vocabulary.Language: Set<String>] = [
        .english: [
            "am", "was", "were", "have", "has", "had", "did", "used", "stay", "remain", "like", "love", "enjoy", "speak", "play",
            "as", "know", "knows", "master",
        ],
        .italian: [
            "sono", "ero", "stato", "stata", "ho", "avevo", "sto", "resto", "rimango", "piace", "piacciono", "amo", "adoro", "parlo",
            "gioco", "pratico", "come", "conosco", "padroneggio",
        ],
        .german: [
            "bin", "war", "habe", "hatte", "bleibe", "mag", "liebe", "gern", "gerne", "spreche", "spiele", "als", "kenne", "weiss", "weiß", "beherrsche",
        ],
        .spanish: [
            "soy", "era", "fui", "estoy", "he", "habia", "gusta", "encanta", "hablo", "juego", "practico", "como", "conozco", "domino",
        ],
        .french: [
            "suis", "etais", "ai", "avais", "reste", "aime", "adore", "parle", "joue", "pratique", "comme", "connais", "sais", "maitrise",
        ],
        .portuguese: [
            "sou", "era", "fui", "estou", "tenho", "fico", "gosto", "adoro", "amo", "falo", "jogo", "pratico", "como", "conheco", "domino",
        ],
    ]
}
