import Testing
import CVDocumentModel

@Suite("CVDocumentValidator · every section is bounded, with its own reason")
struct DocumentContentTests {
    static let person = Person(name: "Ada")

    static func document(_ section: Section) -> CVDocument { CVDocument(language: "en", person: person, sections: [section]) }

    static func reason(of document: CVDocument) -> String? {
        do throws(CVDocumentValidator.Invalid) { try CVDocumentValidator.validate(document); return nil } catch { return error.reason }
    }

    static let tooManyItems: [(Section, String)] = [
        (.experience(Array(repeating: ExperienceItem(role: "r", company: "c"), count: 201)), "too many entries"),
        (.education(Array(repeating: EducationItem(degree: "d", school: "s"), count: 201)), "too many entries"),
        (.skills(Array(repeating: SkillItem(name: "n"), count: 201)), "too many skills"),
        (.languages(Array(repeating: LanguageItem(language: "l", level: .b2), count: 201)), "too many languages"),
        (.certifications(Array(repeating: CertificationItem(name: "n", issuer: "i"), count: 201)), "too many certifications"),
        (.profiles(Array(repeating: ProfileLink(platform: "p", url: "u"), count: 201)), "too many profiles"),
        (.interests(Array(repeating: "i", count: 201)), "too many interests"),
    ]

    @Test("a section with more than 200 items is refused, and one with exactly 200 is not", arguments: tooManyItems)
    func itemCounts(section: Section, reason: String) {
        #expect(Self.reason(of: Self.document(section)) == reason)
        #expect(Self.reason(of: CVDocument(language: "en", person: Self.person, sections: [Self.shortened(section)])) == nil)
    }

    static func shortened(_ section: Section) -> Section {
        switch section {
        case .experience(let items): .experience(Array(items.prefix(200)))
        case .education(let items): .education(Array(items.prefix(200)))
        case .skills(let items): .skills(Array(items.prefix(200)))
        case .languages(let items): .languages(Array(items.prefix(200)))
        case .certifications(let items): .certifications(Array(items.prefix(200)))
        case .profiles(let items): .profiles(Array(items.prefix(200)))
        case .interests(let items): .interests(Array(items.prefix(200)))
        case .summary: section
        }
    }

    static let controlCharacter = "x\u{7}"
    static let badTexts: [(CVDocument, String)] = [
        (CVDocument(language: controlCharacter, person: person, sections: []), "language"),
        (CVDocument(language: "en", person: Person(name: controlCharacter), sections: []), "name"),
        (CVDocument(language: "en", person: Person(name: "A", professionalTitle: controlCharacter), sections: []), "title"),
        (CVDocument(language: "en", person: Person(name: "A", email: controlCharacter), sections: []), "email"),
        (CVDocument(language: "en", person: Person(name: "A", phone: controlCharacter), sections: []), "phone"),
        (CVDocument(language: "en", person: Person(name: "A", location: controlCharacter), sections: []), "location"),
        (CVDocument(language: "en", person: Person(name: "A", website: controlCharacter), sections: []), "website"),
        (document(.summary(controlCharacter)), "summary"),
        (document(.experience([ExperienceItem(role: controlCharacter, company: "c")])), "role"),
        (document(.experience([ExperienceItem(role: "r", company: controlCharacter)])), "company"),
        (document(.experience([ExperienceItem(role: "r", company: "c", location: controlCharacter)])), "location"),
        (document(.experience([ExperienceItem(role: "r", company: "c", description: controlCharacter)])), "description"),
        (document(.education([EducationItem(degree: controlCharacter, school: "s")])), "degree"),
        (document(.education([EducationItem(degree: "d", school: controlCharacter)])), "school"),
        (document(.education([EducationItem(degree: "d", school: "s", description: controlCharacter)])), "description"),
        (document(.skills([SkillItem(name: controlCharacter)])), "skill"),
        (document(.languages([LanguageItem(language: controlCharacter, level: .a1)])), "language"),
        (document(.certifications([CertificationItem(name: controlCharacter, issuer: "i")])), "certification"),
        (document(.certifications([CertificationItem(name: "n", issuer: controlCharacter)])), "issuer"),
        (document(.certifications([CertificationItem(name: "n", issuer: "i", url: controlCharacter)])), "url"),
        (document(.certifications([CertificationItem(name: "n", issuer: "i", description: controlCharacter)])), "description"),
        (document(.profiles([ProfileLink(platform: controlCharacter, url: "u")])), "platform"),
        (document(.profiles([ProfileLink(platform: "p", url: controlCharacter)])), "url"),
        (document(.interests([controlCharacter])), "interest"),
    ]

    @Test("a control character in any field is refused, and the reason names the field", arguments: badTexts)
    func controlCharacters(document: CVDocument, field: String) {
        #expect(Self.reason(of: document) == "\(field) is too long, the document is too large, or it has control characters")
    }

    static func experience(_ period: DocumentPeriod) -> CVDocument {
        document(.experience([ExperienceItem(role: "r", company: "c", period: period)]))
    }

    @Test("a period ends no earlier than it starts; a date without a month spans its whole year", arguments: [
        (DocumentDate(year: 2020, month: 6), DocumentDate(year: 2020, month: 6), true), (DocumentDate(year: 2020, month: 6), DocumentDate(year: 2020, month: 5), false),
        (DocumentDate(year: 2020, month: 6), DocumentDate(year: 2020), true), (DocumentDate(year: 2020), DocumentDate(year: 2020, month: 1), true),
        (DocumentDate(year: 2021), DocumentDate(year: 2020), false), (DocumentDate(year: 2020), DocumentDate(year: 2021, month: 1), true),
    ])
    func periodOrder(start: DocumentDate, end: DocumentDate, valid: Bool) {
        let reason = Self.reason(of: Self.experience(DocumentPeriod(start: start, end: .date(end))))
        #expect(reason == (valid ? nil : "end before start"))
    }

    @Test("a date outside 1900 to 2200 or with a month outside 1 to 12 is refused", arguments: [
        DocumentDate(year: 1899), DocumentDate(year: 2201), DocumentDate(year: 2020, month: 0), DocumentDate(year: 2020, month: 13),
    ])
    func dates(date: DocumentDate) {
        #expect(Self.reason(of: Self.experience(DocumentPeriod(start: date, end: .present))) == "date")
        #expect(Self.reason(of: Self.experience(DocumentPeriod(start: DocumentDate(year: 2000), end: .date(date)))) == "date")
    }

    @Test("a rating outside 1 to 5 is refused", arguments: [(0, false), (1, true), (5, true), (6, false), (-1, false)])
    func ratings(rating: Int, valid: Bool) {
        #expect(Self.reason(of: Self.document(.skills([SkillItem(name: "n", rating: rating)]))) == (valid ? nil : "rating"))
    }

    @Test("a certification year outside 1900 to 2200 is refused", arguments: [(1899, false), (1900, true), (2200, true), (2201, false)])
    func certificationYears(year: Int, valid: Bool) {
        let reason = Self.reason(of: Self.document(.certifications([CertificationItem(name: "n", issuer: "i", year: year)])))
        #expect(reason == (valid ? nil : "date"))
    }
}
