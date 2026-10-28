import Testing
import Foundation
@testable import CVGeneratorAI

/// A fact backs an entry only in a clause that names the entry's employer and holds no word that nothing explains (ADR 0023).
/// Nothing else is read: not the capitals, not a preposition, not the sentence that the clause stands in. So an employer the
/// draft leaves out, however it is written, is a word nothing explains: it can neither take the facts of the entries before it
/// nor lend its own to them. The examples use the words of the closed vocabulary (worked, for, years), not descriptive ones.
@Suite("Sanitizer: only a clause that names the employer backs its facts")
struct SanitizerOmittedEntryTests {
    private let sanitizer = CVDataSanitizer()

    private func sanitized(_ cvData: CVData, from description: String) throws -> CVData {
        try sanitizer.sanitize(cvData, against: description)
    }

    private func job(
        _ company: String, from start: String? = nil, to end: String? = nil, current: Bool = false,
        description: String? = nil, achievements: [String] = []
    ) -> Experience {
        Experience(title: "", company: company, startDate: start, endDate: end, current: current,
                   description: description, achievements: achievements)
    }

    // MARK: - The example of the review

    @Test("A draft with only the first employer keeps neither the date nor the figure of the second")
    func secondEmployerIsLeftOut() throws {
        let description = "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years."
        let draft = CVData(experience: [job(
            "Acme", from: "2012", to: "2019", description: "At Beta in 2019 I worked for 5 years.",
            achievements: ["At Acme in 2012 I worked for 3 years", "At Beta in 2019 I worked for 5 years"]
        )])

        let acme = try sanitized(draft, from: description).experience.first

        #expect(acme?.startDate == "2012")
        #expect(acme?.endDate == nil)
        #expect(acme?.description == nil)
        #expect(acme?.achievements == ["At Acme in 2012 I worked for 3 years"])
    }

    @Test("Figures with no dates are bounded in the same way")
    func figuresOfAnOmittedEmployer() throws {
        let description = "At Acme I worked for 3 years and at Beta I worked for 5 years."
        let draft = CVData(experience: [job("Acme", achievements: ["At Acme I worked for 3 years", "At Beta I worked for 5 years"])])

        #expect(try sanitized(draft, from: description).experience.first?.achievements == ["At Acme I worked for 3 years"])
    }

    @Test("An employer written in lower case after \"and at\" is still the start of another job")
    func lowerCaseEmployerAfterAConjunction() throws {
        let description = "At Acme in 2012 I worked for 3 years and at the clinic in 2019 I worked for 5 years."
        let draft = CVData(experience: [job(
            "Acme", from: "2012", to: "2019",
            achievements: ["At Acme in 2012 I worked for 3 years", "at the clinic in 2019 I worked for 5 years"]
        )])

        let acme = try sanitized(draft, from: description).experience.first

        #expect(acme?.endDate == nil)
        #expect(acme?.achievements == ["At Acme in 2012 I worked for 3 years"])
    }

    // MARK: - An employer the draft leaves out, however it is written

    private static let twoEmployers: [(language: String, description: String, achievements: [String])] = [
        ("en", "At Acme in 2012 I worked for 3 years and at Beta in 2019 I worked for 5 years.",
         ["At Acme in 2012 I worked for 3 years", "at Beta in 2019 I worked for 5 years"]),
        ("it", "Presso Acme nel 2012 ho lavorato per 3 anni e presso Beta nel 2019 ho lavorato per 5 anni.",
         ["Presso Acme nel 2012 ho lavorato per 3 anni", "presso Beta nel 2019 ho lavorato per 5 anni"]),
        ("de", "Bei Acme habe ich 2012 3 Jahre gearbeitet und bei Beta habe ich 2019 5 Jahre gearbeitet.",
         ["Bei Acme habe ich 2012 3 Jahre gearbeitet", "bei Beta habe ich 2019 5 Jahre gearbeitet"]),
        ("es", "En Acme en 2012 trabajé durante 3 años y en Beta en 2019 trabajé durante 5 años.",
         ["En Acme en 2012 trabajé durante 3 años", "en Beta en 2019 trabajé durante 5 años"]),
        ("fr", "Chez Acme en 2012 j'ai travaillé pendant 3 ans et chez Beta en 2019 j'ai travaillé pendant 5 ans.",
         ["Chez Acme en 2012 j'ai travaillé pendant 3 ans", "chez Beta en 2019 j'ai travaillé pendant 5 ans"]),
        ("pt", "Na Acme em 2012 trabalhei durante 3 anos e na Beta em 2019 trabalhei durante 5 anos.",
         ["Na Acme em 2012 trabalhei durante 3 anos", "na Beta em 2019 trabalhei durante 5 anos"]),
    ]

