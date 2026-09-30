import Testing
import PrestoCVDomain
import PrestoCVIntegration
import PrestoCVCoreTestSupport
import CVDocumentModel

// MARK: - Builders

func partialDate(_ year: Int, _ month: Int? = nil) throws -> PartialDate { try #require(PartialDate(year: year, month: month)) }
func webLink(_ raw: String) throws -> WebLink { try #require(WebLink(raw)) }
func documentLanguage(_ raw: String) throws -> DocumentLanguage { try #require(DocumentLanguage(raw)) }

/// A CV that holds only what a test sets: a name, and optionally details and sections.
private func cv(_ details: PersonalDetails = PersonalDetails(fullName: "Ada"), sections: CVSections = CVSections()) -> CV {
    CV(id: SequentialIDGenerator().next(), personal: details, sections: sections)
}

private func experience(_ entry: Experience) -> CV { cv(sections: CVSections(experiences: [entry])) }

private extension CVDocument {
    var summary: String? { sections.lazy.compactMap { if case .summary(let text) = $0 { text } else { nil } }.first }
    var experience: [ExperienceItem]? { sections.lazy.compactMap { if case .experience(let items) = $0 { items } else { nil } }.first }
    var education: [EducationItem]? { sections.lazy.compactMap { if case .education(let items) = $0 { items } else { nil } }.first }
    var skills: [SkillItem]? { sections.lazy.compactMap { if case .skills(let items) = $0 { items } else { nil } }.first }
    var languages: [LanguageItem]? { sections.lazy.compactMap { if case .languages(let items) = $0 { items } else { nil } }.first }
    var certifications: [CertificationItem]? { sections.lazy.compactMap { if case .certifications(let items) = $0 { items } else { nil } }.first }
    var profiles: [CVDocumentModel.ProfileLink]? { sections.lazy.compactMap { if case .profiles(let items) = $0 { items } else { nil } }.first }
    var interests: [String]? { sections.lazy.compactMap { if case .interests(let items) = $0 { items } else { nil } }.first }

    /// The kind of each section, in document order.
    var kinds: [String] {
        sections.map { section in
            switch section {
            case .summary: "summary"
            case .experience: "experience"
            case .education: "education"
            case .skills: "skills"
            case .languages: "languages"
            case .certifications: "certifications"
            case .profiles: "profiles"
            case .interests: "interests"
            }
        }
    }
}

// MARK: - Behaviour

@Suite("CV to document mapper (#88)")
struct CVToDocumentMapperTests {
    let mapper = CVToDocumentMapper()
    let italian: DocumentLanguage
    let fixture: CVDocument

    init() throws {
        italian = try documentLanguage("it")
        fixture = mapper.map(FixtureCV.full(), language: italian)
    }

    // MARK: Document and person

    @Test("the document is in the language it is asked for, not the language of the CV")
    func languageOfDocument() throws {
        var english = cv()
        english.setLanguage(try documentLanguage("en"))

        #expect(mapper.map(english, language: try documentLanguage("pt-BR")).language == "pt-BR")
        #expect(mapper.map(cv(), language: italian).language == "it")
    }

    @Test("the person of the fixture is mapped field by field")
    func fixturePerson() {
        #expect(fixture.person == Person(name: "Ada Lovelace", professionalTitle: "iOS Engineer", email: "ada@example.com",
                                         phone: "+39 06 1234567", location: "Roma", website: "https://ada.example"))
    }

    @Test("a person with a name only has no other detail")
    func nameOnlyPerson() {
        #expect(mapper.map(cv(), language: italian).person == Person(name: "Ada"))
    }

    @Test("a title and a location of white space only are left out")
    func blankPersonText() {
        let blank = cv(PersonalDetails(fullName: "Ada", professionalTitle: " \t", location: "\n  "))

        let person = mapper.map(blank, language: italian).person

        #expect(person.professionalTitle == nil)
        #expect(person.location == nil)
    }

    @Test("a title and a location are passed as they are, spaces included")
    func paddedPersonText() {
        let padded = cv(PersonalDetails(fullName: "Ada", professionalTitle: "  Engineer ", location: " Roma  "))

        let person = mapper.map(padded, language: italian).person

        #expect(person.professionalTitle == "  Engineer ")
        #expect(person.location == " Roma  ")
    }

    // MARK: Sections of the fixture

    @Test("the summary of the fixture is mapped")
    func fixtureSummary() { #expect(fixture.summary == "Builds careful software.") }

    @Test("the experience of the fixture is mapped field by field")
    func fixtureExperience() {
        #expect(fixture.experience == [
            ExperienceItem(role: "Engineer", company: "Analytical", location: "London",
                           period: DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .present), description: "Engines"),
        ])
    }

    @Test("the education of the fixture is mapped field by field")
    func fixtureEducation() {
        #expect(fixture.education == [
            EducationItem(degree: "Mathematics", school: "Home",
                          period: DocumentPeriod(start: DocumentDate(year: 2012, month: 9), end: .date(DocumentDate(year: 2015, month: 7))),
                          description: "Tutored"),
        ])
    }

    @Test("the skills of the fixture are mapped with their ratings")
    func fixtureSkills() { #expect(fixture.skills == [SkillItem(name: "Swift", rating: 5), SkillItem(name: "Git", rating: 3)]) }

    @Test("the languages of the fixture are mapped with their levels")
    func fixtureLanguages() {
        #expect(fixture.languages == [LanguageItem(language: "Italian", level: .native), LanguageItem(language: "English", level: .c1)])
    }

    @Test("the certifications of the fixture are mapped with their year and link")
    func fixtureCertifications() {
        #expect(fixture.certifications == [
            CertificationItem(name: "Swift Certified", issuer: "Apple", year: 2021, url: "https://cert.example/1", description: "Concurrency"),
        ])
    }

    @Test("the profiles of the fixture are mapped with their links")
    func fixtureProfiles() { #expect(fixture.profiles == [CVDocumentModel.ProfileLink(platform: "GitHub", url: "https://github.com/ada")]) }

    @Test("the interests of the fixture are mapped in order")
    func fixtureInterests() { #expect(fixture.interests == ["Chess", "Running"]) }

    // MARK: Sections: order and presence

    @Test("sections come in the fixed order")
    func sectionOrder() {
        #expect(fixture.kinds == ["summary", "experience", "education", "skills", "languages", "certifications", "profiles", "interests"])
    }

    @Test("a CV that holds only a name has no section")
    func noSections() { #expect(mapper.map(cv(), language: italian).sections.isEmpty) }

    @Test("an empty section is left out and the others keep their order")
    func emptySectionsLeftOut() throws {
        let sparse = cv(sections: CVSections(skills: [Skill(name: "Swift")], profiles: [ProfileLink(platform: "GitHub", link: try webLink("https://github.com/ada"))],
                                             interests: ["Chess"]))

        #expect(mapper.map(sparse, language: italian).kinds == ["skills", "profiles", "interests"])
    }

    @Test("a summary of white space only is left out", arguments: ["", " ", "\n\t  \n"])
    func blankSummary(summary: String) {
        let blank = cv(PersonalDetails(fullName: "Ada", summary: summary))

        #expect(mapper.map(blank, language: italian).summary == nil)
    }

    @Test("a summary is passed as it is, spaces included")
    func paddedSummary() {
        let padded = cv(PersonalDetails(fullName: "Ada", summary: "  Careful.\n"))

        #expect(mapper.map(padded, language: italian).summary == "  Careful.\n")
    }

    // MARK: Optional text of entries

    @Test("the location and description of an experience of white space only are left out")
    func blankExperienceText() {
        let blank = experience(Experience(role: "Engineer", company: "Analytical", location: " ", description: "\n "))

        let item = mapper.map(blank, language: italian).experience?.first

        #expect(item?.location == nil)
        #expect(item?.description == nil)
    }

    @Test("the location and description of an experience are passed as they are, spaces included")
    func paddedExperienceText() {
        let padded = experience(Experience(role: "Engineer", company: "Analytical", location: " London ", description: "  Engines\n"))

        let item = mapper.map(padded, language: italian).experience?.first

        #expect(item?.location == " London ")
        #expect(item?.description == "  Engines\n")
    }

    @Test("the description of an education of white space only is left out, and a padded one is kept")
    func educationDescription() {
        let blank = cv(sections: CVSections(education: [Education(degree: "Mathematics", school: "Home", description: " \n")]))
        let padded = cv(sections: CVSections(education: [Education(degree: "Mathematics", school: "Home", description: " Tutored ")]))

        #expect(mapper.map(blank, language: italian).education?.first?.description == nil)
        #expect(mapper.map(padded, language: italian).education?.first?.description == " Tutored ")
    }

    @Test("the description of a certification of white space only is left out, and a padded one is kept")
    func certificationDescription() {
        let blank = cv(sections: CVSections(certifications: [Certification(name: "Swift Certified", issuer: "Apple", description: "\t")]))
        let padded = cv(sections: CVSections(certifications: [Certification(name: "Swift Certified", issuer: "Apple", description: " Concurrency ")]))

        #expect(mapper.map(blank, language: italian).certifications?.first?.description == nil)
        #expect(mapper.map(padded, language: italian).certifications?.first?.description == " Concurrency ")
    }

    // MARK: Periods

    @Test("a current period has no end date and ends at the present")
    func currentPeriod() throws {
        let current = experience(Experience(role: "Engineer", company: "Analytical", period: Period(start: try partialDate(2019, 3), end: .current)))

        #expect(mapper.map(current, language: italian).experience?.first?.period
                == DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .present))
    }

    @Test("a period with a date for its end keeps the date, at the precision it was given")
    func datedPeriod() throws {
        let dated = experience(Experience(role: "Engineer", company: "Analytical",
                                          period: Period(start: try partialDate(2012), end: .date(try partialDate(2015, 7)))))

        #expect(mapper.map(dated, language: italian).experience?.first?.period
                == DocumentPeriod(start: DocumentDate(year: 2012), end: .date(DocumentDate(year: 2015, month: 7))))
    }

    @Test("a period that ended on an unknown date is unspecified, never the present")
    func unknownEnd() throws {
        let unknown = experience(Experience(role: "Clerk", company: "Old Firm", period: Period(start: try partialDate(2015, 1), end: .unknown)))

        #expect(mapper.map(unknown, language: italian).experience?.first?.period
                == DocumentPeriod(start: DocumentDate(year: 2015, month: 1), end: .unspecified))
    }

    @Test("an entry without a period has none in the document")
    func noPeriod() {
        let undated = cv(sections: CVSections(experiences: [Experience(role: "Engineer", company: "Analytical")],
                                              education: [Education(degree: "Mathematics", school: "Home")]))

        let document = mapper.map(undated, language: italian)

        #expect(document.experience?.first?.period == nil)
        #expect(document.education?.first?.period == nil)
    }

    // MARK: Levels, links and dates of certifications

    @Test("a skill without a level has no rating")
    func unratedSkill() {
        let unrated = cv(sections: CVSections(skills: [Skill(name: "Git")]))

        #expect(mapper.map(unrated, language: italian).skills == [SkillItem(name: "Git")])
    }

    @Test("each language proficiency maps to the level of the same name", arguments: LanguageProficiency.allCases)
    func proficiency(proficiency: LanguageProficiency) {
        let spoken = cv(sections: CVSections(languages: [LanguageSkill(language: "Italian", proficiency: proficiency)]))

        let level = mapper.map(spoken, language: italian).languages?.first?.level

        #expect(level?.rawValue == proficiency.rawValue)
    }

    @Test("a certification keeps the year it was issued, not the month")
    func certificationYear() throws {
        let issued = cv(sections: CVSections(certifications: [Certification(name: "Swift Certified", issuer: "Apple", issued: try partialDate(2021, 6))]))

        #expect(mapper.map(issued, language: italian).certifications?.first?.year == 2021)
    }

    @Test("a certification without a date or a link has neither a year nor an address")
    func certificationWithoutDateOrLink() {
        let bare = cv(sections: CVSections(certifications: [Certification(name: "Swift Certified", issuer: "Apple")]))

        #expect(mapper.map(bare, language: italian).certifications == [CertificationItem(name: "Swift Certified", issuer: "Apple")])
    }

    // MARK: Determinism and what is not printed

    @Test("mapping the same CV twice gives equal documents")
    func deterministic() {
        #expect(mapper.map(FixtureCV.full(), language: italian) == mapper.map(FixtureCV.full(), language: italian))
    }

    @Test("identity, title, design, revision and dates of storage do not reach the document")
    func notPrinted() async throws {
        let original = FixtureCV.full()
        var other = FixtureCV.full(id: SequentialIDGenerator().next())
        other.rename("Another name for the list")
        other.choose(design: nil)
        let stored = try await InMemoryCVRepository().create(original)

        #expect(stored.revision == 1 && stored.createdAt != nil)
        #expect(mapper.map(other, language: italian) == fixture)
        #expect(mapper.map(stored, language: italian) == fixture)
    }
}
