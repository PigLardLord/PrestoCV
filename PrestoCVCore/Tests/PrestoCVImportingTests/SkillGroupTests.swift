import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// The group labels of a skills section ("Qualities", "Trade skills") are structure, not skills, and a group called
/// "Languages" does not end the section (#305).
@Suite("Group labels inside a skills section")
struct SkillGroupTests {

    private func importer() -> ImportCV {
        ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
    }

    private func skillValues(_ text: String) throws -> [String] {
        try importer().importText(text).cv.skills.map(\.value)
    }

    @Test("A known group label of qualities is left out as a label, in the six languages", arguments: [
        ("Skills", "Qualities", "Punctuality", "Teamwork", "Pipe fitting", "Welding"),
        ("Skills", "Soft Skill", "Punctuality", "Teamwork", "Pipe fitting", "Welding"),
        ("Skills", "Other", "Punctuality", "Teamwork", "Pipe fitting", "Welding"),
        ("Competenze", "Qualità", "Puntualità", "Lavoro di squadra", "Saldatura", "Posa di tubi"),
        ("Kenntnisse", "Eigenschaften", "Pünktlichkeit", "Teamarbeit", "Schweißen", "Rohrleitungsbau"),
        ("Habilidades", "Cualidades", "Puntualidad", "Trabajo en equipo", "Soldadura", "Montaje de tuberías"),
        ("Compétences", "Qualités", "Ponctualité", "Travail en équipe", "Soudure", "Tuyauterie"),
        ("Competências", "Qualidades", "Pontualidade", "Trabalho em equipa", "Soldadura", "Montagem de tubos"),
    ] as [(String, String, String, String, String, String)])
    func qualities(heading: String, label: String, first: String, second: String, trade: String, tradeTwo: String) throws {
        let result = try importer().importText("""
        Alex Example
        Welder

        \(heading)
        \(tradeTwo)
        \(trade)
        \(label)
        \(first)
        \(second)
        """)
        #expect(result.cv.skills.map(\.value) == [tradeTwo, trade, first, second])
        #expect(result.leftOut.map(\.reason) == [.categoryLabel])
        #expect(result.unplaced.isEmpty)
    }

    @Test("The invented example of the issue: a label of qualities between two runs of skills")
    func issueExampleQualities() throws {
        #expect(try skillValues("""
        Skills
        Welding
        Pipe fitting
        Qualities
        Punctuality
        Teamwork
        """) == ["Welding", "Pipe fitting", "Punctuality", "Teamwork"])
    }

    @Test("A skill that only starts with a label word stays a skill")
    func labelWordInASkill() throws {
        #expect(try skillValues("""
        Skills
        Qualities control
        Other tools
        Welding
        """) == ["Qualities control", "Other tools", "Welding"])
    }

    @Test("A group called Languages, then a group of skills, does not end the skills section")
    func languagesGroupThenSkills() throws {
        let result = try importer().importText("""
        Skills
        Languages
        Spanish
        English
        Trade skills
        Welding
        Pipe fitting
        """)
        #expect(result.cv.skills.map(\.value) == ["Welding", "Pipe fitting"])
        #expect(result.cv.languages.map(\.name.value) == ["Spanish", "English"])
        #expect(result.unplaced.isEmpty)
    }

    @Test("A group called Languages, then a group of skills, in the six languages", arguments: [
        ("Competenze", "Lingue", "Italiano", "Inglese", "Competenze di mestiere", "Saldatura"),
        ("Kenntnisse", "Sprachen", "Deutsch", "Englisch", "Handwerkliche Kenntnisse", "Schweißen"),
        ("Habilidades", "Idiomas", "Español", "Inglés", "Habilidades de oficio", "Soldadura"),
        ("Compétences", "Langues", "Français", "Anglais", "Compétences de métier", "Soudure"),
        ("Competências", "Idiomas", "Português", "Inglês", "Competências de ofício", "Soldadura"),
    ] as [(String, String, String, String, String, String)])
    func languagesGroupInOtherLanguages(
        skills: String, languages: String, first: String, second: String, group: String, skill: String
    ) throws {
        let result = try importer().importText("""
        \(skills)
        \(languages)
        \(first)
        \(second)
        \(group)
        \(skill)
        """)
        #expect(result.cv.skills.map(\.value) == [skill])
        #expect(result.cv.languages.map(\.name.value) == [first, second])
        #expect(result.unplaced.isEmpty)
    }

    @Test("A real Languages section after the skills stays a languages section")
    func realLanguagesSection() throws {
        let result = try importer().importText("""
        Alex Example
        Welder

        Skills
        Welding
        Pipe fitting

        Languages
        Spanish
        English
        """)
        #expect(result.cv.skills.map(\.value) == ["Welding", "Pipe fitting"])
        #expect(result.cv.languages.map(\.name.value) == ["Spanish", "English"])
        #expect(result.unplaced.isEmpty)
    }

    @Test("A real Languages section whose last line is not a group of skills keeps its lines")
    func realLanguagesSectionWithAnotherLine() throws {
        let result = try importer().importText("""
        Skills
        Welding

        Languages
        Spanish
        English
        Driving licence B
        """)
        #expect(result.cv.skills.map(\.value) == ["Welding"])
        #expect(result.cv.languages.map(\.name.value) == ["Spanish", "English"])
    }

    @Test("A language's level in words that ends in Kenntnisse is no group of skills")
    func levelLineIsNoGroup() throws {
        let result = try importer().importText("""
        Fähigkeiten
        Schweißen

        Sprachen
        Deutsch – Muttersprache
        Englisch – gute Kenntnisse
        """)
        #expect(result.cv.skills.map(\.value) == ["Schweißen"])
        #expect(result.cv.languages.map(\.name.value) == ["Deutsch", "Englisch"])
    }
}
