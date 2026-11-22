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

    /// Whether a line ends a group of languages that came inside the skills and opens the skills again: a group's label
    /// (a known one, or a line naming a group of skills) that shows no language evidence. A language the lists know, a
    /// level (a CEFR one, a word of a level, a native speaker's statement) written with or without punctuation, is a
    /// language's line and stays in the languages ("Englisch gute Kenntnisse", "Gute Kenntnisse").
    static func reopensSkills(_ text: String) -> Bool {
        (isLabel(text) || namesGroupOfSkills(text)) && !showsLanguageEvidence(text)
    }

    private static func showsLanguageEvidence(_ text: String) -> Bool {
        let line = text.trimmingCharacters(in: Self.trimmed)
        if LanguageVocabulary.isNativeStatement(line) || SkillLevelWords.isLevel(line) || LanguageReader.statesCEFRLevel(line) { return true }
        let key = SectionVocabulary.key(line)
        if LanguageVocabulary.levelKeys.contains(key) { return true }
        return line.words.contains { LanguageVocabulary.isName(String($0)) }
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
