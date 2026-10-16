import Foundation

/// The closed vocabulary of ADR 0023: short lists, one per language, of the words that explain themselves in a clause that
/// backs an entry of the CV. A word that is in none of them, and is not part of the entry's own quotes, stops the clause from
/// backing the entry, so a name, an employer or a descriptive word the description gives can never be taken for known.
///
/// A language has function words (articles, prepositions, pronouns, auxiliaries, subordinators), the verbs of a CV with their
/// inflected forms, words of time and of level, and the few words of studying and graduating. Left out on purpose, in every
/// language, are the words that change what a clause states: negations ("not", "non", "nicht", "nunca", "pas", "nao"), hedges
/// on a figure ("about", "circa", "etwa", "casi", "environ", "quase", "more than") and "without".
///
/// Every entry is written as `DescriptionText.normalized` writes a word: lower case, without accents, an elided article as a
/// word of its own. The present and past of "to be" and the auxiliaries are the exception: they are written with their accents, as
/// `Word.accented` writes a word, because French "a" (has) is no "à" (at) and Portuguese "é" (is) is no "e" (and).
enum Vocabulary {
    enum Language: String, CaseIterable, Sendable {
        case english = "en"
        case italian = "it"
        case german = "de"
        case spanish = "es"
        case french = "fr"
        case portuguese = "pt"

        /// The language a BCP 47 tag names, when it is one of the six.
        init?(tag: String) {
            guard let primary = tag.split(separator: "-").first, let language = Language(rawValue: primary.lowercased()) else { return nil }
            self = language
        }

        var words: Words {
            switch self {
            case .english: return Vocabulary.english
            case .italian: return Vocabulary.italian
            case .german: return Vocabulary.german
            case .spanish: return Vocabulary.spanish
            case .french: return Vocabulary.french
            case .portuguese: return Vocabulary.portuguese
            }
        }
    }

    /// The words of one language.
    struct Words: Sendable {
        let function: Set<String>
        /// The present and past forms of the verbs of a CV, which explain themselves and are factual. No infinitive is among them: it
        /// explains nothing and says nothing done.
        let verbs: Set<String>
        let time: Set<String>
        let level: Set<String>
        let studying: Set<String>
        /// What a pure time phrase is made of, besides years: the prepositions and adverbs of time and the conjunctions that join
        /// them ("from", "to", "since", "until", "and", "currently"; "dal", "al", "fino"; "seit", "bis", "von"). The rest of the
        /// vocabulary is not in it, because a word of it can be a name ("at", "next").
        let timePhrase: Set<String>
        /// The words of a graduation phrase that say graduating ("graduated", "laureata", "Abschluss", "diplômé").
        let graduating: Set<String>
        /// The words that go with them in a graduation phrase: "mi sono", "habe ... gemacht", "j'ai obtenu mon".
        let graduationFrame: Set<String>
        /// Words of negation, doubt or degree, wish or intention, future and condition ("never", "barely", "want", "will", "if"; "mai",
        /// "appena", "vorrei", "se"; "nie", "kaum", "möchte", "wenn"). They are in no other list: a clause that holds one backs
        /// nothing and gives no entry, and prose keeps the ones of the clause that explains it.
        let modality: Set<String>
        /// The present and past of "to be": a verb that says something done on its own ("am", "m", "was"; "sono", "era"; "bin", "war").
        /// Written as `Word.accented` writes a word, with accents: French "a" (has) is no "à" (at), and Portuguese "é" (is) no "e" (and).
        let beForms: Set<String>
        /// The auxiliaries of the perfect and of the passive: a verb that says something done when a listed form follows it in the
        /// clause ("have worked", "ho lavorato", "habe gearbeitet"). Written with accents, like `beForms`.
        let auxiliaries: Set<String>
        /// The forms of a verb that say another person than "I", in the languages that drop the pronoun ("ha lavorato", "trabajó",
        /// "trabalhou"): none for the others. Written with accents, like `beForms`; a form that is the first person too ("era") is no
        /// one of them.
        let otherPersons: Set<String>
        /// The forms of a verb that a noun can be the subject of, in the languages that drop the pronoun (the third person, and "sono",
        /// "era" that can be one): a second person ("lavori", "trabajas") is none, so the noun before it is a list item ("direzione
        /// lavori") and no subject. Written with accents, like `beForms`. None for the others.
        let thirdPersons: Set<String>
        /// The forms of everyday verbs in the third person ("ama", "vive", "joue", "lives"), as written with accents: no CV verbs, so
        /// they make nothing factual, but a noun before one of them is its subject. The device tags no verb of Italian, Spanish, French
        /// or Portuguese, and misses some in English.
        let everydayVerbs: Set<String>
        /// The words that are neither nouns nor names: the function, time, time-phrase and modality words (see `Vocabulary.isNeutral`).
        let neutral: Set<String>

