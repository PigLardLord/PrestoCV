import Foundation

/// Verbs the vocabulary does not list, told by their form (ADR 0023, rule (c)).
///
/// Grounding reads the verbs of English and German from the device's tags (`LexicalClasses`). It never reads those of Italian, Spanish,
/// French or Portuguese from tags, on any device and whatever assets it has, so that their rows of the contract hold everywhere. In
/// those languages a verb that is not a listed present or past form is told by its ending: an infinitive ("lavorare", "trabajar",
/// "travailler"), a future ("resterò", "quedaré", "resterai", "ficarei") or a conditional ("lavorerei", "trabajaría",
/// "travaillerais"). Endings are read from the word with its accents: the accent is what tells "lavorerò" (will work) from "numero".
enum VerbForms {
    private struct Rules {
        /// The words that introduce an infinitive.
        let markers: Set<String>
        /// The endings of an infinitive, and the fewest letters of a word that ends with one: "mar", "ver" and "per" are no infinitives.
        let infinitive: [String]
        let infinitiveLength: Int
        /// The endings of a future and of a conditional, and the fewest letters of a word that ends with one.
        let tense: [String]
        let tenseLength: Int
        /// The short irregular futures that no ending covers.
        let irregular: Set<String>
    }

    private static let rules: [Vocabulary.Language: Rules] = [
        .english: Rules(markers: ["to"], infinitive: [], infinitiveLength: 0, tense: [], tenseLength: 0, irregular: []),
        .german: Rules(markers: ["zu"], infinitive: [], infinitiveLength: 0, tense: [], tenseLength: 0, irregular: []),
        .italian: Rules(
            markers: ["a", "ad", "da", "di", "per"],
            infinitive: ["are", "ere", "ire", "arsi", "ersi", "irsi", "urre", "orre"], infinitiveLength: 6,
            tense: [
                "rò", "rà", "erai", "irai", "eremo", "iremo", "erete", "irete", "eranno", "iranno", "erei", "eresti", "ereste", "irei",
                "iresti", "ireste", "rebbe", "rebbero", "remmo",
            ],
            tenseLength: 4, irregular: []
        ),
        .spanish: Rules(
            markers: ["a", "con", "de", "para", "por"],
            infinitive: ["ar", "er", "ir", "arse", "erse", "irse"], infinitiveLength: 5,
            tense: [
                "aré", "eré", "iré", "ará", "erá", "irá", "arás", "erás", "irás", "arán", "erán", "aremos", "eremos", "iremos",
                "aréis", "eréis", "iréis", "dré", "drá", "drás", "drán", "dréis", "rré", "rrá", "rrás", "rrán",
                "aría", "arías", "aríamos", "arían", "iría", "irías", "iríamos", "irían", "dría", "drías", "dríamos", "drían",
                "rría", "rrías", "rríamos", "rrían", "sería", "serías", "seríamos", "serían",
            ],
            tenseLength: 4, irregular: ["iré", "irá", "irás", "haré", "hará", "harás", "diré", "dirá", "dirás"]
        ),
        .french: Rules(
            markers: ["a", "d", "de", "pour", "sans"],
            infinitive: ["er", "ir", "re", "oir"], infinitiveLength: 5,
            tense: [
                "erai", "eras", "era", "erons", "erez", "eront", "irai", "iras", "ira", "irons", "irez", "iront",
                "urai", "uras", "ura", "urons", "urez", "uront", "erais", "erait", "erions", "eriez", "eraient",
                "irais", "irait", "irions", "iriez", "iraient", "urais", "urait", "urions", "uriez", "uraient",
                "drais", "drait", "drions", "driez", "draient", "rrais", "rrait", "rrions", "rriez", "rraient",
            ],
            tenseLength: 6, irregular: ["sera", "serai", "seras", "aura", "aurai", "auras", "fera", "ferai", "feras", "ira", "irai", "iras"]
        ),
        .portuguese: Rules(
            markers: ["a", "com", "de", "em", "para", "por"],
            infinitive: ["ar", "er", "ir"], infinitiveLength: 5,
            tense: ["arei", "erei", "irei", "ará", "erá", "irá", "arás", "erás", "irás", "aremos", "eremos", "iremos", "arão", "irão"],
            tenseLength: 5, irregular: ["irei", "serei", "terei", "farei", "será", "terá", "fará", "serão", "terão", "farão"]
        ),
    ]

    private static let everyMarker: Set<String> = ["to", "zu"]

    /// Whether `word` (as `DescriptionText.normalized` writes it) introduces an infinitive: "to", "zu", "di", "de", "per", "para", "pour".
    static func isInfinitiveMarker(_ word: String, in language: Vocabulary.Language?) -> Bool {
        language.flatMap { rules[$0]?.markers.contains(word) } ?? everyMarker.contains(word)
    }

    /// Whether the infinitives of the language are told by their ending: in Italian, Spanish, French and Portuguese a listed form after
    /// "per" or "de" is a noun ("per lavoro"); in English and German, where the device tags verbs, a verb after "to" or "zu" is an infinitive.
    static func readsInfinitivesByEnding(in language: Vocabulary.Language?) -> Bool {
        language.flatMap { rules[$0] }.map { !$0.infinitive.isEmpty } ?? false
    }

    /// Whether grounding reads the verbs of the language from the device's tags: English and German, the languages whose rows of the
    /// contract hold with them. There a form of the vocabulary that the device does not tag as a verb is a noun ("quality control",
    /// "customer support", "team lead").
    static func readsVerbsByTags(in language: Vocabulary.Language?) -> Bool {
        language == .english || language == .german
    }

    /// Whether the word ends the way an infinitive of its language does. Only Italian, Spanish, French and Portuguese: in English
    /// and German the device tells verbs.
    static func hasInfinitiveEnding(_ word: Word, in language: Vocabulary.Language?) -> Bool {
        guard let rules = language.flatMap({ rules[$0] }), !rules.infinitive.isEmpty, word.folded.count >= rules.infinitiveLength else { return false }
        return rules.infinitive.contains { word.folded.hasSuffix($0) }
    }

    /// Whether the word is an English gerund or present participle that no form of "to be" makes finite: "reading" in "Interests: reading",
    /// "solving" in "problem solving", not "looking" in "I'm looking". The device tags such words as verbs, and a list of interests or
    /// skills has no verb for a subject to go with. The other languages have no such word to tell: the device tags no verb in them.
    static func isBareGerund(_ word: Word, after previous: Word?, in language: Vocabulary.Language?) -> Bool {
        guard language == .english, word.folded.count > 5, word.folded.hasSuffix("ing") else { return false }
        return !(previous.map { Vocabulary.isBeForm($0.accented, in: language) } ?? false)
    }

    /// Whether the word ends the way a future or a conditional of its language does.
    static func hasTenseEnding(_ word: Word, in language: Vocabulary.Language?) -> Bool {
        guard let rules = language.flatMap({ rules[$0] }), !rules.tense.isEmpty else { return false }
        if rules.irregular.contains(word.accented) { return true }
        return word.accented.count >= rules.tenseLength && rules.tense.contains { word.accented.hasSuffix($0) }
    }
}
