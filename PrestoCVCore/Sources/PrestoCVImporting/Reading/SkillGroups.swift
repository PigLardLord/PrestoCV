import Foundation

/// The labels that group the lines of a skills section: "Qualities", "Soft skill", "Trade skills". A group's label is
/// structure, not a skill, and one that names a group of skills ends a section of languages the group came after (#305).
enum SkillGroups {

    /// Whether a line alone is the label of a group of qualities or of the rest of a list, as the vocabulary knows them.
    static func isLabel(_ text: String) -> Bool {
        labels.contains(SectionVocabulary.key(text.trimmingCharacters(in: Self.trimmed)))
    }

    /// Whether a short line names a group of skills by one of the words for skills at its start or its end ("Trade
    /// skills", "Competenze di mestiere"). No digit, no punctuation or dash inside ("Englisch – gute Kenntnisse" is a language's level), at most `maximumWords` words.
    static func namesGroupOfSkills(_ text: String) -> Bool {
        let line = text.trimmingCharacters(in: Self.trimmed)
        guard !line.isEmpty, !line.contains(where: { $0.isNumber || ",;:.|/()[]–—-".contains($0) }),
              line.words.count >= 2, line.words.count <= maximumWords else { return false }
        let words = SectionVocabulary.key(line).split(separator: " ").map(String.init)
        guard let first = words.first, let last = words.last else { return false }
        return skillsWords.contains(first) || skillsWords.contains(last)
    }

    private static let maximumWords = 3
    private static let trimmed = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-–•"))

    /// The words for skills, in the six languages.
    private static let skillsWords: Set<String> = Set([
        "skills", "skill", "competencies", "competences",
        "competenze", "competenza", "abilità",
        "kenntnisse", "fähigkeiten", "kompetenzen", "skills",
        "habilidades", "competencias", "destrezas",
        "compétences", "aptitudes",
        "competências", "habilidades",
    ].map(SectionVocabulary.key))

    /// The labels that group qualities and the rest, by language.
    private static let labels: Set<String> = Set([
        // English
        "qualities", "personal qualities", "strengths", "key strengths", "soft skill", "other", "others", "miscellaneous", "personal traits",
        // Italiano
        "qualità", "qualità personali", "punti di forza", "altro", "altri", "altre", "varie", "soft skill",
        // Deutsch
        "eigenschaften", "persönliche eigenschaften", "stärken", "sonstiges", "weitere", "weiteres", "sonstige", "soft skill",
        // Español
        "cualidades", "cualidades personales", "fortalezas", "otros", "otras", "otro", "varios",
        // Français
        "qualités", "qualités personnelles", "points forts", "autres", "autre", "divers",
        // Português
        "qualidades", "qualidades pessoais", "pontos fortes", "outros", "outras", "outro", "diversos",
    ].map(SectionVocabulary.key))
}