        init(
            function: String, verbs: String, infinitives: String, time: String, level: String, studying: String, timePhrase: String,
            graduating: String, graduationFrame: String, beForms: String, auxiliaries: String, otherPersons: String, thirdPersons: String,
            everydayVerbs: String, modality: String
        ) {
            self.function = Self.set(of: function)
            self.verbs = Self.set(of: verbs).subtracting(Self.set(of: infinitives))
            self.time = Self.set(of: time)
            self.level = Self.set(of: level)
            self.studying = Self.set(of: studying)
            self.timePhrase = Self.set(of: timePhrase)
            self.graduating = Self.set(of: graduating)
            self.graduationFrame = Self.set(of: graduationFrame)
            self.modality = Self.set(of: modality)
            self.beForms = Self.set(of: beForms)
            self.auxiliaries = Self.set(of: auxiliaries)
            self.otherPersons = Self.set(of: otherPersons)
            self.thirdPersons = Self.set(of: thirdPersons)
            self.everydayVerbs = Self.set(of: everydayVerbs)
            neutral = self.function.union(self.time).union(self.timePhrase).union(self.modality)
        }

        var all: Set<String> { function.union(verbs).union(time).union(level).union(studying) }

        private static func set(of blob: String) -> Set<String> {
            Set(blob.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        }
    }

    /// Words that mean something else in another language, so that they are explained only when the description is in one of
    /// the languages named: Portuguese "no" is "in the", but English and Spanish "no" is a negation, and Italian "mai" is "never"
    /// where German and French "mai" is a month.
    private static let onlyIn: [String: Set<Language>] = [
        "no": [.portuguese],
        "mai": [.german, .french],
    ]

    private static let everyWord: Set<String> = union { $0.all }

    private static let everyTimePhraseWord: Set<String> = union { $0.timePhrase }

    private static let everyGraduatingWord: Set<String> = union { $0.graduating }

    private static let everyGraduationFrameWord: Set<String> = union { $0.graduationFrame }

    private static let everyVerb: Set<String> = union { $0.verbs }

    private static let everyNeutralWord: Set<String> = union { $0.neutral }

    private static let everyLevelWord: Set<String> = union { $0.level }

    /// The prepositions that introduce an employer, a school or a place of work, in the six languages ("at", "for", "with",
    /// "da", "presso", "per", "bei", "für", "en", "para", "chez", "pour", "em", "na", "no" and the like). A quote that holds one
    /// of them is about somebody's place, not about what a person did.
    static let employerPrepositions: Set<String> = Set("""
        agli ai al all alla alle allo am at au aux avec bei beim by chez com con da dagli dai dal dall dalla dalle dallo dans \
        em en for from fuer fur mit na nas no nos num numa para pela pelo per por pour presso vom von with
        """.split(whereSeparator: { $0.isWhitespace }).map(String.init))

    private static let everyModalityWord: Set<String> = union { $0.modality }

    private static let everyBeForm: Set<String> = union { $0.beForms }

    /// The words that stand before the "t" of "n't": "don't" is the words "don" and "t".
    private static let beforeNT: Set<String> = [
        "don", "doesn", "didn", "isn", "aren", "wasn", "weren", "haven", "hasn", "hadn", "won", "wouldn", "shouldn", "couldn", "can", "mustn",
        "needn", "shan",
    ]

    /// Which of the words are words of negation, doubt or degree, wish or intention, future or condition (`Words.modality`), and
    /// "n't" for a "t" after "don", "isn", "can"... Portuguese "no" is "in the", and German and French "mai" is a month.
    static func modality(in words: [Word], language: Language? = nil) -> Set<String> {
        var found = Set<String>()
        for (index, word) in words.enumerated() {
            if everyModalityWord.contains(word.folded) {
                if !(language.map { onlyIn[word.folded]?.contains($0) } == true) { found.insert(word.folded) }
            } else if word.folded == "t", index > 0, beforeNT.contains(words[index - 1].folded) {
                found.insert("n't")
            }
        }
        return found
    }

    /// The words a quote may skip to begin with its verb: "ho formato", "j'ai formé", "I have trained".
    static let leading: Set<String> = Set("""
        ai as avons ont avais avait avions avaient suis es sommes etais etait je j nous on ho ha hai abbiamo avete hanno avevo
        aveva abbiamo ero era siamo sono io noi mi ci ich wir habe haben hat hatte hatten bin sind war waren he has hemos han
        habia habian soy somos yo i we have had am was were eu tenho tem temos tinha tinhamos sou somos nos
        """.split(whereSeparator: { $0.isWhitespace }).map(String.init))

