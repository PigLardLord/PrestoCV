import Testing
import Foundation
@testable import CVGeneratorAI

/// What a draft says about an entry beyond its name (dates, figures, place, issuer, link, "still works there") must
/// come from what the description says about that entry, found through its employer or school (ADR 0023). A title, a degree,
/// a present word or a year that belongs to another entry authorises nothing.
@Suite("Sanitizer: an entry is backed only by what the description says about it")
struct SanitizerEntryAnchorTests {
    private let sanitizer = CVDataSanitizer()

    private func sanitized(_ cvData: CVData, from description: String) throws -> CVData {
        try sanitizer.sanitize(cvData, against: description)
    }

    private func job(
        _ title: String, _ company: String, from start: String? = nil, to end: String? = nil, current: Bool = false,
        location: String? = nil, description: String? = nil, achievements: [String] = []
    ) -> Experience {
        Experience(title: title, company: company, location: location, startDate: start, endDate: end, current: current,
                   description: description, achievements: achievements)
    }

    private func entry(_ company: String, in result: CVData) -> Experience? {
        result.experience.first { $0.company == company }
    }

    // MARK: - Dates and figures come from what names the employer

    @Test("Another employer's dates and figures are not backed by a title the two jobs share")
    func sharedTitleBacksNothing() throws {
        let description = "Nurse at Acme 2012–2016. Nurse at Beta 2019–2023, trained 3 nurses."
        let draft = CVData(experience: [
            job("nurse", "Acme", from: "2012", to: "2023", current: true, description: "Trained 3 nurses.", achievements: ["Trained 3 nurses"]),
            job("nurse", "Beta", from: "2019", to: "2023", achievements: ["Trained 3 nurses"]),
        ])

        let result = try sanitized(draft, from: description)

        let acme = entry("Acme", in: result)
        #expect(acme?.startDate == "2012")
        #expect(acme?.endDate == nil, "2023 is Beta's")
        #expect(acme?.current == false)
        #expect(acme?.description == nil)
        #expect(acme?.achievements == [])
        let beta = entry("Beta", in: result)
        #expect(beta?.startDate == "2019")
        #expect(beta?.endDate == "2023")
        #expect(beta?.achievements == ["Trained 3 nurses"], "The clause after the comma joins the clause of Beta, which it follows: the draft quotes it, and its quote begins with a verb")
    }

    @Test("A job that is given only the dates of the job with the same title has none")
    func datesOfTheOtherJobAreDropped() throws {
        let description = "Nurse at Acme 2012–2016. Nurse at Beta 2019–2023."
        let draft = CVData(experience: [job("nurse", "Acme", from: "2019", to: "2023"), job("nurse", "Beta", from: "2012", to: "2016")])

        let result = try sanitized(draft, from: description)

        #expect(result.experience.map(\.startDate) == [nil, nil])
        #expect(result.experience.map(\.endDate) == [nil, nil])
    }

    @Test("In a sentence that names two employers, each one is backed by its own clause")
    func twoEmployersInOneSentence() throws {
        let description = "I worked at Acme from 2012 to 2016 and at Beta from 2019 to 2023."
        let draft = CVData(experience: [job("", "Acme", from: "2012", to: "2023"), job("", "Beta", from: "2012", to: "2023")])

        let result = try sanitized(draft, from: description)

        #expect(entry("Acme", in: result)?.startDate == "2012")
        #expect(entry("Acme", in: result)?.endDate == nil)
        #expect(entry("Beta", in: result)?.startDate == nil)
        #expect(entry("Beta", in: result)?.endDate == "2023")
    }

    @Test("In a sentence that names two employers, a figure belongs to the clause it stands in")
    func figuresOfTwoEmployers() throws {
        let description = "At Acme I worked for 3 years and at Beta I worked for 5 years."
        let draft = CVData(experience: [
            job("", "Acme", achievements: ["At Acme I worked for 3 years", "at Beta I worked for 5 years"]),
            job("", "Beta", achievements: ["At Acme I worked for 3 years", "at Beta I worked for 5 years"]),
        ])

        let result = try sanitized(draft, from: description)

        #expect(entry("Acme", in: result)?.achievements == ["At Acme I worked for 3 years"])
        #expect(entry("Beta", in: result)?.achievements == ["at Beta I worked for 5 years"])
    }

