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
            .skills([SkillItem(name: "Swift", rating: 4), SkillItem(name: "Git", rating: 2)]),
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

    private func cv(_ configure: (inout CVSections) -> Void) -> CV {
        var cv = CV(id: Fixtures.id)
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        var sections = CVSections()
        configure(&sections)
        cv.setSections(sections)
        return cv
    }

    @Test("a skill with a blank name is not printed, whatever its level")
    func blankSkill() {
        let doc = document(cv { $0.skills = [Skill(name: "  ", level: SkillLevel(2)), Skill(name: "Git")] })
        #expect(doc.sections == [.skills([SkillItem(name: "Git")])])
        #expect(document(cv { $0.skills = [Skill(name: " \n")] }).sections.isEmpty)
    }

    @Test("a language with a blank name is not printed, whatever its level")
    func blankLanguage() {
        let doc = document(cv { $0.languages = [LanguageSkill(language: " ", proficiency: .c1), LanguageSkill(language: "English", proficiency: .native)] })
        #expect(doc.sections == [.languages([LanguageItem(language: "English", level: .native)])])
        #expect(document(cv { $0.languages = [LanguageSkill(language: "", proficiency: .a1)] }).sections.isEmpty)
    }

    @Test("a certification with no value in any field is not printed; one with some prints what it has, a blank name too")
    func blankCertification() {
        let link = Fixtures.link("https://cert.example/one")
        let doc = document(cv {
            $0.certifications = [Certification(name: " ", issuer: "Apple", issued: Fixtures.date(2021), link: link, description: "x"),
                                 Certification(name: "Swift Certified", issuer: " "),
                                 Certification(name: "", issuer: "", issued: Fixtures.date(2019)),
                                 Certification(name: "\n", issuer: " ", description: "Passed the exam")]
        })
        #expect(doc.sections == [.certifications([
            CertificationItem(name: "", issuer: "Apple", year: 2021, url: "https://cert.example/one", description: "x"),
            CertificationItem(name: "Swift Certified", issuer: ""), CertificationItem(name: "", issuer: "", year: 2019),
            CertificationItem(name: "", issuer: "", description: "Passed the exam"),
        ])])
        #expect(document(cv { $0.certifications = [Certification(name: " ", issuer: "\n", description: " ")] }).sections.isEmpty)
    }

    @Test("a profile always has its address, so it prints even without a platform name")
    func profileWithoutPlatform() {
        let doc = document(cv { $0.profiles = [ProfileLink(platform: "  ", link: Fixtures.link("https://github.com/ada"))] })
        #expect(doc.sections == [.profiles([ProfileLink(platform: "", url: "https://github.com/ada")])])
    }

    @Test("an experience with no value in any field is not printed; one with some prints what it has")
    func blankExperience() {
        let period = Fixtures.period(Fixtures.date(2019), .current)
        let doc = document(cv {
            $0.experiences = [Experience(role: " ", company: "", location: " ", description: "\n"),
                              Experience(role: " ", company: "Old Firm"),
                              Experience(role: "Clerk", company: ""),
                              Experience(role: "", company: "", period: period),
                              Experience(role: "", company: "", description: "Kept ledgers")]
        })
        #expect(doc.sections == [.experience([
            ExperienceItem(role: "", company: "Old Firm"), ExperienceItem(role: "Clerk", company: ""),
            ExperienceItem(role: "", company: "", period: DocumentPeriod(start: DocumentDate(year: 2019), end: .present)),
            ExperienceItem(role: "", company: "", description: "Kept ledgers"),
        ])])
        #expect(document(cv { $0.experiences = [Experience(role: "", company: "")] }).sections.isEmpty)
    }

    @Test("an education entry with no value in any field is not printed; one with some prints what it has")
    func blankEducation() {
        let doc = document(cv {
            $0.education = [Education(degree: " ", school: ""), Education(degree: "", school: "University"), Education(degree: "Mathematics", school: " "),
                            Education(degree: "", school: "", description: "Honours")]
        })
        #expect(doc.sections == [.education([
            EducationItem(degree: "", school: "University"), EducationItem(degree: "Mathematics", school: ""),
            EducationItem(degree: "", school: "", description: "Honours"),
        ])])
        #expect(document(cv { $0.education = [Education(degree: "", school: " ")] }).sections.isEmpty)
    }

    @Test("a line break of any kind in a multi-line field becomes one line feed; the CV removes a vertical tab and a form feed before it (text rule, #389)",
          arguments: [("one\r\ntwo", "one\ntwo"), ("one\rtwo", "one\ntwo"), ("one\ntwo", "one\ntwo"), ("one\r\rtwo", "one\n\ntwo"),
                      ("one\u{0B}two", "onetwo"), ("one\u{0C}two", "onetwo"), ("one\u{85}two", "one\ntwo")])
    func multiLineBreaks(raw: String, expected: String) {
        var personal = PersonalDetails(fullName: "Ada")
        personal.summary = raw
        var cv = cv { $0.experiences = [Experience(role: "Clerk", company: "Old Firm", description: raw)] }
        cv.setPersonalDetails(personal)
        #expect(document(cv).sections == [.summary(expected), .experience([ExperienceItem(role: "Clerk", company: "Old Firm", description: expected)])])
    }

    @Test("a tab becomes a space, in a multi-line and in a single-line field")
    func tab() {
        var personal = PersonalDetails(fullName: "Ada\tLovelace")
        personal.summary = "a\tb"
        var cv = cv { $0.skills = [Skill(name: "Swift\t5")] }
        cv.setPersonalDetails(personal)
        #expect(document(cv).person.name == "Ada Lovelace")
        #expect(document(cv).sections == [.summary("a b"), .skills([SkillItem(name: "Swift 5")])])
    }

    @Test("a line break in a single-line field becomes a space", arguments: ["\n", "\r\n", "\r", "\u{85}"])
    func singleLineBreaks(lineBreak: String) {
        var personal = PersonalDetails(fullName: "Ada\(lineBreak)Lovelace", professionalTitle: "Lead\(lineBreak)Engineer", location: "Bath\(lineBreak)UK")
        personal.summary = "kept"
        var cv = cv {
            $0.experiences = [Experience(role: "Lead\(lineBreak)Dev", company: "Old\(lineBreak)Firm", location: "A\(lineBreak)B")]
            $0.education = [Education(degree: "BSc\(lineBreak)Maths", school: "Uni\(lineBreak)Home")]
            $0.skills = [Skill(name: "Swift\(lineBreak)UI")]
            $0.languages = [LanguageSkill(language: "Swiss\(lineBreak)German", proficiency: .b2)]
            $0.certifications = [Certification(name: "Cert\(lineBreak)One", issuer: "Issuer\(lineBreak)Inc")]
            $0.profiles = [ProfileLink(platform: "Git\(lineBreak)Hub", link: Fixtures.link("https://github.com/ada"))]
            $0.setInterests(["Board\(lineBreak)games"])
        }
        cv.setPersonalDetails(personal)
        let doc = document(cv)
        #expect(doc.person == Person(name: "Ada Lovelace", professionalTitle: "Lead Engineer", location: "Bath UK"))
        #expect(doc.sections == [
            .summary("kept"),
            .experience([ExperienceItem(role: "Lead Dev", company: "Old Firm", location: "A B")]),
            .education([EducationItem(degree: "BSc Maths", school: "Uni Home")]),
            .skills([SkillItem(name: "Swift UI")]),
            .languages([LanguageItem(language: "Swiss German", level: .b2)]),
            .certifications([CertificationItem(name: "Cert One", issuer: "Issuer Inc")]),
            .profiles([ProfileLink(platform: "Git Hub", url: "https://github.com/ada")]),
            .interests(["Board games"]),
        ])
    }

    @Test("every character the exporter refuses is left out of every text field", arguments: ["\u{07}", "\u{00}", "\u{1B}", "\u{7F}", "\u{9F}", "\u{202E}", "\u{2066}"])
    func refusedCharacters(character: String) throws {
        let dirty = "x\(character)y"
        var personal = PersonalDetails(fullName: dirty, professionalTitle: dirty, location: dirty)
        personal.summary = dirty
        var cv = cv {
            $0.experiences = [Experience(role: dirty, company: dirty, location: dirty, description: dirty)]
            $0.education = [Education(degree: dirty, school: dirty, description: dirty)]
            $0.skills = [Skill(name: dirty)]
            $0.languages = [LanguageSkill(language: dirty, proficiency: .c2)]
            $0.certifications = [Certification(name: dirty, issuer: dirty, description: dirty)]
            $0.profiles = [ProfileLink(platform: dirty, link: Fixtures.link("https://github.com/ada"))]
            $0.setInterests([dirty])
        }
        cv.setPersonalDetails(personal)
        let doc = document(cv)
        try CVDocumentValidator.validate(doc)
        #expect(doc.person.name == "xy")
        #expect(doc.sections.first == .summary("xy"))
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
