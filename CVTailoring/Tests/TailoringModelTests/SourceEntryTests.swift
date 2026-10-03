import Testing
import TailoringModel

@Suite("ADR 0013 / R6, R8 · the entries of a source CV")
struct SourceEntryTests {
    // MARK: Personal details

    @Test("personal details are built as written")
    func personalDetails() throws {
        let details = try SourcePersonalDetails(fullName: "Ada Lovelace", professionalTitle: "Analyst", email: "ada@example.com",
                                                phone: "+44 20 7946 0000", location: "London", website: "https://example.com")
        #expect(details.fullName == "Ada Lovelace")
        #expect(details.professionalTitle == "Analyst")
        #expect(details.email == "ada@example.com")
        #expect(details.phone == "+44 20 7946 0000")
        #expect(details.location == "London")
        #expect(details.website == "https://example.com")
    }

    @Test("everything but the name may be left out")
    func personalDetailsMinimal() throws {
        let details = try SourcePersonalDetails(fullName: "Ada")
        #expect(details.professionalTitle.isEmpty && details.location.isEmpty)
        #expect(details.email == nil && details.phone == nil && details.website == nil)
    }

    @Test("a name that is empty after trimming is refused", arguments: ["", " ", "\t\n ", "\u{00A0}"])
    func personalDetailsNeedAName(name: String) {
        #expect(throws: TailoringModelError.emptyField(.fullName)) { try SourcePersonalDetails(fullName: name) }
    }

    @Test("the name keeps its spaces as written")
    func nameAsWritten() throws {
        #expect(try SourcePersonalDetails(fullName: "  Ada Lovelace ").fullName == "  Ada Lovelace ")
    }

    static let personalFields: [TextFieldCase] = [
        TextFieldCase(.fullName) { _ = try SourcePersonalDetails(fullName: $0) },
        TextFieldCase(.professionalTitle) { _ = try SourcePersonalDetails(fullName: "A", professionalTitle: $0) },
        TextFieldCase(.email) { _ = try SourcePersonalDetails(fullName: "A", email: $0) },
        TextFieldCase(.phone) { _ = try SourcePersonalDetails(fullName: "A", phone: $0) },
        TextFieldCase(.location) { _ = try SourcePersonalDetails(fullName: "A", location: $0) },
        TextFieldCase(.website) { _ = try SourcePersonalDetails(fullName: "A", website: $0) },
    ]

    @Test("each personal field accepts 10,000 bytes and refuses one more", arguments: personalFields)
    func personalBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    // MARK: Skills, languages, profiles

    @Test("a skill has a name and an optional level from 1 to 5", arguments: [nil, 1, 2, 3, 4, 5] as [Int?])
    func skill(level: Int?) throws {
        let skill = try SourceSkill(name: "Swift", level: level)
        #expect(skill.name == "Swift")
        #expect(skill.level == level)
    }

    @Test("a skill level outside 1 to 5 is refused", arguments: [Int.min, -1, 0, 6, 10, Int.max])
    func skillLevelOutOfRange(level: Int) {
        #expect(throws: TailoringModelError.invalidSkillLevel) { try SourceSkill(name: "Swift", level: level) }
    }

    @Test("a skill has no level unless one is given")
    func skillWithoutLevel() throws {
        #expect(try SourceSkill(name: "Swift").level == nil)
    }

    @Test("a language has a name and a level, CEFR or native", arguments: [
        LanguageLevel.a1, .a2, .b1, .b2, .c1, .c2, .native,
    ])
    func language(level: LanguageLevel) throws {
        let language = try SourceLanguage(name: "Italian", proficiency: level)
        #expect(language.name == "Italian")
        #expect(language.proficiency == level)
    }

    @Test("there are seven language levels")
    func languageLevels() {
        #expect(LanguageLevel.allCases.count == 7)
    }

    @Test("a profile has a platform and a link")
    func profile() throws {
        let profile = try SourceProfile(platform: "GitHub", link: "https://github.com/ada")
        #expect(profile.platform == "GitHub")
        #expect(profile.link == "https://github.com/ada")
    }

    static let entryFields: [TextFieldCase] = [
        TextFieldCase(.skillName) { _ = try SourceSkill(name: $0) },
        TextFieldCase(.languageName) { _ = try SourceLanguage(name: $0, proficiency: .b2) },
        TextFieldCase(.platform) { _ = try SourceProfile(platform: $0, link: "x") },
        TextFieldCase(.link) { _ = try SourceProfile(platform: "x", link: $0) },
    ]

    @Test("each field of a skill, language or profile accepts 10,000 bytes and refuses one more", arguments: entryFields)
    func entryBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    // MARK: Education and certifications

    @Test("an education entry is built as written, with its description kept whole")
    func education() throws {
        let period = try TailoringPeriod(start: TailoringDate(year: 2010, month: 9), end: .date(TailoringDate(year: 2013, month: 6)))
        let education = try SourceEducation(degree: "BSc", school: "University", period: period, description: "- Thesis on graphs\n- Honours")
        #expect(education.degree == "BSc")
        #expect(education.school == "University")
        #expect(education.period == period)
        #expect(education.description == "- Thesis on graphs\n- Honours")
    }

    @Test("an education entry needs only a degree and a school")
    func educationMinimal() throws {
        let education = try SourceEducation(degree: "BSc", school: "University")
        #expect(education.period == nil)
        #expect(education.description.isEmpty)
    }

    @Test("a certification is built as written")
    func certification() throws {
        let issued = try TailoringDate(year: 2022, month: 3)
        let certification = try SourceCertification(name: "CKA", issuer: "CNCF", issued: issued, link: "https://example.com/cka", description: "Kubernetes")
        #expect(certification.name == "CKA")
        #expect(certification.issuer == "CNCF")
        #expect(certification.issued == issued)
        #expect(certification.link == "https://example.com/cka")
        #expect(certification.description == "Kubernetes")
    }

    @Test("a certification needs only a name and an issuer")
    func certificationMinimal() throws {
        let certification = try SourceCertification(name: "CKA", issuer: "CNCF")
        #expect(certification.issued == nil && certification.link == nil)
        #expect(certification.description.isEmpty)
    }

    static let educationFields: [TextFieldCase] = [
        TextFieldCase(.degree) { _ = try SourceEducation(degree: $0, school: "x") },
        TextFieldCase(.school) { _ = try SourceEducation(degree: "x", school: $0) },
        TextFieldCase(.description) { _ = try SourceEducation(degree: "x", school: "x", description: $0) },
        TextFieldCase(.certificationName) { _ = try SourceCertification(name: $0, issuer: "x") },
        TextFieldCase(.issuer) { _ = try SourceCertification(name: "x", issuer: $0) },
        TextFieldCase(.link) { _ = try SourceCertification(name: "x", issuer: "x", link: $0) },
        TextFieldCase(.description) { _ = try SourceCertification(name: "x", issuer: "x", description: $0) },
    ]

    @Test("each field of an education entry or a certification accepts 10,000 bytes and refuses one more", arguments: educationFields)
    func educationBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    @Test("a field's limit counts bytes, not characters")
    func bytesNotCharacters() throws {
        _ = try SourceSkill(name: twoByteCharacters(bytes: 10_000))
        #expect(throws: TailoringModelError.tooLarge(.skillName)) { try SourceSkill(name: twoByteCharacters(bytes: 10_002)) }
    }
}
