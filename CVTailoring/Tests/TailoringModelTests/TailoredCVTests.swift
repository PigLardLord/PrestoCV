import Testing
import TailoringModel

@Suite("ADR 0013 / R6, R8 · the tailored CV")
struct TailoredCVTests {
    private func tailored(_ source: SourceCV, experiences: [TailoredExperience] = []) throws -> TailoredCV {
        try TailoredCV(source: source, language: source.language, personal: source.personal, summary: "A sharper summary.", experiences: experiences)
    }

    @Test("a tailored CV holds the same sections as its source, and each experience names its source")
    func built() throws {
        let source = try Sample.source()
        let period = try TailoringPeriod(start: TailoringDate(year: 2019), end: .current)
        let lines = [try Sample.line("Built the API.", [source.statementRef(experience: 0, line: 0)]),
                     try Sample.line("Cut costs.", [source.statementRef(experience: 0, line: 1), source.statementRef(experience: 0, line: 2)])]
        let experience = try TailoredExperience(source: source.experienceRef(at: 0), role: "Engineer", company: "Acme", location: "Turin", period: period, lines: lines)
        let cv = try TailoredCV(source: source, language: .english, personal: Sample.personal(), summary: "A sharper summary.",
                                experiences: [experience], education: [Sample.education()], skills: [Sample.skill()],
                                languages: [Sample.language()], certifications: [Sample.certification()], profiles: [Sample.profile()],
                                interests: ["Chess"])
        #expect(cv.source == source)
        #expect(cv.language == .english)
        #expect(cv.personal.fullName == "Ada Lovelace")
        #expect(cv.summary == "A sharper summary.")
        #expect(cv.experiences == [experience])
        #expect(cv.experiences[0].source == (try source.experienceRef(at: 0)))
        #expect(cv.experiences[0].location == "Turin" && cv.experiences[0].period == period)
        #expect(cv.experiences[0].lines.map(\.statement.text) == ["Built the API.", "Cut costs."])
        #expect(cv.experiences[0].lines[1].sources == [try source.statementRef(experience: 0, line: 1), try source.statementRef(experience: 0, line: 2)])
        #expect(cv.education.count == 1 && cv.skills.count == 1 && cv.languages.count == 1)
        #expect(cv.certifications.count == 1 && cv.profiles.count == 1)
        #expect(cv.interests == ["Chess"])
    }