    /// The second employer has no preposition before it, starts the sentence, or is written in lower case.
    private static let employerNamedAnyhow: [(language: String, description: String, achievements: [String])] = [
        ("en", "At Acme in 2012 I worked for 3 years and Beta employed me in 2019 for 5 years.",
         ["At Acme in 2012 I worked for 3 years", "Beta employed me in 2019 for 5 years"]),
        ("it", "Presso Acme nel 2012 ho lavorato per 3 anni e Beta mi ha assunta nel 2019 per 5 anni.",
         ["Presso Acme nel 2012 ho lavorato per 3 anni", "Beta mi ha assunta nel 2019 per 5 anni"]),
        ("de", "Bei Acme habe ich 2012 3 Jahre gearbeitet und Beta hat mich 2019 für 5 Jahre eingestellt.",
         ["Bei Acme habe ich 2012 3 Jahre gearbeitet", "Beta hat mich 2019 für 5 Jahre eingestellt"]),
        ("en, first word", "Beta employed me in 2019 for 9 years. At Acme I worked for 3 years in 2012.",
         ["At Acme I worked for 3 years in 2012", "Beta employed me in 2019 for 9 years"]),
        ("en, lower case", "At Acme in 2012 I worked for 3 years and beta employed me in 2019 for 9 years.",
         ["At Acme in 2012 I worked for 3 years", "beta employed me in 2019 for 9 years"]),
        ("it, first word", "Beta mi ha assunta nel 2019 per 9 anni. Presso Acme ho lavorato per 3 anni nel 2012.",
         ["Presso Acme ho lavorato per 3 anni nel 2012", "Beta mi ha assunta nel 2019 per 9 anni"]),
        ("it, lower case", "Presso Acme nel 2012 ho lavorato per 3 anni e beta mi ha assunta nel 2019 per 9 anni.",
         ["Presso Acme nel 2012 ho lavorato per 3 anni", "beta mi ha assunta nel 2019 per 9 anni"]),
        ("de, first word", "Beta hat mich 2019 für 9 Jahre eingestellt. Bei Acme habe ich 2012 3 Jahre gearbeitet.",
         ["Bei Acme habe ich 2012 3 Jahre gearbeitet", "Beta hat mich 2019 für 9 Jahre eingestellt"]),
        ("de, lower case", "Bei Acme habe ich 2012 3 Jahre gearbeitet und beta hat mich 2019 für 9 Jahre eingestellt.",
         ["Bei Acme habe ich 2012 3 Jahre gearbeitet", "beta hat mich 2019 für 9 Jahre eingestellt"]),
    ]

    @Test("What a job keeps is the same whether or not the draft has the job beside it",
          arguments: twoEmployers + employerNamedAnyhow)
    func omittingTheOtherJobChangesNothing(language: String, description: String, achievements: [String]) throws {
        let acme = job("Acme", from: "2012", to: "2019", current: true, description: achievements[1] + ".", achievements: achievements)
        let beta = job("Beta", from: "2012", to: "2019", current: true, description: achievements[0] + ".", achievements: achievements)

        let withBoth = try sanitized(CVData(experience: [acme, beta]), from: description).experience
        let acmeAlone = try sanitized(CVData(experience: [acme]), from: description).experience
        let betaAlone = try sanitized(CVData(experience: [beta]), from: description).experience

        #expect(acmeAlone.first == withBoth.first { $0.company == "Acme" }, "\(language): Acme")
        #expect(betaAlone.first == withBoth.first { $0.company == "Beta" }, "\(language): Beta")
        #expect(acmeAlone.first?.startDate == "2012", "\(language)")
        #expect(acmeAlone.first?.endDate == nil, "\(language)")
        #expect(acmeAlone.first?.current == false, "\(language)")
        #expect(acmeAlone.first?.achievements == [achievements[0]], "\(language)")
    }

