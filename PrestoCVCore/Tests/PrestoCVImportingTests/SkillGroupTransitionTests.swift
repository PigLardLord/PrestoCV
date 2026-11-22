import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// After a skills section and a group called "Languages", a line that is a group label reopens the skills, and one that
/// states a language or a level stays in the languages, whatever its punctuation (#305). Every CV here is invented.
@Suite("Where a group of languages inside the skills ends")
struct SkillGroupTransitionTests {

    /// The words of one language of the CV: the headings, the skill listed first, the first language, and the lines that
    /// follow it, a skill and another language.
    struct Words: Sendable {
        let skills: String
        let languages: String
        let trade: String
        let firstLanguage: String
        let skillAfter: String
        let languageAfter: String
    }

    static let english = Words(skills: "Skills", languages: "Languages", trade: "Welding", firstLanguage: "Spanish", skillAfter: "Punctuality", languageAfter: "German")
    static let german = Words(skills: "Fähigkeiten", languages: "Sprachen", trade: "Schweißen", firstLanguage: "Deutsch", skillAfter: "Pünktlichkeit", languageAfter: "Spanisch")
    static let italian = Words(skills: "Competenze", languages: "Lingue", trade: "Saldatura", firstLanguage: "Italiano", skillAfter: "Puntualità", languageAfter: "Tedesco")
    static let spanish = Words(skills: "Habilidades", languages: "Idiomas", trade: "Soldadura", firstLanguage: "Español", skillAfter: "Puntualidad", languageAfter: "Alemán")
    static let french = Words(skills: "Compétences", languages: "Langues", trade: "Soudure", firstLanguage: "Français", skillAfter: "Ponctualité", languageAfter: "Allemand")

    /// A line after the first language, in the language of the CV, and whether it opens the skills again.
    static let lines: [(Words, String, Bool)] = [
        // The labels that group qualities and the rest, and a line naming a group of skills
        (english, "Qualities", true), (english, "Other", true), (english, "Soft Skill", true), (english, "Trade skills", true),
        (german, "Eigenschaften", true), (german, "Handwerkliche Kenntnisse", true),
        (italian, "Qualità", true), (italian, "Altro", true), (italian, "Competenze di mestiere", true),
        (spanish, "Cualidades", true), (spanish, "Habilidades de oficio", true),
        (french, "Qualités", true), (french, "Autres", true), (french, "Compétences de métier", true),
        // A group's label that holds a language name is still a group of skills, and names no language
        (english, "Spanish cooking skills", true), (german, "Englisch Kompetenzen", true), (german, "Französisch Fähigkeiten", true),
        (italian, "Competenze di inglese", true), (spanish, "Habilidades de inglés", true), (french, "Compétences en anglais", true),
        // A language with its level, written without punctuation, after a dash, after a colon, or as a CEFR level
        (english, "Spanish fluent", false), (french, "Français C1", false), (english, "French fluent", false), (english, "French – fluent", false), (english, "French: fluent", false), (english, "French B2", false),
        (german, "Englisch gute Kenntnisse", false), (german, "Englisch – gute Kenntnisse", false),
        (german, "Englisch: gute Kenntnisse", false), (german, "Französisch C1", false),
        (italian, "Inglese buono", false), (italian, "Inglese – ottimo", false), (italian, "Inglese: B2", false), (italian, "Inglese madrelingua", false),
        (spanish, "Inglés nivel alto", false), (spanish, "Inglés – avanzado", false), (spanish, "Inglés: C1", false),
        (french, "Anglais courant", false), (french, "Anglais – bilingue", false), (french, "Anglais: B2", false),
        // A level on its own, which is the level of the language above it
        (english, "Fluent", false), (english, "C1", false), (english, "Native", false),
        (german, "Gute Kenntnisse", false), (german, "Sehr gute Kenntnisse", false), (german, "Muttersprache", false),
        (italian, "Madrelingua", false), (italian, "Ottimo", false), (spanish, "Nivel alto", false), (french, "Courant", false),
    ]

    private func imported(_ words: Words, line: String, after: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText("""
        \(words.skills)
        \(words.trade)
        \(words.languages)
        \(words.firstLanguage)
        \(line)
        \(after)
        """)
    }

    @Test("A line after a group called Languages reopens the skills only when it is a group label without language evidence", arguments: lines)
    func transition(words: Words, line: String, reopensTheSkills: Bool) throws {
        if reopensTheSkills {
            let found = try imported(words, line: line, after: words.skillAfter)
            #expect(found.cv.skills.map(\.value) == [words.trade, words.skillAfter], "\(line)")
            #expect(found.cv.languages.map(\.name.value) == [words.firstLanguage], "\(line)")
        } else {
            let found = try imported(words, line: line, after: words.languageAfter)
            #expect(found.cv.skills.map(\.value) == [words.trade], "\(line)")
            #expect(found.cv.languages.map(\.name.value).last == words.languageAfter, "\(line)")
            #expect(found.cv.languages.map(\.name.value).first == words.firstLanguage, "\(line)")
        }
    }

    @Test("A group label that holds a language name keeps the skills after it and invents no language")
    func labelWithLanguageName() throws {
        let found = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText("""
        Skills
        Welding
        Languages
        German
        Spanish cooking skills
        Paella preparation
        """)
        #expect(found.cv.skills.map(\.value) == ["Welding", "Paella preparation"])
        #expect(found.cv.languages.map(\.name.value) == ["German"])
    }
}
