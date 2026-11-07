import Testing
import Foundation
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVImportingTestSupport
import PrestoCVIntegration
import PrestoCVWorkflowPorts

private let mapper = ImportedCVMapper()
private let id = FixedID(7).id

private func map(_ f: ImportFixture, _ build: (inout ImportedCV) -> Void, language: CVLanguage? = nil,
                 unplaced: [UnplacedText] = []) -> ImportOutcome {
    var cv = ImportedCV()
    build(&cv)
    return mapper.map(f.result(cv, language: language, unplaced: unplaced), id: id)
}

private func date(_ year: Int, _ month: Int? = nil) -> PartialDate {
    guard let date = PartialDate(year: year, month: month) else { preconditionFailure("date") }
    return date
}

@Suite("Imported CV mapper")
struct ImportedCVMapperTests {
    @Test("a full import becomes exactly this CV, in order")
    func fullImportBecomesThisCV() {
        let outcome = mapper.map(FullImport.result, id: id)
        var expected = CV(id: id, language: DocumentLanguage("en"))
        expected.setPersonalDetails(PersonalDetails(
            fullName: "Mira Valdez", professionalTitle: "Platform Engineer", email: EmailAddress("mira.valdez@example.org"),
            phone: PhoneNumber("+49 30 5550123"), location: "Lisbon, Portugal", website: link("https://miravaldez.example.org"),
            summary: "Builds reliable platforms for small teams."))
        expected.setSections(CVSections(
            experiences: [
                Experience(role: "Staff Engineer", company: "Northwind Labs", location: "Hamburg, Germany",
                           period: Period(start: date(2019, 3), end: .date(date(2021, 5))),
                           description: "• Led the migration to containers\n• Cut build times by half"),
                Experience(role: "Junior Developer", company: "Tailspin Works", location: "",
                           period: Period(start: date(2015), end: .unknown), description: "Wrote internal tools"),
            ],
            education: [
                Education(degree: "MSc Computer Science", school: "Technical University of Aveiro",
                          period: Period(start: date(2012), end: .date(date(2014))), description: "Thesis on distributed caches"),
            ],
            skills: [Skill(name: "Go"), Skill(name: "Kubernetes")],
            languages: [LanguageSkill(language: "Portuguese", proficiency: .native), LanguageSkill(language: "English", proficiency: .b2)],
            certifications: [Certification(name: "Certified Kubernetes Administrator", issuer: "Linux Foundation", issued: date(2017))],
            profiles: [ProfileLink(platform: "LinkedIn", link: link("https://linkedin.com/in/miravaldez")),
                       ProfileLink(platform: "GitHub", link: link("https://github.com/miravaldez")),
                       ProfileLink(platform: "XING", link: link("https://xing.com/profile/Mira_Valdez"))],
            interests: ["Chess"]))
        #expect(outcome.cv == expected)
    }

    @Test("an entry keeps its place in the list, and several details become one bulleted description")
    func experienceKeepsOrderAndMultipleDetailsAreBulleted() {
        let f = ImportFixture(text: "Alpha Co Beta Co one two")
        let outcome = map(f) { cv in
            cv.experience = [
                f.experience(role: f.quoted("Alpha"), employer: f.quoted("Co"), details: [f.quoted("one")]),
                f.experience(role: f.quoted("Beta"), employer: f.quoted("Co"), details: [f.quoted("one"), f.quoted("two")]),
            ]
        }
        #expect(outcome.cv.sections.experiences.map(\.role) == ["Alpha", "Beta"])
        #expect(outcome.cv.sections.experiences.map(\.description) == ["one", "• one\n• two"])
    }

    @Test("the education location has no place in the CV: it is reported and kept in the text not imported, never dropped")
    func educationLocationIsMappedOrReported() {
        let f = ImportFixture(text: "MSc Aveiro, Portugal")
        let outcome = map(f) { $0.education = [f.education(degree: f.quoted("MSc"), location: f.quoted("Aveiro, Portugal"))] }
        #expect(outcome.review.contains(ImportReviewItem(field: .educationLocation(1), reason: .locationNotKept, text: "Aveiro, Portugal")))
        #expect(outcome.notImported.contains("Aveiro, Portugal"))
        #expect(!leaves(outcome.cv).contains { $0.value.contains("Aveiro") })
    }