    @Test("A sentence that gives the years of two periods is read clause by clause, whether or not the draft has both jobs")
    func employerOfThePeriodLeftOutOfTheDraft() throws {
        let description = "I worked at Acme from 2012 to 2016 and at Beta from 2019 to 2023."

        let result = try sanitized(CVData(experience: [job("", "Acme", from: "2012", to: "2023")]), from: description)

        #expect(result.experience.first?.startDate == "2012")
        #expect(result.experience.first?.endDate == nil)
    }

    @Test("A clause that names the employer backs all of its dates and figures; cut by commas, a clause of nothing but time next to it joins it, one beyond it does not")
    func oneEmployerInAClause() throws {
        let clause = "At Acme from 2012 to 2016 I worked for 3 years"
        let draft = CVData(experience: [job("", "Acme", from: "2012", to: "2016", description: clause + ".", achievements: [clause])])

        #expect(try sanitized(draft, from: clause + ".") == draft)
        #expect(try sanitized(draft, from: "At Acme, from 2012 to 2016, I worked for 3 years.") == CVData(experience: [job("", "Acme", from: "2012", to: "2016")]))
    }

    @Test("A school named beside a job backs none of the job's dates, and a job none of the school's")
    func jobAndSchoolInOneSentence() throws {
        let description = "I worked at Acme from 2012 to 2016 and studied at Alpha University from 2008 to 2011."
        let draft = CVData(
            experience: [job("", "Acme", from: "2008", to: "2016")],
            education: [Education(institution: "Alpha University", startDate: "2008", endDate: "2016")]
        )

        let result = try sanitized(draft, from: description)

        #expect(result.experience.first?.startDate == nil)
        #expect(result.experience.first?.endDate == "2016")
        #expect(result.education.first?.startDate == "2008")
        #expect(result.education.first?.endDate == nil)
    }

    // MARK: - A title is the entry's own

    @Test("A job's title is one the description gives for that job, or for the person, not another job's")
    func titleOfAnotherJob() throws {
        let description = "I was head nurse at Beta in 2019. I was a cook at Acme in 2012."
        let draft = CVData(experience: [job("head nurse", "Acme"), job("head nurse", "Beta")])

        let result = try sanitized(draft, from: description)

        #expect(entry("Acme", in: result)?.title == "")
        #expect(entry("Beta", in: result)?.title == "head nurse")
    }

    @Test("A title the description gives only about the person is the job's title too, when its clause holds nothing but explained words")
    func titleOfThePerson() throws {
        let description = "I'm a primary school teacher. Since 2016 I have taught at the Don Milani school."
        let draft = CVData(personalInfo: PersonalInfo(title: "primary school teacher"), experience: [job("primary school teacher", "Don Milani school")])

        let result = try sanitized(draft, from: description)

        #expect(result.experience.first?.title == "primary school teacher")
        #expect(result.personalInfo.title == "primary school teacher")
    }