    /// Whether `word` (as `DescriptionText.normalized` writes it) is in the vocabulary, as it stands. The vocabulary lists the verbs of
    /// a CV only in their present and past forms, and a future, a wish or an infinitive is no listed form.
    ///
    /// - Parameter language: The language the description is known to be in; nil when it is not known.
    static func explains(_ word: String, in language: Language? = nil) -> Bool {
        isKnown(word, in: language, among: everyWord)
    }

    /// Whether `word` may stand in a pure time phrase, besides years.
    static func isTimePhrase(_ word: String, in language: Language? = nil) -> Bool {
        isKnown(word, in: language, among: everyTimePhraseWord)
    }

    /// Whether `word` is neither a noun nor a name: a function word, a word of time, or one of negation, doubt, wish and the like. Such
    /// a word may stand before a verb without being its subject ("the", "since", "currently", "not", "want"); the level, studying and
    /// verb words may not ("the school", "the degree"). Only the words of the language of the description count when it is known:
    /// Portuguese "março" (March) is not an Italian "Marco".
    static func isNeutral(_ word: String, in language: Language? = nil) -> Bool {
        language.map { $0.words.neutral.contains(word) } ?? everyNeutralWord.contains(word)
    }

    /// Whether `word` is a word of level ("advanced", "fortgeschritten", "native"), in the language of the description when it is
    /// known: the device tags some of them as verbs, and they are none.
    static func isLevel(_ word: String, in language: Language? = nil) -> Bool {
        language.map { $0.words.level.contains(word) } ?? everyLevelWord.contains(word)
    }

    /// Whether `word` says graduating: a graduation phrase holds one.
    static func isGraduating(_ word: String, in language: Language? = nil) -> Bool {
        isKnown(word, in: language, among: everyGraduatingWord)
    }

    /// Whether `word` goes with the words of graduating in a graduation phrase.
    static func isGraduationFrame(_ word: String, in language: Language? = nil) -> Bool {
        isKnown(word, in: language, among: everyGraduationFrameWord)
    }

    /// Whether `word` is a verb of a CV, in one of the forms the vocabulary lists: in the language of the description when it is
    /// known, because a form of one language is a preposition in another ("di", the Spanish "I gave").
    static func isVerb(_ word: String, in language: Language? = nil) -> Bool {
        isKnown(word, in: language, among: language?.words.verbs ?? everyVerb)
    }

    /// Whether `word` (as `Word.accented` writes it) is the present or the past of "to be": in the language of the description when it
    /// is known, because a form of one language is a preposition or a pronoun in another ("es", "son").
    static func isBeForm(_ word: String, in language: Language? = nil) -> Bool {
        language.map { $0.words.beForms.contains(word) } ?? everyBeForm.contains(word)
    }

    /// Whether `word` (as `Word.accented` writes it) is an auxiliary of the perfect or the passive in the language of the description. With no language it is none:
    /// French "a" (has) is a preposition in Italian, Spanish and Portuguese and an article in English, and a clause without one is
    /// read by its listed verbs alone.
    static func isAuxiliary(_ word: String, in language: Language?) -> Bool {
        language?.words.auxiliaries.contains(word) ?? false
    }

    /// Whether `word` (as `Word.accented` writes it) is a verb form that says another person than "I" in the language of the
    /// description. With no language it is none.
    static func isOtherPerson(_ word: String, in language: Language?) -> Bool {
        language?.words.otherPersons.contains(word) ?? false
    }

    /// Whether `word` (as `Word.accented` writes it) is a form of an everyday verb in the third person: not a CV verb, but one a noun
    /// before it is the subject of.
    static func isEverydayVerb(_ word: String, in language: Language?) -> Bool {
        language?.words.everydayVerbs.contains(word) ?? false
    }

    /// Whether a noun can be the subject of the verb `word` (as `Word.accented` writes it): in the languages that drop the pronoun, a
    /// form of the third person. In the others, and with no language, any verb can.
    static func canTakeANounSubject(_ word: String, in language: Language?) -> Bool {
        guard let words = language?.words, !words.thirdPersons.isEmpty else { return true }
        return words.thirdPersons.contains(word) || words.everydayVerbs.contains(word)
    }

    private static func isKnown(_ word: String, in language: Language?, among words: Set<String>) -> Bool {
        guard words.contains(word) else { return false }
        guard let only = onlyIn[word] else { return true }
        return language.map(only.contains) ?? false
    }

    private static func union(_ part: (Words) -> Set<String>) -> Set<String> {
        Language.allCases.reduce(into: Set<String>()) { $0.formUnion(part($1.words)) }
    }
}
