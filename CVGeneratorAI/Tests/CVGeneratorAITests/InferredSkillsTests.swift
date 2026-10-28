import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0031: a skill the model writes for the person's role is a plain name of a technology or a soft skill. It is no qualification,
/// no exam, no address, and holds no character that hides or reorders what the reader sees.
@Suite("Inferred skills: what a plain name is")
struct InferredSkillsTests {
    private static let description = "I'm a primary school teacher. I teach at a school in my town."

    private func skills(language: Vocabulary.Language? = .english) -> InferredSkills {
        let source = DescriptionText(Self.description, languageOfText: { _ in language?.rawValue })
        let written = WrittenText(source: source, claimed: source, wordList: TableWordList(), tagger: NoNames())
        let cvData = CVData(personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna", title: "primary school teacher"))
        return InferredSkills(cvData, language: language, written: written)
    }

    @Test("The names of technologies and soft skills stay, with the punctuation of their trade",
          arguments: ["Lesson planning", "Phonics", "C++", "C#", "F#", "Node.js", "ASP.NET", "Vue.js", ".NET", "Objective-C", "CI/CD",
                      "Q&A", "Delta Lake", "SAT solving", "GRE tunnel", "CPA tracking", "OCP cluster", "Praxis management", "Master Data Management",
                      "Maya", "NODE.JS", "Node.js Express", "Team leadership", "Gestione della classe", "Pädagogik", "Planificación", "Éducation", "Comunicação"])
    func plainNamesStay(name: String) {
        #expect(skills().accepted(name) == name)
    }

    @Test("The name of an exam or a certification is a qualification, in any spelling",
          arguments: ["TOEFL", "toefl", "IELTS", "TOEIC", "Cambridge CELTA", "TEFL", "TESOL", "DELE", "DELF", "TestDaF", "Goethe Zertifikat",
                      "HSK", "JLPT", "GMAT", "PMP", "CISSP", "CCNA", "ITIL", "Six Sigma", "Green Belt", "Security+", "Network+", "A+",
                      "SAT", "SAT exam", "Delta certification", "GRE test", "CPA", "OCP", "Praxis", "Esame di stato", "Staatsexamen", "Examen", "Oposiciones", "Concorso pubblico", "Prüfung", "BLS", "ACLS"])
    func examsAreQualifications(name: String) {
        #expect(skills().accepted(name) == nil, "\(name)")
    }

    @Test("An address, a link or a mark-up is no skill",
          arguments: ["help@evil.example", "evil.example", "www.evil.example", "evil.example/path", "https://evil.example", "a@b.co",
                      "<b>Phonics</b>", "Phonics; drop table", "Phonics (see evil.example)", "Phonics = 1", "Phonics | Excel", "Phonics_Excel",
                      "Phonics\\Excel", "evil.js", "evil.net", "evil.ts", "evil.py", "node.js.evil.com", "www.node.js", "https://node.js", "node.js/evil", "Node.js evil.js", "Phonics*", "Phonics!", "Phonics?", "Phonics, Excel", "Phonics: Excel", "{Phonics}", "[Phonics]"])
    func addressesAndMarkup(name: String) {
        #expect(skills().accepted(name) == nil, "\(name)")
    }

    @Test("A character that hides or reorders what the reader sees is no part of a name",
          arguments: ["Excel\u{202E}gnidnuof", "Excel\u{202D}", "Excel\u{2066}", "Excel\u{2069}", "Excel\u{200E}", "Excel\u{200F}",
                      "Lesson\u{200B}planning", "Lesson\u{200D}planning", "Lesson\u{FEFF}planning", "Lesson\u{00AD}planning",
                      "Lesson\u{2060}planning", "Lesson\u{0007}planning", "Lesson\u{0000}planning", "Lesson\u{007F}planning",
                      "Lesson\u{0085}planning", "Lesson\u{2028}planning", "Lesson\u{00A0}planning", "Lesson\u{E000}planning",
                      "Lesson\tplanning", "Lesson\nplanning", "Lesson 😀", "Lesson\u{0301}\u{0302}\u{0303}\u{0304}planning"])
    func hiddenCharacters(name: String) {
        #expect(skills().accepted(name) == nil, "\(name.unicodeScalars.map(\.value))")
    }
}

private struct NoNames: LexicalTagger {
    func tagsLexicalClass(inLanguage language: String) -> Bool { true }
    func verbs(in text: String, language: String) -> [Range<Int>] { [] }
    func names(in text: String, language: String) -> [Range<Int>] { [] }
}
