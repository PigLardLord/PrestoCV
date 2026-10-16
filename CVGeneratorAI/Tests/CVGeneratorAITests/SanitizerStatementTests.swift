import Testing
import Foundation
@testable import CVGeneratorAI

/// A mention of an entry is a statement of fact, and the words of a purpose or a detail after it give no facts (ADR 0023, rule (c)).
@Suite("Sanitizer: the verbs of a clause decide what it says about an entry")
struct SanitizerStatementTests {
    private let sanitizer = CVDataSanitizer(languageOfText: { _ in "en" })

    private func sanitized(_ job: Experience, from description: String) -> Experience? {
        sanitizer.sanitize(CVData(experience: [job]), against: description).experience.first
    }

    @Test("A clause that mentions the employer without stating work done backs no date, though another clause does state it")
    func planBacksNothing() {
        let job = Experience(title: "", company: "Acme", startDate: "2027")

        let result = sanitized(job, from: "I worked at Acme. I have to work at Acme from 2027.")

        #expect(result?.company == "Acme")
        #expect(result?.startDate == nil)
    }

    @Test("The person's own place explains itself before the name of an entry, and an unexplained word does not; their name is no subject")
    func personExplainsItsWords() {
        let job = Experience(title: "", company: "Acme", startDate: "2016")
        let sanitizer = CVDataSanitizer(languageOfText: { _ in "it" })
        let draft = CVData(personalInfo: PersonalInfo(name: "Anna Rossi", location: "Bologna"), experience: [job])

        #expect(sanitizer.sanitize(draft, against: "A Bologna ho lavorato presso Acme dal 2016.").experience.first?.startDate == "2016")
        #expect(sanitizer.sanitize(draft, against: "A Zorblax ho lavorato presso Acme dal 2016.").experience.isEmpty)
        #expect(sanitizer.sanitize(draft, against: "Anna Rossi ha lavorato presso Acme dal 2016.").experience.isEmpty, "a name is never the person")
    }

    @Test("A verbless clause that a comma or a conjunction split off belongs to the clause before it")
    func fragmentBelongsToItsClause() {
        let beta = CVData(experience: [Experience(title: "", company: "Beta")])
        let three = CVData(experience: [Experience(title: "", company: "Acme"), Experience(title: "", company: "Beta"), Experience(title: "", company: "Gamma")])

        #expect(sanitizer.sanitize(beta, against: "I have never worked at Acme or Beta.").experience.isEmpty)
        #expect(sanitizer.sanitize(beta, against: "I have never worked at Acme, Beta.").experience.isEmpty)
        #expect(sanitizer.sanitize(three, against: "I worked at Acme, Beta and Gamma.").experience.map(\.company) == ["Acme", "Beta", "Gamma"])
        #expect(sanitizer.sanitize(three, against: "I would like to work at Acme, Beta, Gamma.").experience.isEmpty)
    }

    @Test("A verbless clause that starts a sentence or follows a semicolon stands on its own")
    func verblessAnchorStandsAlone() {
        let beta = CVData(experience: [Experience(title: "", company: "Beta")])

        #expect(sanitizer.sanitize(beta, against: "I have never worked at Acme; Beta.").experience.map(\.company) == ["Beta"])
        #expect(sanitizer.sanitize(beta, against: "I have never worked at Acme. Beta.").experience.map(\.company) == ["Beta"])
    }

