import Testing
@testable import CVGeneratorAI

/// The year a study ended (#354): the year the person says they finished it is its end date, whatever end date the model wrote; a
/// study the person never says they finished gets none. Every name, school and year is invented.
@Suite("A study ends in the year the person says they finished it (#354)")
struct StudyFactsTests {
    private let sanitizer = CVDataSanitizer(
        languageOfText: { _ in "de" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList()
    )

    static let finished = """
        Ich bin Tischler und arbeite seit 2016 bei der Werkstatt Ostrander in Passau. \
        Ich habe die Berufsschule Altmühltal besucht und 2011 meine Ausbildung abgeschlossen.
        """

    static let begun = """
        Ich bin Tischler und arbeite seit 2016 bei der Werkstatt Ostrander in Passau. \
        2020 habe ich eine Ausbildung an der Berufsschule Altmühltal begonnen.
        """

    @Test("The year the person says they finished a study is its end date, though the model wrote it as the start")
    func finishedYearIsTheEnd() throws {
        let draft = CVData(education: [
            Education(degree: "Ausbildung", institution: "Berufsschule Altmühltal", startDate: "2011", endDate: "2015"),
        ])

        let result = try sanitizer.sanitize(draft, against: Self.finished)

        #expect(result.education == [Education(degree: "Ausbildung", institution: "Berufsschule Altmühltal", endDate: "2011")])
    }

    @Test("A study the person never says they finished gets no end date, and its start is no end")
    func begunStudyHasNoEnd() throws {
        let draft = CVData(education: [
            Education(degree: "Ausbildung", institution: "Berufsschule Altmühltal", startDate: "2020", endDate: "2023"),
        ])

        let result = try sanitizer.sanitize(draft, against: Self.begun)

        #expect(result.education.first?.endDate == nil)
    }

    // MARK: A course the person says they finished (#359)

    struct FinishRow: Sendable, CustomTestStringConvertible {
        let language: String
        let description: String
        let degree: String
        let institution: String
        let end: String?
        var testDescription: String { "\(language): \(description)" }
    }

    @Test("The year the person says they finished the course or their studies is the end of the study, and no start; a course begun or a project is no end (#359)",
          arguments: [
              FinishRow(
                  language: "pt", description: "Sou enfermeira. Estudei na Escola Superior de Saúde do Mondego e terminei o curso em 2014.",
                  degree: "curso", institution: "Escola Superior de Saúde do Mondego", end: "2014"
              ),
              FinishRow(
                  language: "es", description: "Soy enfermera. Estudié en la Escuela de Enfermería de Soria y terminé el curso en 2014.",
                  degree: "curso", institution: "Escuela de Enfermería de Soria", end: "2014"
              ),
              FinishRow(
                  language: "it", description: "Sono infermiera. Ho studiato alla Scuola Infermieri di Bari e ho terminato il corso nel 2014.",
                  degree: "corso", institution: "Scuola Infermieri di Bari", end: "2014"
              ),
              FinishRow(
                  language: "fr", description: "Je suis infirmière. J'ai étudié à l'Institut Rabelais et j'ai terminé ma formation en 2014.",
                  degree: "formation", institution: "Institut Rabelais", end: "2014"
              ),
              FinishRow(
                  language: "en", description: "I am a nurse. I studied at Riverside Nursing School and finished the course in 2014.",
                  degree: "course", institution: "Riverside Nursing School", end: "2014"
              ),
              FinishRow(
                  language: "pt", description: "Sou enfermeira. Estudei na Escola Superior de Saúde do Mondego e terminei os meus estudos em 2014.",
                  degree: "curso", institution: "Escola Superior de Saúde do Mondego", end: "2014"
              ),
              FinishRow(
                  language: "es", description: "Soy enfermera. Estudié en la Escuela de Enfermería de Soria y terminé mis estudios en 2014.",
                  degree: "curso", institution: "Escuela de Enfermería de Soria", end: "2014"
              ),
              FinishRow(
                  language: "es", description: "Soy enfermera. Estudié en la Escuela de Enfermería de Soria y terminé la carrera en 2014.",
                  degree: "curso", institution: "Escuela de Enfermería de Soria", end: "2014"
              ),
              FinishRow(
                  language: "it", description: "Sono infermiera. Ho studiato alla Scuola Infermieri di Bari e ho terminato gli studi nel 2014.",
                  degree: "corso", institution: "Scuola Infermieri di Bari", end: "2014"
              ),
              FinishRow(
                  language: "fr", description: "Je suis infirmière. J'ai étudié à l'Institut Rabelais et j'ai terminé mes études en 2014.",
                  degree: "formation", institution: "Institut Rabelais", end: "2014"
              ),
              FinishRow(
                  language: "en", description: "I am a nurse. I studied at Riverside Nursing School and finished my studies in 2014.",
                  degree: "course", institution: "Riverside Nursing School", end: "2014"
              ),
              FinishRow(
                  language: "pt", description: "Sou enfermeira. Estudei na Escola Superior de Saúde do Mondego e comecei o curso em 2014.",
                  degree: "curso", institution: "Escola Superior de Saúde do Mondego", end: nil
              ),
              FinishRow(
                  language: "pt", description: "Sou enfermeira. Estudei na Escola Superior de Saúde do Mondego e terminei o projeto em 2014.",
                  degree: "curso", institution: "Escola Superior de Saúde do Mondego", end: nil
              ),
              FinishRow(
                  language: "en", description: "I am a nurse. I studied at Riverside Nursing School and finished the project in 2014.",
                  degree: "course", institution: "Riverside Nursing School", end: nil
              ),
              FinishRow(
                  language: "es", description: "Soy enfermera. Estudié en la Escuela de Enfermería de Soria y empecé mis estudios en 2014.",
                  degree: "curso", institution: "Escuela de Enfermería de Soria", end: nil
              ),
              FinishRow(
                  language: "it", description: "Sono infermiera. Ho studiato alla Scuola Infermieri di Bari e ho terminato il progetto nel 2014.",
                  degree: "corso", institution: "Scuola Infermieri di Bari", end: nil
              ),
          ])
    func finishedCourseIsTheEnd(row: FinishRow) throws {
        let sanitizer = CVDataSanitizer(
            languageOfText: { _ in row.language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList()
        )
        let draft = CVData(education: [
            Education(degree: row.degree, institution: row.institution, startDate: "2014", endDate: "2014"),
        ])

        let result = try sanitizer.sanitize(draft, against: row.description)

        #expect(result.education.map(\.institution) == [row.institution])
        #expect(result.education.first?.endDate == row.end)
        if row.end != nil {
            #expect(result.education.first?.startDate == nil, "The year the study ended is never its start")
        }
    }
}
