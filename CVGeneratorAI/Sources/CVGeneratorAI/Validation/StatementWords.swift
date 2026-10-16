/// Words that change what a sentence states, in the app's six languages, written without case or accents.
enum StatementWords {
    /// Words that start another statement about another thing, by language: Italian "ma" (but) is French "ma" (my), and Portuguese
    /// "o" is an article.
    private static let conjunctionsByLanguage: [Vocabulary.Language: Set<String>] = [
        .english: ["and", "or", "but"],
        .italian: ["e", "ed", "o", "ma"],
        .german: ["und", "oder", "aber"],
        .spanish: ["y", "e", "o", "pero"],
        .french: ["et", "ou", "mais"],
        .portuguese: ["e", "ou", "mas"],
    ]

    /// The conjunctions of every language, for a text whose language is not known.
    static let conjunctions: Set<String> = conjunctionsByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    /// Whether `word` (as `Word.accented` writes it) is a conjunction, in the language of the description when it is known.
    static func isConjunction(_ word: String, in language: Vocabulary.Language?) -> Bool {
        language.flatMap { conjunctionsByLanguage[$0] }.map { $0.contains(word) } ?? conjunctions.contains(word)
    }

    /// Negations and hedges. A level said with one of them ("not fluent", "a bit of", "hardly") is not the level.
    static let hedges: [String] = [
        // English
        "not", "no", "never", "hardly", "barely", "scarcely", "little", "bit", "somewhat", "kinda", "sorta", "almost",
        "nearly", "learning", "limited", "poor", "poorly", "without", "yet", "cannot", "neither", "nor", "none",
        "kind of", "sort of",
        // Italian
        "non", "mai", "poco", "poca", "pochi", "po", "quasi", "appena", "senza", "ancora", "imparando", "scarso",
        "scarsa", "limitato", "limitata", "nessuno", "nessuna",
        // German
        "nicht", "kein", "keine", "keinen", "keiner", "keinem", "kaum", "nie", "niemals", "bisschen", "wenig",
        "wenige", "nur", "ohne", "noch", "nichts", "lerne", "begrenzt", "schlecht",
        // Spanish
        "nunca", "jamas", "apenas", "pocos", "sin", "casi", "ningun", "ninguna", "ninguno", "todavia",
        "aprendiendo", "limitado", "limitada", "ni",
        // French
        "pas", "peu", "ne", "n", "jamais", "peine", "sans", "aucun", "aucune", "encore", "apprends", "apprenant",
        "limite", "limitee",
        // Portuguese
        "nao", "nem", "pouco", "pouca", "poucos", "nunca", "sem", "quase", "ainda", "nenhum", "nenhuma",
        "aprendendo",
    ]

    /// Words that say a thing is going on now.
    static let presents: [String] = [
        "currently", "now", "today", "present", "ongoing", "still", "to date",
        "attualmente", "oggi", "ora", "adesso", "tuttora", "ad oggi",
        "derzeit", "aktuell", "momentan", "jetzt", "heute", "bis heute",
        "actualmente", "hoy", "ahora", "hasta hoy",
        "actuellement", "maintenant", "aujourd'hui", "a ce jour",
        "atualmente", "hoje", "agora", "ate hoje", "ate agora",
    ]

    /// "Since": when it comes with a single year and nothing that ends the statement, it says the thing goes on.
    static let since: [String] = ["since", "dal", "dall", "seit", "desde", "depuis"]

    /// Words that say a thing has ended or is a former one.
    static let ends: [String] = [
        "until", "till", "formerly", "previously", "fino", "prima", "bis", "fruher", "frueher", "hasta", "antes",
        "jusqu", "avant", "ancien", "ancienne",
    ]

    /// Words that may come before a level in the clause after an item, in the app's six languages: "Swift, niveau
    /// intermédiaire", "English, at a B2 level".
    static let appositionWords: Set<String> = [
        "level", "at", "a", "an", "the", "of", "niveau", "nivel", "livello", "stufe", "di", "de", "du", "des", "auf", "im", "em", "en", "al",
    ]
}
