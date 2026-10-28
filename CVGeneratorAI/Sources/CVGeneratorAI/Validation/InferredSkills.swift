import Foundation

/// The skills the model writes for the person's roles, studies and field, which the description does not name (ADR 0031). Such a
/// skill claims no fact: it has no level, and it is kept only as a plain name of a technology or a soft skill, of at most four words
/// and forty characters, that holds
/// - no digit, and no word of level, duration or seniority the description does not write ("Advanced Excel", "Senior Java");
/// - no language ("Business English"): the languages are the person's own, and the draft lists them apart;
/// - no word of a qualification ("Certified Scrum Master", "Abilitazione"), and no name of an exam or a certification ("TOEFL",
///   "Green Belt", see `QualificationNames`): a qualification is a fact;
/// - no address, link or mark-up, and no character that the reader cannot see or that reorders the text (see `SkillNameShape`);
/// - no employer, school, place or person of the draft, and no interest of it;
/// - no word that the description holds only in clauses that claim nothing for the person ("I would like to learn Kubernetes").
///
/// The draft keeps at most `caps` skills of each kind, those the description names first.
struct InferredSkills {
    /// The most skills of each kind a draft keeps: the instructions ask for 4 to 8 technologies and 3 to 5 soft skills.
    static let caps: [SkillKind: Int] = [.technology: 8, .softSkill: 5]

    private let language: Vocabulary.Language?
    private let written: WrittenText
    /// The employers, schools, places and people of the draft, as `DescriptionText.normalized` writes them.
    private let facts: [String]
    /// The interests of the draft, as `DescriptionText.normalized` writes them.
    private let interests: Set<String>

    init(_ cvData: CVData, language: Vocabulary.Language?, written: WrittenText) {
        self.language = language
        self.written = written
        let info = cvData.personalInfo
        let names: [String?] = [info.name, info.location]
            + cvData.experience.flatMap { [$0.company, $0.location] }
            + cvData.education.map(\.institution)
            + cvData.certifications.flatMap { [$0.name, $0.issuer] }
        facts = names.compactMap { $0.presentValue }.map { DescriptionText.normalized($0) }
        interests = Set(cvData.interests.compactMap { $0.presentValue }.map { DescriptionText.normalized($0) })
    }

    /// The name of the skill, trimmed, when the draft may keep it.
    func accepted(_ name: String) -> String? {
        guard let name = name.presentValue, name.count <= 40, !name.contains(where: \.isNumber), SkillNameShape.isPlain(name),
              !QualificationNames.isOne(name) else { return nil }
        let words = Word.words(in: name)
        guard !words.isEmpty, words.count <= 4 else { return nil }

        let lists = WrittenTextWords.of(language)
        let statesAFact = words.enumerated().contains { index, word in
            let previous = index > 0 ? words[index - 1].folded : nil
            let next = index + 1 < words.count ? words[index + 1].folded : nil
            return written.isAnUnstatedLevel(word.folded) || written.isExcluded(word.folded)
                || lists.isQualification(word.folded, after: previous, before: next)
                || Self.languageNames.contains(word.folded)
        }
        let normalized = DescriptionText.normalized(name)
        guard !statesAFact, !interests.contains(normalized),
              !facts.contains(where: { !DescriptionText.spans(of: $0, in: normalized).isEmpty }) else { return nil }
        return name
    }

    /// The names of the world's languages, of one word, in the six languages of the app, as `Word.folded` writes them: "english",
    /// "inglese", "englisch". A name of more words ("Swiss German") is left out, as its words are no languages ("swiss", "central").
    static let languageNames: Set<String> = {
        let displays = Vocabulary.Language.allCases.map { Locale(identifier: $0.rawValue) }
        var names = Set<String>()
        for code in Locale.LanguageCode.isoLanguageCodes {
            for display in displays {
                guard let name = display.localizedString(forLanguageCode: code.identifier), name.lowercased() != code.identifier else { continue }
                let words = Word.words(in: name)
                // A word of two letters is the code of a language, or the Italian "ci", and "CI/CD" is a skill.
                if words.count == 1, let word = words.first, word.folded.count > 2 { names.insert(word.folded) }
            }
        }
        return names
    }()
}