    @Test("the email and the phone keep the typed values the import read")
    func emailAndPhoneKeepTheirTypedValues() {
        let f = ImportFixture(text: "Ada ada@example.org +44 20 7946 0000")
        let outcome = map(f) {
            $0.person.email = f.sourced(EmailAddress("ada@example.org")!, quoting: "ada@example.org")
            $0.person.phone = f.sourced(PhoneNumber("+44 20 7946 0000")!, quoting: "+44 20 7946 0000")
        }
        #expect(outcome.cv.personal.email == EmailAddress("ada@example.org"))
        #expect(outcome.cv.personal.phone == PhoneNumber("+44 20 7946 0000"))
    }

    @Test("a profile link becomes a profile, the first website becomes the website, and another website is kept as text not imported")
    func linksBecomeProfilesOrWebsite() {
        let f = ImportFixture(text: "https://a.example.org https://b.example.org linkedin.com/in/x github.com/y xing.com/profile/z")
        let outcome = map(f) {
            $0.person.links = [
                f.link(.website, f.sourced(link("https://a.example.org"), quoting: "https://a.example.org")),
                f.link(.website, f.sourced(link("https://b.example.org"), quoting: "https://b.example.org")),
                f.link(.linkedIn, f.sourced(link("https://linkedin.com/in/x"), quoting: "linkedin.com/in/x")),
                f.link(.gitHub, f.sourced(link("https://github.com/y"), quoting: "github.com/y")),
                f.link(.xing, f.sourced(link("https://xing.com/profile/z"), quoting: "xing.com/profile/z")),
            ]
        }
        #expect(outcome.cv.personal.website == link("https://a.example.org"))
        #expect(outcome.cv.sections.profiles.map(\.platform) == ["LinkedIn", "GitHub", "XING"])
        #expect(outcome.notImported.contains("https://b.example.org"))
    }

    @Test("a certification year is kept as the date, and a year the CV cannot hold is reported with its text")
    func certificationYearIsKeptOrReported() {
        let f = ImportFixture(text: "Alpha 2017 Beta 1850")
        let outcome = map(f) {
            $0.certifications = [
                f.certification(f.quoted("Alpha"), year: f.sourced(2017, quoting: "2017", reading: .year)),
                f.certification(f.quoted("Beta"), year: f.sourced(1850, quoting: "1850", reading: .year)),
            ]
        }
        #expect(outcome.cv.sections.certifications.map(\.issued) == [date(2017), nil])
        #expect(outcome.review.contains(ImportReviewItem(field: .certificationYear(2), reason: .yearUnreadable, text: "1850")))
        #expect(outcome.notImported.contains("1850"))
    }