    @Test("A clause that starts with its verb after a comma or a conjunction shares the subject of the clause before it")
    func sharedSubject() {
        let job = Experience(title: "", company: "Acme")
        let draft = CVData(experience: [job])

        #expect(sanitizer.sanitize(draft, against: "My sister is a nurse and worked at Acme.").experience.isEmpty)
        #expect(sanitizer.sanitize(draft, against: "My sister is a nurse, trained interns and worked at Acme.").experience.isEmpty)
        #expect(sanitizer.sanitize(draft, against: "I trained interns and worked at Acme.").experience.map(\.company) == ["Acme"])
        #expect(sanitizer.sanitize(draft, against: "My sister is a nurse. Worked at Acme.").experience.map(\.company) == ["Acme"], "A new sentence has its own subject")
        #expect(sanitizer.sanitize(draft, against: "She worked at Acme.").experience.isEmpty)
        #expect(sanitizer.sanitize(CVData(summary: "Worked at Acme."), against: "My sister is a nurse and worked at Acme.").summary == nil)
        #expect(sanitizer.sanitize(CVData(summary: "Worked at Acme."), against: "I trained interns and worked at Acme.").summary == "Worked at Acme.")
    }

    @Test("A clause about someone else joins nothing: the achievement that quotes it goes")
    func clauseOfAnotherPersonJoinsNothing() {
        let italian = CVDataSanitizer(languageOfText: { _ in "it" })
        let job = Experience(title: "", company: "Acme", achievements: ["ha formato 3 insegnanti"])
        let mine = Experience(title: "", company: "Acme", achievements: ["ho formato 3 insegnanti"])

        #expect(italian.sanitize(CVData(experience: [job]), against: "Ho lavorato presso Acme, ha formato 3 insegnanti.").experience.first?.achievements == [])
        #expect(italian.sanitize(CVData(experience: [mine]), against: "Ho lavorato presso Acme, ho formato 3 insegnanti.").experience.first?.achievements == ["ho formato 3 insegnanti"])
    }

    @Test("A title in a purpose is no title of the job")
    func titleInAPurpose() {
        let job = Experience(title: "head nurse", company: "Acme")

        #expect(sanitized(job, from: "I worked at Acme to become head nurse.")?.title == "")
        #expect(sanitized(job, from: "I worked as head nurse at Acme.")?.title == "head nurse")
    }

    @Test("A clause of a purpose next to the employer's gives nothing, and a clause that states work done keeps what it quotes")
    func purposeClauseJoinsNothing() {
        let purpose = Experience(title: "", company: "Acme", achievements: ["Teach 3 courses"])
        let statement = Experience(title: "", company: "Acme", achievements: ["Taught 3 courses"])

        #expect(sanitized(purpose, from: "I worked at Acme, to teach 3 courses.")?.achievements == [])
        #expect(sanitized(statement, from: "I worked at Acme, where I taught 3 courses.")?.achievements == ["Taught 3 courses"])
    }

    @Test("A word of now in a purpose does not say the job goes on, and a year in a purpose does not count against \"since\"")
    func currentAndYearsInAPurpose() {
        #expect(sanitized(Experience(title: "", company: "Acme", current: true), from: "I worked at Acme to teach students today.")?.current == false)

        let since = Experience(title: "", company: "Acme", startDate: "2016", current: true)
        let result = sanitized(since, from: "I work at Acme since 2016 to support students in 2018.")

        #expect(result?.startDate == "2016")
        #expect(result?.current == true)
    }

    @Test("A word nothing explains in a purpose does not stop the statement before it from backing the job")
    func unexplainedWordInAPurpose() {
        let result = sanitized(Experience(title: "", company: "Acme", startDate: "2016"), from: "I worked at Acme in 2016 to support Zorblax.")

        #expect(result?.startDate == "2016")
    }

    @Test("A word of wish in a purpose stops the clause from backing the job")
    func wishInAPurpose() {
        let job = Experience(title: "", company: "Acme", startDate: "2016")
        let result = sanitized(job, from: "I worked at Acme. I worked at Acme in 2016 to teach maybe 3 courses.")

        #expect(result?.company == "Acme")
        #expect(result?.startDate == nil)
    }

    @Test("The participle of a perfect belongs to its auxiliary: what comes after it is the statement's")
    func perfectKeepsItsFacts() {
        let result = sanitized(Experience(title: "", company: "Acme", startDate: "2016", current: true), from: "At Acme I have worked since 2016.")

        #expect(result?.startDate == "2016")
        #expect(result?.current == true)
    }
}