    @Test("a tailored CV needs only its source, a language and a person")
    func minimal() throws {
        let cv = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal())
        #expect(cv.summary.isEmpty && cv.experiences.isEmpty && cv.education.isEmpty && cv.skills.isEmpty)
        #expect(cv.languages.isEmpty && cv.certifications.isEmpty && cv.profiles.isEmpty && cv.interests.isEmpty)
    }

    // MARK: References

    @Test("references into the source are accepted wherever they point")
    func referencesInRange() throws {
        let source = try Sample.source()
        let first = try source.experienceRef(at: 0), second = try source.experienceRef(at: 1)
        let lines = [try Sample.line("One.", [source.statementRef(experience: 0, line: 2)]),
                     try Sample.line("Two.", [source.statementRef(experience: 1, line: 0)])]
        _ = try tailored(source, experiences: [Sample.tailoredExperience(source: first, lines: lines), Sample.tailoredExperience(source: second)])
    }

    @Test("an experience that names a source experience outside the snapshot is refused")
    func experienceFromBiggerSnapshot() throws {
        let source = try Sample.source(), bigger = try Sample.biggerSource()
        let foreign = try Sample.tailoredExperience(source: bigger.experienceRef(at: 5))
        #expect(throws: TailoringModelError.referenceOutOfRange) { try tailored(source, experiences: [foreign]) }
    }

    @Test("a line that names a statement outside its snapshot is refused, whether the experience or the line is out of range")
    func lineFromBiggerSnapshot() throws {
        let source = try Sample.source(), bigger = try Sample.biggerSource()
        let ownExperience = try source.experienceRef(at: 1)
        let farExperience = try bigger.statementRef(experience: 4, line: 0)   // the source has two experiences
        let farLine = try bigger.statementRef(experience: 1, line: 4)         // its second experience has one statement
        for foreign in [farExperience, farLine] {
            let experience = try Sample.tailoredExperience(source: ownExperience, lines: [Sample.line("Text.", [foreign])])
            #expect(throws: TailoringModelError.referenceOutOfRange) { try tailored(source, experiences: [experience]) }
        }
    }

    @Test("a foreign reference is refused in a later experience, and in a later line of the first one")
    func foreignReferenceLate() throws {
        let source = try Sample.source(), bigger = try Sample.biggerSource()
        let valid = try source.statementRef(experience: 0, line: 0)
        let farExperience = try bigger.statementRef(experience: 4, line: 0)
        let farLine = try bigger.statementRef(experience: 1, line: 4)
        let first = try Sample.tailoredExperience(source: source.experienceRef(at: 0), lines: [Sample.line("Fine.", [valid])])
        _ = try tailored(source, experiences: [first, first])

        let secondForeignSource = try Sample.tailoredExperience(source: bigger.experienceRef(at: 5))
        #expect(throws: TailoringModelError.referenceOutOfRange) { try tailored(source, experiences: [first, secondForeignSource]) }
        for foreign in [farExperience, farLine] {
            let secondForeignLine = try Sample.tailoredExperience(source: source.experienceRef(at: 1), lines: [Sample.line("Text.", [foreign])])
            #expect(throws: TailoringModelError.referenceOutOfRange) { try tailored(source, experiences: [first, secondForeignLine]) }
            let lateLine = try Sample.tailoredExperience(source: source.experienceRef(at: 0), lines: [Sample.line("Fine.", [valid]), Sample.line("Text.", [foreign])])
            #expect(throws: TailoringModelError.referenceOutOfRange) { try tailored(source, experiences: [lateLine]) }
        }
    }

    @Test("one foreign reference among valid ones is enough to refuse the tailored CV")
    func oneForeignReference() throws {
        let source = try Sample.source(), bigger = try Sample.biggerSource()
        let sources = [try source.statementRef(experience: 0, line: 0), try bigger.statementRef(experience: 3, line: 3)]
        let experience = try Sample.tailoredExperience(source: source.experienceRef(at: 0), lines: [Sample.line("Text.", sources)])
        #expect(throws: TailoringModelError.referenceOutOfRange) { try tailored(source, experiences: [experience]) }
    }

    @Test("every reference of a tailored CV resolves against its own source")
    func referencesResolveAgainstTheSource() throws {
        let source = try Sample.source()
        let refs = [try source.statementRef(experience: 0, line: 1), try source.statementRef(experience: 1, line: 0)]
        let experience = try Sample.tailoredExperience(source: source.experienceRef(at: 0), lines: [Sample.line("One.", [refs[0]]), Sample.line("Two.", [refs[1]])])
        let cv = try tailored(source, experiences: [experience])
        let resolved = try cv.experiences.flatMap(\.lines).flatMap(\.sources).map { try cv.source.statement($0).text }
        #expect(resolved == ["cut costs by 30%", "ran the on-call rota"])
    }

    @Test("a reference made by an equal snapshot is accepted")
    func referenceOfAnEqualSnapshot() throws {
        let source = try Sample.source(), same = try Sample.source()
        let experience = try Sample.tailoredExperience(source: same.experienceRef(at: 1), lines: [Sample.line("Text.", [same.statementRef(experience: 0, line: 2)])])
        _ = try tailored(source, experiences: [experience])
    }

    // MARK: Provenance failures are representable

    @Test("a line with no source, a source of another experience, an unrelated experience and a repeated one are all values")
    func provenanceFailuresAreRepresentable() throws {
        let source = try Sample.source()
        let otherExperience = try source.statementRef(experience: 1, line: 0)
        let lines = [try Sample.line("No source at all."), try Sample.line("From another experience.", [otherExperience]),
                     try Sample.line("A made-up 99% gain.", [source.statementRef(experience: 0, line: 0)])]
        let experience = try Sample.tailoredExperience(source: source.experienceRef(at: 0), lines: lines)
        let cv = try tailored(source, experiences: [experience, experience])
        #expect(cv.experiences.count == 2)
        #expect(cv.experiences[0].lines[0].sources.isEmpty)
    }

    // MARK: Bounds

    static let experienceFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.role) { _ = try TailoredExperience(source: Sample.source().experienceRef(at: 0), role: $0, company: "x", lines: []) })
        cases.append(TextFieldCase(.company) { _ = try TailoredExperience(source: Sample.source().experienceRef(at: 0), role: "x", company: $0, lines: []) })
        cases.append(TextFieldCase(.location) { _ = try TailoredExperience(source: Sample.source().experienceRef(at: 0), role: "x", company: "x", location: $0, lines: []) })
        cases.append(TextFieldCase(.statement) { _ = try TailoredLine(statement: Statement(text: $0), sources: []) })
        cases.append(TextFieldCase(.summary) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), summary: $0) })
        cases.append(TextFieldCase(.interest) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), interests: [$0]) })
        return cases
    }()

    @Test("each text of a tailored CV accepts 10,000 bytes and refuses one more", arguments: experienceFields)
    func textBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    @Test("a line made by the split is bounded when it joins a tailored experience")
    func lineFromTheSplit() throws {
        let oversized = Statement.split(ascii(10_001))
        #expect(oversized.count == 1)
        #expect(throws: TailoringModelError.tooLarge(.statement)) { try TailoredLine(statement: oversized[0], sources: []) }
        #expect(try TailoredLine(statement: Statement.split(ascii(10_000))[0], sources: []).statement.text.utf8.count == 10_000)
    }

    @Test("a line names at most 200 sources")
    func sourcesPerLine() throws {
        let source = try Sample.source()
        let ref = try source.statementRef(experience: 0, line: 0)
        #expect(TailoringLimits.maxSourcesPerLine == 200)
        _ = try TailoredLine(statement: Statement(text: "Text."), sources: Array(repeating: ref, count: 200))
        #expect(throws: TailoringModelError.tooMany(.sources)) { try TailoredLine(statement: Statement(text: "Text."), sources: Array(repeating: ref, count: 201)) }
    }

    @Test("an experience holds at most 200 lines")
    func linesPerExperience() throws {
        let source = try Sample.source()
        let line = try Sample.line("Text.", [source.statementRef(experience: 0, line: 0)])
        let experience = try source.experienceRef(at: 0)
        _ = try Sample.tailoredExperience(source: experience, lines: Array(repeating: line, count: 200))
        #expect(throws: TailoringModelError.tooMany(.lines)) { try Sample.tailoredExperience(source: experience, lines: Array(repeating: line, count: 201)) }
    }

    static let sections: [SectionCase] = {
        var cases: [SectionCase] = []
        cases.append(SectionCase(.experiences) {
            let source = try Sample.source()
            let experience = try Sample.tailoredExperience(source: source.experienceRef(at: 0))
            _ = try TailoredCV(source: source, language: .english, personal: Sample.personal(), experiences: Array(repeating: experience, count: $0))
        })
        cases.append(SectionCase(.education) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), education: Array(repeating: Sample.education(), count: $0)) })
        cases.append(SectionCase(.skills) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), skills: Array(repeating: Sample.skill(), count: $0)) })
        cases.append(SectionCase(.languages) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), languages: Array(repeating: Sample.language(), count: $0)) })
        cases.append(SectionCase(.certifications) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), certifications: Array(repeating: Sample.certification(), count: $0)) })
        cases.append(SectionCase(.profiles) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), profiles: Array(repeating: Sample.profile(), count: $0)) })
        cases.append(SectionCase(.interests) { _ = try TailoredCV(source: Sample.source(), language: .english, personal: Sample.personal(), interests: Array(repeating: "Chess", count: $0)) })
        return cases
    }()

    @Test("each section holds at most 200 entries", arguments: sections)
    func sectionBounds(section: SectionCase) throws {
        try section.build(200)
        #expect(throws: TailoringModelError.tooMany(section.collection)) { try section.build(201) }
    }
}
