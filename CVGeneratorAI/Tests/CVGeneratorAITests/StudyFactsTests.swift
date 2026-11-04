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
}
