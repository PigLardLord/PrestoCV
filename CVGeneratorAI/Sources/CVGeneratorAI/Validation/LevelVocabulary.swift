/// Words by which a description states a level, in the app's six languages, written without case or accents.
///
/// A level is kept in a generated CV only if the description says it for that skill or language:
/// each group below says which levels its words allow.
struct LevelVocabulary<Level: Hashable & Sendable>: Sendable {
    /// Phrases with the levels each allows; the longest are tried first so "upper intermediate" wins over "intermediate".
    let phrases: [(phrase: String, levels: Set<Level>)]

    init(_ groups: [(levels: Set<Level>, words: [String])]) {
        var phrases: [(phrase: String, levels: Set<Level>)] = []
        for group in groups {
            for word in group.words {
                phrases.append((phrase: word, levels: group.levels))
            }
        }
        self.phrases = phrases.sorted { $0.phrase.count > $1.phrase.count }
    }
}

extension LevelVocabulary where Level == SkillLevel {
    static let skills = LevelVocabulary<SkillLevel>([
        (levels: [.beginner], words: [
            "beginner", "novice", "basic", "basics", "principiante", "elementare", "basico", "basica",
            "anfanger", "anfangerin", "grundkenntnisse", "grundlagen", "debutant", "debutante", "notions", "iniciante",
        ]),
        (levels: [.intermediate], words: [
            "intermediate", "intermedio", "intermedia", "mittelstufe", "intermediaire", "intermediario", "intermediaria",
        ]),
        (levels: [.advanced], words: [
            "advanced", "avanzato", "avanzata", "fortgeschritten", "avanzado", "avanzada", "avance", "avancee",
            "avancado", "avancada", "proficient",
        ]),
        (levels: [.expert], words: [
            "expert", "esperto", "esperta", "experte", "expertin", "experto", "experta", "especialista",
        ]),
    ])
}

extension LevelVocabulary where Level == LanguageProficiency {
    static let languages = LevelVocabulary<LanguageProficiency>([
        (levels: [.native], words: [
            "native", "native speaker", "mother tongue", "nativo", "nativa", "madrelingua", "madre lingua",
            "lingua madre", "lengua materna", "lingua materna", "muttersprache", "muttersprachler", "muttersprachlerin",
            "langue maternelle", "lingua nativa",
        ]),
        (levels: [.native, .c2], words: ["bilingual", "bilingue"]),
        (levels: [.c1, .c2], words: [
            "fluent", "fluente", "fluido", "fluida", "fliessend", "fließend", "courant", "courante",
            "advanced", "avanzato", "avanzata", "fortgeschritten", "avanzado", "avanzada", "avance", "avancee",
            "avancado", "avancada",
        ]),
        (levels: [.b2], words: [
            "upper intermediate", "upper-intermediate", "intermedio alto", "intermediaire superieur",
        ]),
        (levels: [.b1, .b2], words: [
            "intermediate", "intermedio", "intermedia", "mittelstufe", "intermediaire", "intermediario", "intermediaria",
        ]),
        (levels: [.a1, .a2], words: [
            "basic", "elementary", "beginner", "basico", "basica", "elementare", "elemental", "elementaire",
            "grundkenntnisse", "anfanger", "debutant", "notions", "iniciante",
        ]),
    ])

    /// The CEFR codes, which state a level exactly.
    static let codes: [String: LanguageProficiency] = [
        "a1": .a1, "a2": .a2, "b1": .b1, "b2": .b2, "c1": .c1, "c2": .c2,
    ]
}

/// How high a level is that a description states (#202). Denying a high level ("not an expert", "not fluent", "kein Experte")
/// implies some knowledge of the item; denying a low one ("no basic knowledge", "keine Grundkenntnisse") implies none.
enum LevelHeight: Sendable {
    case low, high

    /// The low levels, as the level vocabularies give them: a beginner's skill, an A1 or A2 language.
    private static let lowPhrases: Set<String> = Set(
        LevelVocabulary<SkillLevel>.skills.phrases.filter { $0.levels == [.beginner] }.map(\.phrase)
            + LevelVocabulary<LanguageProficiency>.languages.phrases.filter { $0.levels.isSubset(of: [.a1, .a2]) }.map(\.phrase)
            + ["a1", "a2"]
    )

    /// Every phrase of the level vocabularies, and the CEFR codes.
    static let phrases: [String] = Array(Set(
        LevelVocabulary<SkillLevel>.skills.phrases.map(\.phrase) + LevelVocabulary<LanguageProficiency>.languages.phrases.map(\.phrase)
            + LevelVocabulary<LanguageProficiency>.codes.keys
    )).sorted { $0.count > $1.count }

    /// The height of the level that a phrase of the level vocabularies states at `index` of the folded words, or nil when none
    /// starts there. The longest phrase wins: "upper intermediate" over "intermediate".
    static func ofPhrase(at index: Int, in words: [String]) -> LevelHeight? {
        for phrase in phrases {
            let parts = phrase.split(separator: " ").map(String.init)
            guard index + parts.count <= words.count, Array(words[index..<(index + parts.count)]) == parts else { continue }
            return lowPhrases.contains(phrase) ? .low : .high
        }
        return nil
    }

    /// Whether the phrase is a low level.
    static func isLow(_ phrase: String) -> Bool {
        lowPhrases.contains(phrase)
    }
}
