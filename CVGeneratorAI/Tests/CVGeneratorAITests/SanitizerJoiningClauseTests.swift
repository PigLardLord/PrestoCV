import Testing
import Foundation
@testable import CVGeneratorAI

/// A clause that names no employer joins the clause next to it (ADR 0023, rule (c)), and the cases where it must not: a clause
/// between two entries, a quote that names somebody's place. The rows of `GroundingContractTests` hold the words that the
/// closed vocabulary surely has; these hold what depends on the shape of the clauses.
@Suite("Sanitizer: a clause that names no employer joins the one next to it")
struct SanitizerJoiningClauseTests {
    private let sanitizer = CVDataSanitizer()

    private func job(_ company: String, from start: String? = nil, to end: String? = nil, achievements: [String] = []) -> Experience {
        Experience(title: "", company: company, startDate: start, endDate: end, achievements: achievements)
    }

    @Test("A clause next to the clauses of two entries joins neither, even when the name of the other one is a word of the vocabulary")
    func betweenTwoEntries() {
        let description = "At Acme I worked, from 2012 to 2016, and at Time I worked, from 2019 to 2023."
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2016"), job("Time", from: "2019", to: "2023")])

        let result = sanitizer.sanitize(draft, against: description).experience

        #expect(result.map(\.startDate) == [nil, "2019"], "2012 stands in the clause between the two; 2019 follows the clause of Time alone")
        #expect(result.map(\.endDate) == [nil, "2023"])
    }

    @Test("The same entry on both sides of a clause is the entry it joins")
    func betweenTwoClausesOfOneEntry() {
        let description = "At Acme I worked, from 2012 to 2016, at Acme again"
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2016")])

        let result = sanitizer.sanitize(draft, against: description).experience.first

        #expect(result?.startDate == "2012")
        #expect(result?.endDate == "2016")
    }

    @Test("A quote that holds a preposition of an employer explains nothing, though it begins with a verb")
    func quoteWithAnEmployerPreposition() {
        let description = "At Acme in 2012 I worked, and I worked for Beta in 2019."
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2019", achievements: ["worked for Beta in 2019"])])

        let acme = sanitizer.sanitize(draft, against: description).experience.first

        #expect(acme?.startDate == "2012")
        #expect(acme?.endDate == nil, "2019 is the year of the clause of Beta")
        #expect(acme?.achievements == [])
    }

    @Test("A quote that begins with a verb explains the clause it lies in, and the achievement stays as the model wrote it")
    func quoteThatBeginsWithAVerb() {
        let description = "At Acme in 2012 I worked, and trained interns in 2018."
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2018", achievements: ["Trained interns in 2018."])])

        let acme = sanitizer.sanitize(draft, against: description).experience.first

        #expect(acme?.achievements == ["Trained interns in 2018."])
        #expect(acme?.endDate == nil, "A clause that a quote explains gives the achievement alone, never a date")
    }

    @Test("An entry whose name stands in two places is found by neither when the clauses disagree on what it is")
    func entriesWithTheSameEmployer() {
        let description = "I was a nurse at Acme from 2012 to 2016. I am head nurse at Acme now."
        let draft = CVData(experience: [
            Experience(title: "nurse", company: "Acme", startDate: "2012", endDate: "2016"),
            Experience(title: "head nurse", company: "Acme", startDate: "2012", current: true),
        ])

        let result = sanitizer.sanitize(draft, against: description).experience

        #expect(result.map(\.startDate) == ["2012", nil])
        #expect(result.map(\.current) == [false, true])
    }

    // MARK: - A graduation phrase

    @Test("The text of a job never holds the graduation phrase next to its clause: 2012 is no year of the job")
    func graduationPhraseIsNotTheTextOfAJob() {
        let description = "I have worked at Acme since 2016 and graduated in 2012."
        let draft = CVData(experience: [Experience(title: "", company: "Acme", startDate: "2016", description: "Graduated in 2012.")])

        let acme = sanitizer.sanitize(draft, against: description).experience.first

        #expect(acme?.startDate == "2016")
        #expect(acme?.description == nil)
    }

    @Test("A word that goes with graduating is no graduation phrase without a word of graduating: gemacht needs Abschluss, obtenu needs diplôme",
          arguments: [
            // (description, what it says of the degree's year, whether the year stays)
            ("de", "Ich habe Pflege an der Universität Alpha studiert und habe 2012 meinen Abschluss gemacht.", true),
            ("de", "Ich habe Pflege an der Universität Alpha studiert und habe 2012 gemacht.", false),
            ("fr", "J'ai étudié les soins à l'université Alpha et j'ai obtenu mon diplôme en 2012.", true),
            ("fr", "J'ai étudié les soins à l'université Alpha et j'ai obtenu en 2012.", false),
          ] as [(String, String, Bool)])
    func frameWordsNeedAWordOfGraduating(language: String, description: String, keeps: Bool) {
        let degree = language == "de" ? "Pflege" : "les soins"
        let school = language == "de" ? "Universität Alpha" : "université Alpha"
        let study = Education(degree: degree, institution: school, endDate: "2012")

        let result = sanitizer.sanitize(CVData(education: [study]), against: description).education.first

        #expect((result?.endDate == "2012") == keeps, "\(description)")
    }

    // MARK: - A mention that is a fact

    @Test("An entry denied in one clause and mentioned as a fact in another stays, with what the fact backs")
    func deniedAndMentioned() {
        let description = "I have never worked at Acme. I worked at Acme in 2012."
        let draft = CVData(experience: [job("Acme", from: "2012")])

        let result = sanitizer.sanitize(draft, against: description).experience

        #expect(result.map(\.company) == ["Acme"])
        #expect(result.map(\.startDate) == ["2012"])
    }

    @Test("A clause that only hopes or promises backs nothing, and a word of the vocabulary does not make it a fact")
    func hopedClauseBacksNothing() {
        let description = "I worked at Acme from 2012 to 2016. I will work at Acme in 2030. I would like to work at Acme in 2040."
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2030")])

        let acme = sanitizer.sanitize(draft, against: description).experience.first

        #expect(acme?.startDate == "2012")
        #expect(acme?.endDate == nil)
    }

    @Test("An entry with no factual mention goes whole, whatever else the draft says of it")
    func entryWithoutAFactualMention() {
        let draft = CVData(
            experience: [Experience(title: "", company: "Acme", location: "Turin", startDate: "2027", current: true, description: "Worked at Acme.", achievements: ["worked at Acme"])],
            education: [Education(degree: nil, institution: "Alpha University", endDate: "2027")],
            certifications: [Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2027")]
        )
        let description = "If Acme hires me in Turin I will work at Acme from 2027. I hope to study at Alpha University until 2027. I want a BLS."

        #expect(sanitizer.sanitize(draft, against: description) == CVData())
    }
}
