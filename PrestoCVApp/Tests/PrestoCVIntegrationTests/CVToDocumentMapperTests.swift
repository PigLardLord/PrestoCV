import Testing
import Foundation
import PrestoCVDomain
import PrestoCVIntegration
import CVDocumentModel

private func document(_ cv: CV, language: String = "it") -> CVDocument {
    guard let language = DocumentLanguage(language) else { preconditionFailure("language") }
    return CVToDocumentMapper().map(cv, language: language)
}

@Suite("CV to document mapper")
struct CVToDocumentMapperTests {
    @Test("a fully populated CV becomes exactly this document, sections in print order")
    func fullDocument() {
        let doc = document(Fixtures.fullCV())
        #expect(doc.language == "it")
        #expect(doc.person == Person(name: "Ada Lovelace", professionalTitle: "Analytical Engineer", email: "ada@example.com",
                                     phone: "+44 20 7946 0958", location: "London", website: "https://ada.example"))
        #expect(doc.sections == [
            .summary("Wrote the first program for the Analytical Engine."),
            .experience([
                ExperienceItem(role: "Analyst", company: "Babbage & Co", location: "Cambridge",
                               period: DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .present), description: "Programmed the Engine"),
                ExperienceItem(role: "Clerk", company: "Old Firm", location: "Bath",
                               period: DocumentPeriod(start: DocumentDate(year: 2015), end: .unspecified), description: "Kept ledgers"),
                ExperienceItem(role: "Tutor", company: "Home", location: "Oxford",
                               period: DocumentPeriod(start: DocumentDate(year: 2012, month: 5), end: .date(DocumentDate(year: 2014, month: 8))),
                               description: "Taught mathematics"),
            ]),
            .education([EducationItem(degree: "Mathematics", school: "University",
                                      period: DocumentPeriod(start: DocumentDate(year: 2008, month: 9), end: .date(DocumentDate(year: 2011, month: 6))),
                                      description: "Honours")]),
            .skills([SkillItem(name: "Swift", rating: 4), SkillItem(name: "Git", rating: 3)]),
            .languages([LanguageItem(language: "English", level: .native), LanguageItem(language: "Italiano", level: .b2)]),
            .certifications([CertificationItem(name: "Swift Certified", issuer: "Apple", year: 2021, url: "https://cert.example/one",
                                               description: "Concurrency")]),
            .profiles([ProfileLink(platform: "GitHub", url: "https://github.com/ada")]),
            .interests(["Poetry", "Chess"]),
        ])
    }

    @Test("the order of the entries is the order the person chose")
    func entryOrderIsKept() {
        let doc = document(Fixtures.fullCV())
        guard case .experience(let items)? = doc.sections.first(where: { if case .experience = $0 { true } else { false } }) else {
            Issue.record("no experience section"); return
        }
        #expect(items.map(\.role) == ["Analyst", "Clerk", "Tutor"])
    }

    @Test("a CV with only a name has a header and no sections: empty and blank values are not printed")
    func emptyValuesAreOmitted() {
        var cv = CV(id: Fixtures.id)
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada", professionalTitle: "  ", location: "", summary: " \n"))
        var sections = CVSections()
        sections.experiences = [Experience(role: "Clerk", company: "Old Firm", location: " ", description: "")]
        cv.setSections(sections)
        let doc = document(cv)
        #expect(doc.person == Person(name: "Ada"))
        #expect(doc.sections == [.experience([ExperienceItem(role: "Clerk", company: "Old Firm")])])
    }

    @Test("a skill without a level has no rating, and a certification without a date has no year")
    func missingOptionalValues() {
        var cv = CV(id: Fixtures.id)
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        var sections = CVSections()
        sections.skills = [Skill(name: "Git")]
        sections.certifications = [Certification(name: "Swift Certified", issuer: "Apple")]
        cv.setSections(sections)
        #expect(document(cv).sections == [.skills([SkillItem(name: "Git")]), .certifications([CertificationItem(name: "Swift Certified", issuer: "Apple")])])
    }

    @Test("every language level has its own document level", arguments: LanguageProficiency.allCases)
    func languageLevels(level: LanguageProficiency) {
        var cv = CV(id: Fixtures.id)
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        var sections = CVSections()
        sections.languages = [LanguageSkill(language: "English", proficiency: level)]
        cv.setSections(sections)
        guard case .languages(let items)? = document(cv).sections.first else { Issue.record("no languages section"); return }
        #expect(items.map(\.level.rawValue) == [level.rawValue])
    }

    @Test("a month stays with its year, and an end that is unknown is never 'present'")
    func periods() {
        var cv = CV(id: Fixtures.id)
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        var sections = CVSections()
        sections.education = [
            Education(degree: "A", school: "S", period: Fixtures.period(Fixtures.date(2000), .unknown)),
            Education(degree: "B", school: "S", period: Fixtures.period(Fixtures.date(2001, 2), .current)),
        ]
        cv.setSections(sections)
        guard case .education(let items)? = document(cv).sections.first else { Issue.record("no education section"); return }
        #expect(items.map(\.period) == [
            DocumentPeriod(start: DocumentDate(year: 2000), end: .unspecified),
            DocumentPeriod(start: DocumentDate(year: 2001, month: 2), end: .present),
        ])
    }

    @Test("the mapping is deterministic: the same CV gives the same document")
    func deterministic() {
        #expect(document(Fixtures.fullCV()) == document(Fixtures.fullCV()))
    }

    @Test("the document language is the one asked for, not the CV's own")
    func languageIsTheArgument() {
        #expect(document(Fixtures.fullCV(), language: "pt-br").language == "pt-BR")
    }

    @Test("the mapped document passes the exporter's validation", arguments: ["Ada", " Ada ", "A", String(repeating: "x", count: 5_000)])
    func saveableCVsMapToValidDocuments(name: String) throws {
        var cv = Fixtures.fullCV()
        var personal = cv.personal
        personal.fullName = name
        cv.setPersonalDetails(personal)
        #expect(cv.canBeSaved)
        try CVDocumentValidator.validate(document(cv))
    }
}
