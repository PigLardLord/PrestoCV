import Foundation

/// Which words of the modality lists (`Words.modality`) withdraw a claim of the person (#202), for the skills, interests and
/// languages: "I have never used Python", "I would like to learn Spanish" and "If I had time, I would play chess" claim nothing.
///
/// Both lists below are drawn from the modality lists of their language, so they cannot drift from them (see `VocabularyTests`).
extension Vocabulary {
    /// The words of the modality lists that qualify a claim but do not withdraw it: ability ("can", "posso", "kann", "puedo", "peux")
    /// and part or most ("mostly", "partly", "teilweise", "parcialmente", "partiellement"). "I can speak French" and "I partly use
    /// Swift" claim French and Swift. They are read in all six languages, as the modality lists are.
    private static let claimQualifiersByLanguage: [Language: Set<String>] = [
        .english: ["can", "mostly", "partly", "partially"],
        .italian: ["posso", "puo", "possiamo", "possono", "parzialmente"],
        .german: ["kann", "kannst", "konnen", "koennen", "teilweise"],
        .spanish: ["puedo", "puede", "pueden", "podemos", "parcialmente"],
        .french: ["peux", "peut", "peuvent", "pouvons", "partiellement"],
        .portuguese: ["posso", "pode", "podem", "podemos", "parcialmente"],
    ]

    private static let everyClaimQualifier: Set<String> = claimQualifiersByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    /// The words of condition that open a clause and make the rest of its sentence a supposition: "If I had time, I would play
    /// chess", "Si j'avais le temps, je jouerais aux échecs".
    private static let conditionsByLanguage: [Language: Set<String>] = [
        .english: ["if", "unless"],
        .italian: ["se", "purche"],
        .german: ["wenn", "falls", "sofern"],
        .spanish: ["si"],
        .french: ["si"],
        .portuguese: ["se", "caso"],
    ]

    private static let everyCondition: Set<String> = conditionsByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    /// The relative pronouns and the subordinators that can bring another subject into a clause: what follows one of them may be that
    /// subject's ("I work with a colleague who speaks French"), and claims nothing for the person (see `RelativeClauses`).
    private static let relativesByLanguage: [Language: Set<String>] = [
        .english: ["who", "whom", "whose", "which", "that"],
        .italian: ["che", "cui"],
        .german: ["der", "die", "das", "dem", "den", "deren", "dessen", "denen", "welche", "welcher", "welches", "welchem", "welchen"],
        .spanish: ["que", "quien", "quienes", "cuyo", "cuya", "cuyos", "cuyas"],
        .french: ["qui", "que", "qu", "dont"],
        .portuguese: ["que", "quem", "cujo", "cuja", "cujos", "cujas"],
    ]

    private static let everyRelative: Set<String> = relativesByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    /// The qualifiers of each language, for the vocabulary's own tests.
    static func claimQualifiers(of language: Language) -> Set<String> {
        claimQualifiersByLanguage[language] ?? []
    }

    /// The words of condition of each language, for the vocabulary's own tests.
    static func conditions(of language: Language) -> Set<String> {
        conditionsByLanguage[language] ?? []
    }

    /// The relative pronouns and subordinators of each language, for the vocabulary's own tests.
    static func relatives(of language: Language) -> Set<String> {
        relativesByLanguage[language] ?? []
    }

    /// Whether `word` (as `DescriptionText.normalized` writes it) is a relative pronoun or a subordinator that can bring another subject
    /// into a clause, in the language of the description when it is known.
    static func isRelative(_ word: String, in language: Language?) -> Bool {
        (language.map(relatives(of:)) ?? everyRelative).contains(word)
    }

    /// The words that withdraw a claim: the words of negation, doubt, wish, future or condition (`modality`) that are no qualifier of
    /// ability or part, in any of the six languages, as the modality lists are read in all of them.
    static func withdrawals(in words: [Word], language: Language?) -> Set<String> {
        modality(in: words, language: language).subtracting(everyClaimQualifier)
    }

    /// Whether `word` (as `DescriptionText.normalized` writes it) is a word of condition that can open a clause, in the language of the
    /// description when it is known.
    static func isCondition(_ word: String, in language: Language?) -> Bool {
        (language.map(conditions(of:)) ?? everyCondition).contains(word)
    }
}
