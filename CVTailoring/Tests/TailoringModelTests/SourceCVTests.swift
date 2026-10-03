import Testing
import TailoringModel

/// A section of a source CV, filled with `count` copies of one valid entry.
struct SectionCase: Sendable, CustomTestStringConvertible {
    let collection: TailoringModelError.Collection
    let build: @Sendable (Int) throws -> Void
    init(_ collection: TailoringModelError.Collection, _ build: @escaping @Sendable (Int) throws -> Void) {
        self.collection = collection
        self.build = build
    }
    var testDescription: String { "\(collection)" }
}

@Suite("ADR 0013 / R6, R8 · the source CV")
struct SourceCVTests {
    @Test("a source CV holds every section as given")
    func built() throws {
        let experience = try Sample.experience(description: "- Built the API")
        let cv = try SourceCV(language: .italian, personal: Sample.personal(), summary: "An analyst.", experiences: [experience],
                              education: [Sample.education()], skills: [Sample.skill()], languages: [Sample.language()],
                              certifications: [Sample.certification()], profiles: [Sample.profile()], interests: ["Chess", "Rowing"])
        #expect(cv.language == .italian)
        #expect(cv.personal.fullName == "Ada Lovelace")
        #expect(cv.summary == "An analyst.")
        #expect(cv.experiences == [experience])
        #expect(cv.education.count == 1 && cv.skills.count == 1 && cv.languages.count == 1)
        #expect(cv.certifications.count == 1 && cv.profiles.count == 1)
        #expect(cv.interests == ["Chess", "Rowing"])
    }

    @Test("a source CV needs only a language and a person")
    func minimal() throws {
        let cv = try SourceCV(language: .english, personal: Sample.personal())
        #expect(cv.summary.isEmpty)
        #expect(cv.experiences.isEmpty && cv.education.isEmpty && cv.skills.isEmpty && cv.languages.isEmpty)
        #expect(cv.certifications.isEmpty && cv.profiles.isEmpty && cv.interests.isEmpty)
    }

    @Test("two snapshots of the same CV are equal")
    func equality() throws {
        let first = try SourceCV(language: .german, personal: Sample.personal(), experiences: [Sample.experience()])
        let second = try SourceCV(language: .german, personal: Sample.personal(), experiences: [Sample.experience()])
        #expect(first == second)
        #expect(first != (try SourceCV(language: .german, personal: Sample.personal(), experiences: [Sample.experience("Other")])))
    }

    static let textFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.summary) { _ = try SourceCV(language: .english, personal: Sample.personal(), summary: $0) })
        cases.append(TextFieldCase(.interest) { _ = try SourceCV(language: .english, personal: Sample.personal(), interests: ["ok", $0]) })
        return cases
    }()

    @Test("the summary and each interest accept 10,000 bytes and refuse one more", arguments: textFields)
    func textBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    static let sections: [SectionCase] = {
        var cases: [SectionCase] = []
        cases.append(SectionCase(.experiences) { _ = try SourceCV(language: .english, personal: Sample.personal(), experiences: Array(repeating: Sample.experience(), count: $0)) })
        cases.append(SectionCase(.education) { _ = try SourceCV(language: .english, personal: Sample.personal(), education: Array(repeating: Sample.education(), count: $0)) })
        cases.append(SectionCase(.skills) { _ = try SourceCV(language: .english, personal: Sample.personal(), skills: Array(repeating: Sample.skill(), count: $0)) })
        cases.append(SectionCase(.languages) { _ = try SourceCV(language: .english, personal: Sample.personal(), languages: Array(repeating: Sample.language(), count: $0)) })
        cases.append(SectionCase(.certifications) { _ = try SourceCV(language: .english, personal: Sample.personal(), certifications: Array(repeating: Sample.certification(), count: $0)) })
        cases.append(SectionCase(.profiles) { _ = try SourceCV(language: .english, personal: Sample.personal(), profiles: Array(repeating: Sample.profile(), count: $0)) })
        cases.append(SectionCase(.interests) { _ = try SourceCV(language: .english, personal: Sample.personal(), interests: Array(repeating: "Chess", count: $0)) })
        return cases
    }()

    @Test("each section holds at most 200 entries", arguments: sections)
    func sectionBounds(section: SectionCase) throws {
        #expect(TailoringLimits.maxEntriesPerSection == 200)
        try section.build(200)
        #expect(throws: TailoringModelError.tooMany(section.collection)) { try section.build(201) }
    }
}
