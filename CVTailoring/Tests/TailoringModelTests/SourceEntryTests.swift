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

    static let blankNames: [String] = {
        var names: [String] = []
        names.append(contentsOf: blankStrings)
        return names
    }()

    @Test("a name that is empty after trimming is refused", arguments: blankNames)
    func personalDetailsNeedAName(name: String) {
        #expect(throws: TailoringModelError.emptyField(.fullName)) { try SourcePersonalDetails(fullName: name) }
    }

    @Test("a name made of a space with a combining mark is not empty: the mark shows")
    func markedSpaceName() throws {
        #expect(try SourcePersonalDetails(fullName: markedSpace).fullName == markedSpace)
    }

    @Test("the name keeps its spaces as written")
    func nameAsWritten() throws {
        #expect(try SourcePersonalDetails(fullName: "  Ada Lovelace ").fullName == "  Ada Lovelace ")
    }

    static let personalFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.fullName) { _ = try SourcePersonalDetails(fullName: $0) })
        cases.append(TextFieldCase(.professionalTitle) { _ = try SourcePersonalDetails(fullName: "A", professionalTitle: $0) })
        cases.append(TextFieldCase(.email) { _ = try SourcePersonalDetails(fullName: "A", email: $0) })
        cases.append(TextFieldCase(.phone) { _ = try SourcePersonalDetails(fullName: "A", phone: $0) })
        cases.append(TextFieldCase(.location) { _ = try SourcePersonalDetails(fullName: "A", location: $0) })
        cases.append(TextFieldCase(.website) { _ = try SourcePersonalDetails(fullName: "A", website: $0) })
        return cases
    }()

    @Test("each personal field accepts 10,000 bytes and refuses one more", arguments: personalFields)
    func personalBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    // MARK: Skills, languages, profiles

    static let skillLevels: [Int?] = {
        var levels: [Int?] = []
        levels.append(nil)
        levels.append(contentsOf: [1, 2, 3, 4, 5])
        return levels
    }()

    @Test("a skill has a name and an optional level from 1 to 5", arguments: skillLevels)
    func skill(level: Int?) throws {
        let skill = try SourceSkill(name: "Swift", level: level)
        #expect(skill.name == "Swift")
        #expect(skill.level == level)
    }

    static let invalidSkillLevels: [Int] = {
        var levels: [Int] = []
        levels.append(contentsOf: [Int.min, -1, 0, 6, 10, Int.max])
        return levels
    }()

    @Test("a skill level outside 1 to 5 is refused", arguments: invalidSkillLevels)
    func skillLevelOutOfRange(level: Int) {
        #expect(throws: TailoringModelError.invalidSkillLevel) { try SourceSkill(name: "Swift", level: level) }
    }

    @Test("a skill has no level unless one is given")
    func skillWithoutLevel() throws {
        #expect(try SourceSkill(name: "Swift").level == nil)
    }

    static let proficiencies: [LanguageLevel] = {
        var levels: [LanguageLevel] = []
        levels.append(contentsOf: [LanguageLevel.a1, LanguageLevel.a2, LanguageLevel.b1, LanguageLevel.b2])
        levels.append(contentsOf: [LanguageLevel.c1, LanguageLevel.c2, LanguageLevel.native])
        return levels
    }()

    @Test("a language has a name and a level, CEFR or native", arguments: proficiencies)
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

    static let entryFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.skillName) { _ = try SourceSkill(name: $0) })
        cases.append(TextFieldCase(.languageName) { _ = try SourceLanguage(name: $0, proficiency: .b2) })
        cases.append(TextFieldCase(.platform) { _ = try SourceProfile(platform: $0, link: "x") })
        cases.append(TextFieldCase(.link) { _ = try SourceProfile(platform: "x", link: $0) })
        return cases
    }()

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

    static let educationFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.degree) { _ = try SourceEducation(degree: $0, school: "x") })
        cases.append(TextFieldCase(.school) { _ = try SourceEducation(degree: "x", school: $0) })
        cases.append(TextFieldCase(.description) { _ = try SourceEducation(degree: "x", school: "x", description: $0) })
        cases.append(TextFieldCase(.certificationName) { _ = try SourceCertification(name: $0, issuer: "x") })
        cases.append(TextFieldCase(.issuer) { _ = try SourceCertification(name: "x", issuer: $0) })
        cases.append(TextFieldCase(.link) { _ = try SourceCertification(name: "x", issuer: "x", link: $0) })
        cases.append(TextFieldCase(.description) { _ = try SourceCertification(name: "x", issuer: "x", description: $0) })
        return cases
    }()

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