    @Test("The same, whatever place the draft gives to the job or to the person",
          arguments: employerNamedAnyhow)
    func placeOfTheOmittedEmployer(language: String, description: String, achievements: [String]) throws {
        let plain = Experience(title: "", company: "Acme", startDate: "2012", endDate: "2019", current: true, achievements: achievements)
        let atBeta = Experience(title: "", company: "Acme", location: "Beta", startDate: "2012", endDate: "2019", current: true, achievements: achievements)

        let results = [
            try sanitized(CVData(experience: [plain]), from: description).experience.first,
            try sanitized(CVData(experience: [atBeta]), from: description).experience.first,
            try sanitized(CVData(personalInfo: PersonalInfo(location: "Beta"), experience: [plain]), from: description).experience.first,
        ]

        for acme in results {
            #expect(acme == results[0], "\(language)")
            #expect(acme?.endDate == nil, "\(language)")
            #expect(acme?.location == nil, "\(language)")
            #expect(acme?.achievements == [achievements[0]], "\(language)")
        }
    }

    @Test("An employer listed beside another in one clause leaves the dates to neither it nor the draft's omission",
          arguments: [
            "I worked at Acme and Beta from 2012 to 2019.",
            "Ho lavorato presso Acme e Beta dal 2012 al 2019.",
            "Ich habe bei Acme und Beta von 2012 bis 2019 gearbeitet.",
          ])
    func coordinatedEmployers(description: String) throws {
        let acme = job("Acme", from: "2012", to: "2019")
        let beta = job("Beta", from: "2012", to: "2019")

        let alone = try sanitized(CVData(experience: [acme]), from: description).experience.first
        let withBoth = try sanitized(CVData(experience: [acme, beta]), from: description).experience.first { $0.company == "Acme" }

        #expect(alone?.startDate == nil, "\(description)")
        #expect(alone?.endDate == nil, "\(description)")
        #expect(alone == withBoth, "\(description)")
    }

    @Test("A second period in the sentence that nothing names still ends the evidence of the first",
          arguments: [
            ("en", "At Acme in 2012 I worked for 3 years and as head nurse in 2019 I worked for 5 years.",
             ["At Acme in 2012 I worked for 3 years", "as head nurse in 2019 I worked for 5 years"]),
            ("it", "Presso Acme nel 2012 ho lavorato per 3 anni e come caposala nel 2019 ho lavorato per 5 anni.",
             ["Presso Acme nel 2012 ho lavorato per 3 anni", "come caposala nel 2019 ho lavorato per 5 anni"]),
            ("de", "Bei Acme habe ich 2012 3 Jahre gearbeitet und als Leiter habe ich 2019 5 Jahre gearbeitet.",
             ["Bei Acme habe ich 2012 3 Jahre gearbeitet", "als Leiter habe ich 2019 5 Jahre gearbeitet"]),
          ])
    func periodWithoutAName(language: String, description: String, achievements: [String]) throws {
        let acme = job("Acme", from: "2012", to: "2019", achievements: achievements)

        let result = try sanitized(CVData(experience: [acme]), from: description).experience.first

        #expect(result?.startDate == "2012", "\(language)")
        #expect(result?.endDate == nil, "\(language)")
        #expect(result?.achievements == [achievements[0]], "\(language)")
    }

    // MARK: - What joins the clause that names the employer, and what does not

    @Test("A clause that names no employer joins the clause of the employer next to it, in the same sentence")
    func factsOfAClauseWithoutTheEmployer() throws {
        let teacher = job("Don Milani school", from: "2016", current: true, achievements: ["Trained 3 new teachers"])
        let assistant = Experience(title: "assistant", company: "nursery", startDate: "2012", endDate: "2016")
        let school = Education(degree: "Education Sciences", institution: "University of Bologna", endDate: "2012")
        let description = """
            Since 2016 I have taught at the Don Milani school, where I trained 3 new teachers. \
            Before that, from 2012 to 2016, I worked as an assistant in a nursery. \
            I studied Education Sciences at the University of Bologna and graduated in 2012.
            """

        let result = try sanitized(CVData(experience: [teacher, assistant], education: [school]), from: description)

        #expect(result.experience[0].startDate == "2016")
        #expect(result.experience[0].current == true)
        #expect(result.experience[0].achievements == ["Trained 3 new teachers"], "The clause after the comma is explained by the quote, which begins with a verb")
        #expect(result.experience[1].startDate == "2012", "The years stand in a clause of nothing but time next to the one that names the nursery")
        #expect(result.experience[1].endDate == "2016")
        #expect(result.education[0].degree == "Education Sciences")
        #expect(result.education[0].endDate == "2012", "The 2012 is in the clause after \"and\", which holds nothing but words of graduating and a year")
    }