    @Test("a language without a CEFR level stays out of the CV and is listed for review and in the text not imported")
    func languageWithoutLevelIsNotAddedButReported() {
        let f = ImportFixture(text: "English B2 Spanish fluent French")
        let outcome = map(f) {
            $0.languages = [
                f.language(f.quoted("English"), level: f.sourced(.b2, quoting: "B2", reading: .languageLevel)),
                f.language(f.quoted("Spanish"), levelWords: f.quoted("fluent", check: .levelNotCEFR)),
                f.language(f.quoted("French")),
            ]
        }
        #expect(outcome.cv.sections.languages == [LanguageSkill(language: "English", proficiency: .b2)])
        #expect(outcome.review.filter { if case .language = $0.field { true } else { false } } == [
            ImportReviewItem(field: .language(2), reason: .levelNotCEFR, text: "Spanish — fluent"),
            ImportReviewItem(field: .language(3), reason: .levelMissing, text: "French"),
        ])
        #expect(outcome.notImported.contains("Spanish — fluent") && outcome.notImported.contains("French"))
    }

    @Test("a period keeps the precision the text gave: a month only where the text states one")
    func periodStaysTheTextsOwnWords() {
        let f = ImportFixture(text: "Alpha 2019 - 03/2021 Beta 03/2019 - today")
        let outcome = map(f) {
            $0.experience = [
                f.experience(role: f.quoted("Alpha"), period: f.sourced(ImportedPeriod(start: yearMonth(2019), end: .date(yearMonth(2021, 3))),
                                                                       quoting: "2019 - 03/2021", reading: .period)),
                f.experience(role: f.quoted("Beta"), period: f.sourced(ImportedPeriod(start: yearMonth(2019, 3), end: .current),
                                                                      quoting: "03/2019 - today", reading: .period)),
            ]
        }
        let periods = outcome.cv.sections.experiences.map(\.period)
        #expect(periods[0] == Period(start: date(2019), end: .date(date(2021, 3))))
        #expect(periods[1] == Period(start: date(2019, 3), end: .current))
        #expect(outcome.review.isEmpty)
    }

    @Test("dates that make no period are reported with the person's words, and the CV keeps none")
    func unreadablePeriodIsReported() {
        let f = ImportFixture(text: "Alpha 2021 - 2019 Beta 1850 - 1860 Gamma 2015")
        let outcome = map(f) {
            $0.experience = [
                f.experience(role: f.quoted("Alpha"), period: f.sourced(ImportedPeriod(start: yearMonth(2021), end: .date(yearMonth(2019))),
                                                                       quoting: "2021 - 2019", reading: .period, check: .periodUnreadable)),
                f.experience(role: f.quoted("Beta"), period: f.sourced(ImportedPeriod(start: yearMonth(1850), end: .date(yearMonth(1860))),
                                                                      quoting: "1850 - 1860", reading: .period)),
                f.experience(role: f.quoted("Gamma"), period: f.sourced(ImportedPeriod(start: yearMonth(2015), end: nil),
                                                                       quoting: "2015", reading: .period)),
            ]
        }
        #expect(outcome.cv.sections.experiences.map(\.period) == [nil, nil, nil])
        #expect(outcome.review == [
            ImportReviewItem(field: .experiencePeriod(1), reason: .periodUnreadable, text: "2021 - 2019"),
            ImportReviewItem(field: .experiencePeriod(2), reason: .periodUnreadable, text: "1850 - 1860"),
            ImportReviewItem(field: .experiencePeriod(3), reason: .periodNotARange, text: "2015"),
        ])
        for piece in ["2021 - 2019", "1850 - 1860", "2015"] { #expect(outcome.notImported.contains(piece)) }
    }

    @Test("a period without an end is never present: its end stays unknown, and only a stated present is current")
    func openEndIsNeverPresent() {
        let f = ImportFixture(text: "Alpha 2019 - Beta 2019 - present")
        let outcome = map(f) {
            $0.experience = [
                f.experience(role: f.quoted("Alpha"), period: f.sourced(ImportedPeriod(start: yearMonth(2019), end: .unstated),
                                                                       quoting: "2019 -", reading: .period, check: .periodOpenEnd)),
                f.experience(role: f.quoted("Beta"), period: f.sourced(ImportedPeriod(start: yearMonth(2019), end: .current),
                                                                      quoting: "2019 - present", reading: .period)),
            ]
        }
        #expect(outcome.cv.sections.experiences.map { $0.period?.end } == [.unknown, .current])
        #expect(outcome.review == [ImportReviewItem(field: .experiencePeriod(1), reason: .periodOpenEnd, text: "2019 -")])
    }

    @Test("the document language is the language the import detected, or none")
    func documentLanguageIsTheDetectedOne() {
        let f = ImportFixture(text: "Ada")
        #expect(map(f, { $0.person.name = f.quoted("Ada") }, language: .de).cv.language == DocumentLanguage("de"))
        #expect(map(f, { $0.person.name = f.quoted("Ada") }, language: nil).cv.language == nil)
    }

    @Test("the same import gives the same CV and review, apart from the id")
    func mappingIsDeterministicApartFromId() {
        let first = mapper.map(FullImport.result, id: FixedID(1).id)
        let second = mapper.map(FullImport.result, id: FixedID(2).id)
        #expect(first.cv.id != second.cv.id)
        #expect(first.review == second.review && first.notImported == second.notImported)
        #expect(first.cv.personal == second.cv.personal && first.cv.sections == second.cv.sections && first.cv.language == second.cv.language)
    }
}
