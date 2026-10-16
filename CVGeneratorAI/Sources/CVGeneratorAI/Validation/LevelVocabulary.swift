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