    @Test("A lead-in at the start of the sentence still belongs to the clause after it")
    func leadInBelongsToTheClauseAfterIt() throws {
        let draft = CVData(experience: [job("Acme", from: "2019", current: true)])

        let result = try sanitized(draft, from: "Since 2019, I work at Acme.").experience.first

        #expect(result?.startDate == "2019")
        #expect(result?.current == true)
    }

    @Test("Nothing outside the clauses that name the employer backs it, even when the description names one employer only")
    func soleEmployerOfTheDescription() throws {
        let draft = CVData(experience: [job("Acme", from: "2018", current: true, achievements: ["Worked for 3 years"])])

        let result = try sanitized(draft, from: "I work at Acme. Since 2018 I cook there. I work for 3 years now.").experience.first

        #expect(result?.startDate == nil)
        #expect(result?.current == false)
        #expect(result?.achievements == [])
    }

    @Test("The first word of a sentence is no exception: a sentence that does not name the employer backs nothing")
    func sentenceThatStartsWithAnEmployer() throws {
        let draft = CVData(experience: [job(
            "Acme", from: "2012", to: "2019", current: true,
            achievements: ["Worked for 3 years at Acme", "Beta employed me now in 2019 for 9 years"]
        )])

        let result = try sanitized(draft, from: "Beta employed me now in 2019 for 9 years. I worked for 3 years at Acme.").experience.first

        #expect(result?.startDate == nil)
        #expect(result?.endDate == nil)
        #expect(result?.current == false)
        #expect(result?.achievements == ["Worked for 3 years at Acme"])
    }

    @Test("Capitals are not read: a clause in capitals is explained as one in lower case, and a capitalised word nothing explains blocks it")
    func capitalsAreNotRead() throws {
        let draft = CVData(experience: [job("Acme", from: "2012", achievements: ["At Acme in 2012 I worked for 3 years"])])

        let shouting = try sanitized(draft, from: "AT ACME IN 2012 I WORKED FOR 3 YEARS.").experience.first
        let withAName = try sanitized(draft, from: "At Acme in 2012 I used Python for 3 years.").experience.first

        #expect(shouting?.startDate == "2012")
        #expect(shouting?.achievements == ["At Acme in 2012 I worked for 3 years"])
        #expect(withAName?.startDate == nil, "Python is a word nothing explains")
        #expect(withAName?.achievements == [])
    }

    @Test("A description typed in lower case is read in the same way")
    func lowerCaseDescription() throws {
        let description = "i worked at acme in 2012 and beta employed me in 2019"
        let draft = CVData(experience: [job("acme", from: "2012", to: "2019")])

        let acme = try sanitized(draft, from: description).experience.first

        #expect(acme?.startDate == "2012")
        #expect(acme?.endDate == nil)
    }

    @Test("An employer whose name holds a conjunction is not cut in two",
          arguments: [
            ("Dal 2004 al 2008 ho lavorato presso lo Studio Rossi e Associati.", "Studio Rossi e Associati"),
            ("From 2004 to 2008 I worked at Procter and Gamble.", "Procter and Gamble"),
            ("Von 2004 bis 2008 habe ich bei Müller und Söhne gearbeitet.", "Müller und Söhne"),
          ])
    func employerWithAConjunction(description: String, company: String) throws {
        let result = try sanitized(CVData(experience: [job(company, from: "2004", to: "2008")]), from: description).experience.first

        #expect(result?.startDate == "2004", "\(description)")
        #expect(result?.endDate == "2008", "\(description)")
    }

    @Test("A clause that names no employer backs nothing of a description that names two")
    func clauseWithoutAnEmployer() throws {
        let description = "At Acme I worked, from 2012 to 2016, and at Beta I worked, from 2019 to 2023."
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2016")])

        let acme = try sanitized(draft, from: description).experience.first

        #expect(acme?.startDate == nil)
        #expect(acme?.endDate == nil)
    }