    @Test("A degree is one the description gives for that school, not another school's")
    func degreeOfAnotherSchool() throws {
        let description = "I studied Nursing at Alpha University in 2010. I studied Law at Beta University in 2015."
        let draft = CVData(education: [
            Education(degree: "Law", institution: "Alpha University", endDate: "2010"),
            Education(degree: "Law", institution: "Beta University", endDate: "2015"),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.education.map(\.degree) == [nil, "Law"])
        #expect(result.education.map(\.institution) == ["Alpha University", "Beta University"])
    }

    @Test("A degree with no school, named in two places that each speak of another entry, is no entry")
    func degreeNamedBesideOtherEntriesOnly() throws {
        let description = "At Acme I studied Nursing. At Beta I studied Nursing."
        let draft = CVData(experience: [job("", "Acme"), job("", "Beta")], education: [Education(degree: "Nursing", startDate: "2010")])

        let result = try sanitized(draft, from: description)

        #expect(result.education.isEmpty)
        #expect(result.experience.count == 2)
    }

    // MARK: - A job with no employer is found by a title that occurs once

    @Test("A job with no employer keeps the dates of the one place its title is named")
    func titleOnlyJobWithAUniqueTitle() throws {
        let result = try sanitized(CVData(experience: [job("nurse", "", from: "2012", to: "2016")]), from: "I was a nurse from 2012 to 2016.")

        #expect(result.experience.first?.startDate == "2012")
        #expect(result.experience.first?.endDate == "2016")
    }

    @Test("A job with no employer and a title named in two places has no dates, and so is not a job")
    func titleOnlyJobWithAnAmbiguousTitle() throws {
        let description = "I'm a nurse. I was a nurse from 2012 to 2016."

        let result = try sanitized(CVData(experience: [job("nurse", "", from: "2012", to: "2016", current: true)]), from: description)

        #expect(result.experience.isEmpty)
    }

    @Test("A title that a longer title of the draft contains is not named by it")
    func titleInsideALongerTitle() throws {
        let description = "I was head nurse at Acme from 2012 to 2016. In 2019 I became a nurse."
        let draft = CVData(experience: [job("head nurse", "Acme", from: "2012", to: "2016"), job("nurse", "", from: "2019")])

        let result = try sanitized(draft, from: description)

        #expect(result.experience.map(\.title) == ["head nurse", "nurse"])
        #expect(result.experience.map(\.startDate) == ["2012", "2019"])
    }

    // MARK: - An employer inside a longer name, and an employer with two jobs

    @Test("An employer named inside a longer employer's name is not that employer")
    func employerInsideALongerEmployer() throws {
        let description = "I worked at Acme from 2010 to 2012. I work at Acme Labs since 2019."
        let draft = CVData(experience: [
            job("", "Acme", from: "2010", to: "2019", current: true),
            job("", "Acme Labs", from: "2010", current: true),
        ])

        let result = try sanitized(draft, from: description)

        let acme = entry("Acme", in: result)
        #expect(acme?.startDate == "2010")
        #expect(acme?.endDate == nil)
        #expect(acme?.current == false)
        let labs = entry("Acme Labs", in: result)
        #expect(labs?.startDate == nil)
        #expect(labs?.current == true)
    }

    @Test("Two jobs at one employer are told apart by their titles")
    func twoJobsAtOneEmployer() throws {
        let description = "I was a nurse at Acme from 2012 to 2016. I am head nurse at Acme now."
        let draft = CVData(experience: [
            job("nurse", "Acme", from: "2012", to: "2016", current: true),
            job("head nurse", "Acme", from: "2012", current: true),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.experience.map(\.title) == ["nurse", "head nurse"])
        #expect(result.experience.map(\.startDate) == ["2012", nil])
        #expect(result.experience.map(\.endDate) == ["2016", nil])
        #expect(result.experience.map(\.current) == [false, true])
    }

    @Test("Two jobs at one employer in one sentence cannot be told apart, so neither is dated")
    func twoJobsAtOneEmployerInOneClause() throws {
        let description = "At Acme I was a nurse and then head nurse, until 2016."
        let draft = CVData(experience: [job("nurse", "Acme", to: "2016"), job("head nurse", "Acme", to: "2016")])

        let result = try sanitized(draft, from: description)

        #expect(result.experience.map(\.endDate) == [nil, nil])
    }

    // MARK: - Places, issuers and links

    @Test("A job's place is one the description gives where it speaks of that job")
    func jobPlace() throws {
        let description = "I was a cook at Acme in Milan from 2012 to 2016. I studied in Rome."

        let rome = try sanitized(CVData(experience: [job("cook", "Acme", location: "Rome")]), from: description)
        let milan = try sanitized(CVData(experience: [job("cook", "Acme", location: "Milan")]), from: description)

        #expect(rome.experience.first?.location == nil)
        #expect(milan.experience.first?.location == "Milan")
    }

    @Test("The person's own place is not the place of a job")
    func personalPlaceIsNotAJobPlace() throws {
        let result = try sanitized(CVData(experience: [job("", "Acme", location: "Turin")]), from: "I live in Turin. I worked at Acme in 2012.")

        #expect(result.experience.first?.location == nil)
    }

    @Test("A date without a year is the entry's own: a word elsewhere in the description is not")
    func dateWithoutAYear() throws {
        let description = "I live in the present. I worked at Acme from 2012 to 2016."

        let result = try sanitized(CVData(experience: [job("", "Acme", from: "2012", to: "Present")]), from: description)

        #expect(result.experience.first?.endDate == nil)
        #expect(result.experience.first?.startDate == "2012")
    }

    @Test("A month written beside the year for that entry stays as written")
    func monthOfTheEntry() throws {
        let description = "I worked at Acme from March 2012 to June 2016."

        let result = try sanitized(CVData(experience: [job("", "Acme", from: "March 2012", to: "June 2016")]), from: description)

        #expect(result.experience.first?.startDate == "March 2012")
        #expect(result.experience.first?.endDate == "June 2016")
    }

    @Test("A certification's issuer and date are the ones given beside its name")
    func certificationIssuerAndDate() throws {
        let description = "I have a BLS from the Italian Resuscitation Council in 2023. I also have an ACLS from the American Heart Association in 2022."
        let draft = CVData(certifications: [
            Certification(name: "BLS", issuer: "American Heart Association", date: "2022"),
            Certification(name: "ACLS", issuer: "American Heart Association", date: "2022"),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.certifications.map(\.issuer) == [nil, "American Heart Association"])
        #expect(result.certifications.map(\.date) == [nil, "2022"])
    }

    @Test("Certifications listed in one sentence share neither an issuer nor a date unless each clause gives them")
    func certificationsInOneSentence() throws {
        let description = "I hold a BLS and an ACLS from the Italian Resuscitation Council in 2023."
        let draft = CVData(certifications: [
            Certification(name: "BLS", issuer: "Italian Resuscitation Council", date: "2023"),
            Certification(name: "ACLS", issuer: "Italian Resuscitation Council", date: "2023"),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.certifications.map(\.name) == ["BLS", "ACLS"])
        #expect(result.certifications.map(\.issuer) == [nil, "Italian Resuscitation Council"])
        #expect(result.certifications.map(\.date) == [nil, "2023"])
    }

    @Test("A certification's link is one the description gives beside its name, not the person's own site")
    func certificationLink() throws {
        let description = "My site is example.com. I earned a BLS in 2023 at bls.example.org/123."

        let sites = try sanitized(CVData(certifications: [Certification(name: "BLS", url: "example.com")]), from: description)
        let own = try sanitized(CVData(certifications: [Certification(name: "BLS", url: "bls.example.org/123")]), from: description)

        #expect(sites.certifications.first?.url == nil)
        #expect(own.certifications.first?.url == "bls.example.org/123")
    }

    // MARK: - Education

    @Test("Two degrees of one title at two schools are told apart by their schools")
    func sharedDegree() throws {
        let description = "Master at Alpha University 2008-2010. Master at Beta University 2012-2014."
        let draft = CVData(education: [
            Education(degree: "Master", institution: "Alpha University", startDate: "2012", endDate: "2010"),
            Education(degree: "Master", institution: "Beta University", startDate: "2012", endDate: "2010"),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.education.map(\.startDate) == [nil, "2012"])
        #expect(result.education.map(\.endDate) == ["2010", nil])
    }

    @Test("Two degrees at one school are told apart by their degrees")
    func twoDegreesAtOneSchool() throws {
        let description = "I studied Nursing at Alpha University from 2005 to 2008. Then Critical Care at Alpha University from 2008 to 2010."
        let draft = CVData(education: [
            Education(degree: "Nursing", institution: "Alpha University", startDate: "2005", endDate: "2010"),
            Education(degree: "Critical Care", institution: "Alpha University", startDate: "2005", endDate: "2010"),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.education.map(\.startDate) == ["2005", nil])
        #expect(result.education.map(\.endDate) == [nil, "2010"])
    }

    @Test("In a sentence that names two schools, each one is backed by its own clause")
    func twoSchoolsInOneSentence() throws {
        let description = "I studied at Alpha University from 2008 to 2010 and at Beta University from 2012 to 2014."
        let draft = CVData(education: [
            Education(institution: "Alpha University", startDate: "2008", endDate: "2014"),
            Education(institution: "Beta University", startDate: "2008", endDate: "2014"),
        ])

        let result = try sanitized(draft, from: description)

        #expect(result.education.map(\.startDate) == ["2008", nil])
        #expect(result.education.map(\.endDate) == [nil, "2014"])
    }
}
