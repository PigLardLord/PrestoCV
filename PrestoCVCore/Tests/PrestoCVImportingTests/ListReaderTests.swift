import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

@Suite("Reading skills, interests, languages and certifications")
struct ListReaderTests {

    private func read(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections {
            switch section.kind {
            case .skills: ListReader.readSkills(section, into: &findings)
            case .interests: ListReader.readInterests(section, into: &findings)
            case .languages: LanguageReader.read(section, into: &findings)
            case .certifications: CertificationReader.read(section, into: &findings)
            default: break
            }
        }
        return findings
    }

    @Test("Skills split at commas and bullets; a group's label is left out, prose stays visible")
    func skills() {
        let found = read("""
        Skills
        - Programming languages: Swift, Kotlin, TypeScript
        - Tools: Xcode; Git; CI/CD
        - I enjoy mentoring junior developers and leading code reviews across several teams
        """)
        #expect(found.cv.skills.map(\.value) == ["Swift", "Kotlin", "TypeScript", "Xcode", "Git", "CI/CD"])
        #expect(found.leftOut.map(\.reason) == [.categoryLabel, .categoryLabel])
        #expect(found.unplaced.map(\.text) == ["I enjoy mentoring junior developers and leading code reviews across several teams"])
    }

    @Test("A table of skills keeps the skill; a level in words stays visible, never turned into stars")
    func skillTable() {
        let found = read("""
        ## Competenze
        | Competenza | Livello |
        |---|---|
        | Swift | Esperto |
        | Kotlin | ★★★☆☆ |
        """)
        #expect(found.cv.skills.map(\.value) == ["Swift", "Kotlin"])
        #expect(found.unplaced.map(\.text) == ["Esperto"])
    }

    @Test("Interests split like skills")
    func interests() {
        let found = read("Hobbys\nKlettern, Fotografie · Gitarre")
        #expect(found.cv.interests.map(\.value) == ["Klettern", "Fotografie", "Gitarre"])
    }

    @Test("Languages with CEFR levels and native ones, in each language's words", arguments: [
        ("Inglese – C1", "Inglese", LanguageProficiency.c1), ("Deutsch: Muttersprache", "Deutsch", .native),
        ("Englisch (B2)", "Englisch", .b2), ("Español – lengua materna", "Español", .native), ("Anglais : niveau B1", "Anglais", .b1),
        ("Português (nativo)", "Português", .native), ("English – Native or bilingual", "English", .native),
        ("Italiano madrelingua", "Italiano", .native), ("C1 English", "English", .c1),
    ])
    func levels(text: String, name: String, level: LanguageProficiency) throws {
        let found = read("Languages\n\(text)")
        let language = try #require(found.cv.languages.first)
        #expect(language.name.value == name)
        #expect(language.level?.value == level)
        #expect(language.level?.reading == .languageLevel)
    }

    @Test("A level in words is kept as words, with no level, and flagged")
    func wordsLevel() throws {
        let found = read("Sprachen\nEnglisch – verhandlungssicher\nSpanisch")
        #expect(found.cv.languages.map(\.name.value) == ["Englisch", "Spanisch"])
        #expect(found.cv.languages[0].level == nil)
        #expect(found.cv.languages[0].levelWords?.value == "verhandlungssicher")
        #expect(found.cv.languages[0].levelWords?.check == .levelNotCEFR)
        #expect(found.cv.languages[1].levelWords == nil)
    }

    @Test("Several languages in one line")
    func severalInALine() {
        let found = read("Lingue\nItaliano (madrelingua), Inglese (C1), Francese (B1)")
        #expect(found.cv.languages.map(\.name.value) == ["Italiano", "Inglese", "Francese"])
        #expect(found.cv.languages.map { $0.level?.value } == [.native, .c1, .b1])
    }

    @Test("The Europass rows: the mother tongue, and the grid of the other languages")
    func europass() {
        let found = read("""
        CAPACITÀ E COMPETENZE PERSONALI
        MADRELINGUA\tItaliano
        ALTRE LINGUE\tInglese
        \tB2 B2 B1 B1 B2
        \tFrancese
        \tA2 A2 A2 A2 A2
        """)
        #expect(found.cv.languages.map(\.name.value) == ["Italiano", "Inglese", "Francese"])
        #expect(found.cv.languages.map { $0.level?.value } == [.native, nil, .a2])
        #expect(found.cv.languages[1].levelWords?.check == .levelsDiffer)
    }

    @Test("Certifications: the name, the issuer and the year")
    func certifications() throws {
        let found = read("""
        Certificazioni
        - BLSD – Croce Rossa Italiana (2021)
        - AWS Certified Developer, Amazon Web Services, 2022
        - Corso di primo soccorso
        """)
        try #require(found.cv.certifications.count == 3)
        #expect(found.cv.certifications.map(\.name.value) == ["BLSD", "AWS Certified Developer", "Corso di primo soccorso"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Croce Rossa Italiana", "Amazon Web Services", nil])
        #expect(found.cv.certifications.map { $0.year?.value } == [2021, 2022, nil])
        #expect(found.cv.certifications[0].year?.reading == .year)
    }
}