    @Test("A clause that names two employers says nothing of either")
    func clauseWithTwoEmployers() throws {
        let description = "I left Beta for Acme in 2019 and I still work there now."
        let draft = CVData(experience: [job("Acme", from: "2019", current: true), job("Beta", to: "2019")])

        let result = try sanitized(draft, from: description).experience

        #expect(result.map(\.startDate) == [nil, nil])
        #expect(result.map(\.endDate) == [nil, nil])
        #expect(result.map(\.current) == [false, false])
    }

    @Test("A name that goes on past the employer's is another employer when the draft has it")
    func employerWhoseNameGoesOn() throws {
        let description = "I worked at Acme in 2012. I work at Acme Labs since 2019."
        let draft = CVData(experience: [job("Acme", from: "2012", to: "2019", current: true), job("Acme Labs", from: "2012", current: true)])

        let result = try sanitized(draft, from: description).experience

        #expect(result.map(\.startDate) == ["2012", nil], "The 2012 of Acme Labs is not in its clause")
        #expect(result.map(\.endDate) == [nil, nil])
        #expect(result.map(\.current) == [false, true])
    }

    // MARK: - Titles and prose

    @Test("A title stated outside the clauses that name the employer is not the job's, whatever the sentence says of the person")
    func titleOutsideTheEmployersClauses() throws {
        let description = "I was head nurse at Beta in 2019. I was a cook at Acme in 2012."
        let draft = CVData(experience: [Experience(title: "head nurse", company: "Acme")])

        #expect(try sanitized(draft, from: description).experience.first?.title == "")
    }

    @Test("A sentence of a job's text that names another employer of the draft is dropped")
    func proseNamingAnotherEmployer() throws {
        let description = "I worked at Acme. Later I moved to Beta."
        let acme = job("Acme", description: "Worked at Acme. Later moved to Beta.")
        let beta = job("Beta")

        let result = try sanitized(CVData(experience: [acme, beta]), from: description).experience

        #expect(result.first?.description == "Worked at Acme.")
    }

    // MARK: - Schools and certifications

    @Test("A school the draft left out still ends the evidence of the school before it")
    func omittedSchool() throws {
        let description = "At Alpha University in 2010 I graduated and at Beta University in 2014 I did a master."
        let draft = CVData(education: [Education(institution: "Alpha University", startDate: "2010", endDate: "2014")])

        let alpha = try sanitized(draft, from: description).education.first

        // 2010 is written with "graduated": the year of the degree, never the start (ADR 0023). Beta's 2014 is not Alpha's.
        #expect(alpha?.startDate == nil)
        #expect(alpha?.endDate == nil)
    }

    @Test("An issuer and a date given for a certification the draft left out are not the draft's")
    func omittedCertification() throws {
        let description = "I hold a BLS from the Italian Resuscitation Council in 2023 and a PALS from the American Heart Association in 2019."
        let right = CVData(certifications: [Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2023")])
        let wrong = CVData(certifications: [Certification(name: "BLS", issuer: "American Heart Association", date: "2019")])

        #expect(try sanitized(right, from: description).certifications.first == right.certifications.first)
        #expect(try sanitized(wrong, from: description).certifications.first == Certification(name: "BLS"))
    }

    // MARK: - Levels

    @Test("The level of a language or skill the draft left out is not the level of the one beside it")
    func levelOfAnOmittedItem() throws {
        let languages = CVData(languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .a2)])
        let skills = CVData(skills: [Skill(name: "Python", level: .advanced)])

        let result = try sanitized(languages, from: "I speak Italian (native), French (A2) and English (B2).")
        let skillResult = try sanitized(skills, from: "I know Python (expert), Swift (advanced) and Go (beginner).")

        #expect(result.languages == [Language(name: "Italian", proficiency: .native), Language(name: "English")], "English keeps no level (#354)")
        #expect(skillResult.skills == [Skill(name: "Python")])
    }

    @Test("A level stated in the same clause as the item is still that item's")
    func levelInTheSameClause() throws {
        let languages = CVData(languages: [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)])

        let result = try sanitized(languages, from: "I speak Italian (native), French (A2) and English (B2).")

        #expect(result.languages.map(\.proficiency) == [.native, .b2])
    }
}
