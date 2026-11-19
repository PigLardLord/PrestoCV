import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence

private let fallback = Date(timeIntervalSince1970: 1_700_000_000)
private func period(start: (year: Int, month: Int?)?, end: (year: Int, month: Int?)?, current: Bool) -> Period? { try? Period.make(start: start, end: end, current: current) }

private func mapped(_ json: String, name: String? = nil) -> LegacyCV? {
    let id = LegacyFixtures.idA
    guard case .cv(let legacy) = LegacyCVFile.read(Data(json.utf8), fileName: name ?? LegacyFixtures.fileName(id), fallback: fallback) else { return nil }
    return legacy
}

private func invalidReason(_ json: String, name: String = LegacyFixtures.fileName(LegacyFixtures.idA)) -> LegacyInvalid? {
    guard case .invalid(let reason) = LegacyCVFile.read(Data(json.utf8), fileName: name, fallback: fallback) else { return nil }
    return reason
}

@Suite("Reading a legacy CV file")
struct LegacyCVFileTests {
    @Test("a file of version 1.0 maps every field to the domain")
    func version10() throws {
        let legacy = try #require(mapped(LegacyFixtures.v10()))
        let expected = CV(
            id: CVID(UUID(uuidString: LegacyFixtures.idA)!), revision: 0,
            createdAt: ISO8601DateFormatter().date(from: "2026-09-01T08:00:00Z"), updatedAt: ISO8601DateFormatter().date(from: "2026-09-20T10:00:00Z"),
            title: "Lab roles",
            personal: PersonalDetails(fullName: "Ada Example", professionalTitle: "Lab technician", email: EmailAddress("ada@example.org"),
                                      phone: PhoneNumber("+39 011 555 0100"), location: "Turin", website: WebLink("https://example.org/ada"),
                                      summary: "Careful and curious."),
            sections: CVSections(
                experiences: [Experience(role: "Technician", company: "Example Labs", location: "Turin",
                                         period: period(start: (2018, 3), end: nil, current: true), description: "Ran assays.")],
                education: [Education(degree: "BSc Biology", school: "Example University",
                                      period: period(start: (2012, nil), end: (2015, nil), current: false), description: "")],
                skills: [Skill(name: "Pipetting", level: SkillLevel(4)), Skill(name: "Cooking")],
                languages: [LanguageSkill(language: "English", proficiency: .b2), LanguageSkill(language: "Italian", proficiency: .native)],
                certifications: [Certification(name: "First Aid", issuer: "Example Institute", issued: PartialDate(year: 2019),
                                               link: WebLink("https://example.org/aid"), description: "Basic course")],
                profiles: [ProfileLink(platform: "GitHub", link: WebLink("https://example.org/ada-code")!)],
                interests: ["Chess", "Hiking"]),
            design: nil, language: nil)
        #expect(legacy.cv == expected)
        #expect(legacy.drops.isEmpty)
    }

    @Test("a file of version 1.0.1 carries its look and its document language")
    func version101() throws {
        let cv = try #require(mapped(LegacyFixtures.v101(), name: LegacyFixtures.fileName(LegacyFixtures.idB))).cv
        #expect(cv.design == DesignChoice(design: "modern", palette: "ocean", fonts: "classic"))
        #expect(cv.language?.tag == "it")
    }

    @Test("a look without a palette or fonts keeps only its design")
    func partialLook() throws {
        let cv = try #require(mapped(LegacyFixtures.minimal(#""look":{"design":"modern"}"#))).cv
        #expect(cv.design == DesignChoice(design: "modern"))
    }

    @Test("a look without a valid design is dropped, and says so", arguments: [#"{"palette":"ocean"}"#, #"{"design":"modern!"}"#,
        #"{"design":"Modern","palette":"ocean"}"#])
    func droppedLook(look: String) throws {
        let legacy = try #require(mapped(LegacyFixtures.minimal(#""look":\#(look)"#)))
        #expect(legacy.cv.design == nil)
        #expect(legacy.drops == [.look])
    }

    @Test("a palette the domain refuses is dropped alone: the design and the fonts stay, and the look is noted")
    func badPaletteAlone() throws {
        let legacy = try #require(mapped(LegacyFixtures.minimal(#""look":{"design":"modern","palette":"has space","fonts":"classic"}"#)))
        #expect(legacy.cv.design == DesignChoice(design: "modern", fonts: "classic"))
        #expect(legacy.drops == [.look])
    }

    @Test("fonts the domain refuses are dropped alone: the design and the palette stay, and the look is noted")
    func badFontsAlone() throws {
        let fonts = String(repeating: "a", count: 65)
        let legacy = try #require(mapped(LegacyFixtures.minimal(#""look":{"design":"modern","palette":"ocean","fonts":"\#(fonts)"}"#)))
        #expect(legacy.cv.design == DesignChoice(design: "modern", palette: "ocean"))
        #expect(legacy.drops == [.look])
    }

    @Test("a look of the wrong shape is no look, as the legacy app reads it", arguments: [#""modern""#, "7", "[1]", #"{"design":7}"#, "null"])
    func wrongShapeLook(look: String) throws {
        let legacy = try #require(mapped(LegacyFixtures.minimal(#""look":\#(look)"#)))
        #expect(legacy.cv.design == nil && legacy.drops.isEmpty)
    }

    @Test("values the domain refuses are dropped one by one and reported")
    func refusedValues() throws {
        let fields = #""personalInfo":{"name":"A","email":"not an email","phone":"call me","portfolio":"javascript:alert(1)"},"#
            + #""skills":[{"name":"X","level":9}],"certifications":[{"name":"C","year":1200,"url":"ftp://x"}],"#
            + #""social":[{"platform":"P","url":"nope"}],"documentLanguage":"not a tag""#
        let legacy = try #require(mapped(LegacyFixtures.minimal(fields)))
        let cv = legacy.cv
        #expect(cv.personal.fullName == "A" && cv.personal.email == nil && cv.personal.phone == nil && cv.personal.website == nil)
        #expect(cv.sections.skills == [Skill(name: "X", level: nil)])
        #expect(cv.sections.certifications == [Certification(name: "C", issuer: "")])
        #expect(cv.sections.profiles.isEmpty && cv.language == nil)
        #expect(Set(legacy.drops) == [.email, .phone, .website, .skillLevel, .certificationYear, .certificationLink, .profile, .documentLanguage])
    }

    @Test("a period that is not an unambiguous range is kept as written in the description, and reported to check, not as a drop", arguments: ["2020", "since forever", "2023 – 2020", "13/2020 – 2021", "1500 – 1600"])
    func uncertainPeriod(text: String) throws {
        let fields = #""relevant_experience":[{"title":"T","company":"C","period":"\#(text)"}]"#
        let legacy = try #require(mapped(LegacyFixtures.minimal(fields)))
        let job = try #require(legacy.cv.sections.experiences.first)
        #expect(job.period == nil && job.description == text)
        #expect(legacy.drops.isEmpty && legacy.checks == [.period])
    }

    @Test("an uncertain period is the first line above the description an entry had, for a job and a study alike")
    func uncertainPeriodAboveDescription() throws {
        let fields = #""relevant_experience":[{"title":"T","company":"C","period":"  since forever ","description":"Did X"}],"#
            + #""education":[{"degree":"D","school":"S","period":"2020","description":"Thesis on Y"}]"#
        let legacy = try #require(mapped(LegacyFixtures.minimal(fields)))
        let job = try #require(legacy.cv.sections.experiences.first), study = try #require(legacy.cv.sections.education.first)
        #expect(job.period == nil && job.description == "since forever\nDid X")
        #expect(study.period == nil && study.description == "2020\nThesis on Y")
        #expect(legacy.drops.isEmpty && legacy.checks == [.period])
    }

    @Test("an empty period is no period, no drop and nothing to check")
    func emptyPeriod() throws {
        let legacy = try #require(mapped(LegacyFixtures.minimal(#""education":[{"degree":"D","school":"S","period":"  "}]"#)))
        #expect(legacy.cv.sections.education.count == 1 && legacy.cv.sections.education.first?.description == "")
        #expect(legacy.drops.isEmpty && legacy.checks.isEmpty)
    }

    @Test("a file without times takes the fallback; one with a time but not the other keeps it")
    func missingTimes() throws {
        let bare = try #require(mapped(#"{"id":"\#(LegacyFixtures.idA)"}"#)).cv
        #expect(bare.createdAt == fallback && bare.updatedAt == fallback)
        let half = try #require(mapped(#"{"id":"\#(LegacyFixtures.idA)","updatedAt":"2026-10-02T00:00:00Z"}"#)).cv
        #expect(half.createdAt == half.updatedAt && half.updatedAt != fallback)
    }

    @Test("an update dated before its creation is not dated before it")
    func backwardsTimes() throws {
        let json = #"{"id":"\#(LegacyFixtures.idA)","createdAt":"2026-10-02T00:00:00Z","updatedAt":"2026-10-01T00:00:00Z"}"#
        let cv = try #require(mapped(json)).cv
        #expect(cv.updatedAt == cv.createdAt)
    }

    @Test("a file without an id, with an id that is not a UUID, or named after another id, is not a legacy CV")
    func idsOutsideThePattern() {
        #expect(invalidReason(#"{"name":"x"}"#) == .id)
        #expect(invalidReason(#"{"id":"not-a-uuid"}"#) == .id)
        #expect(invalidReason(#"{"id":"\#(LegacyFixtures.idB)"}"#) == .name)
        #expect(invalidReason(#"{"id":"\#(LegacyFixtures.idA.lowercased())"}"#, name: "cv_\(LegacyFixtures.idA.lowercased()).json") == .name)
        #expect(invalidReason(#"{"id":"\#(LegacyFixtures.idA)"}"#, name: "cv_x.json") == .name)
    }

    @Test("content that is not a JSON object is invalid, and a number of the wrong type does not crash")
    func notJSON() {
        #expect(invalidReason("[]") == .json)
        #expect(invalidReason("not json") == .json)
        #expect(invalidReason(#"{"id":"\#(LegacyFixtures.idA)","skills":"x"}"#) == .json)
    }

    @Test("a schemaVersion key in a legacy file is ignored: the file is still a legacy file")
    func schemaVersionIgnored() throws {
        let legacy = try #require(mapped(LegacyFixtures.minimal(#""schemaVersion":1,"revision":5"#)))
        #expect(legacy.cv.revision == 0)
    }

    @Test("a language level is read as the legacy app reads it, with B1 for what it does not know")
    func languageLevels() throws {
        let fields = #""languages":[{"name":"A","level":"c1"},{"name":"B","level":"mother tongue"},{"name":"C","level":"???"}]"#
        let cv = try #require(mapped(LegacyFixtures.minimal(fields))).cv
        #expect(cv.sections.languages.map(\.proficiency) == [.c1, .native, .b1])
    }

    @Test("a level is read in the order of the 1.0 app", arguments: [
        ("Native", LanguageProficiency.native), ("mother tongue", .native), ("Beginner", .a1), ("a1", .a1), ("Elementary", .a2),
        ("intermediate", .b1), ("Intermediate (B2)", .b1), ("Upper Intermediate", .b2), ("upper", .b2), ("B2 level", .b2),
        ("Advanced", .c1), ("C1", .c1), ("Proficient", .c2), ("c2 certificate", .c2), ("???", .b1), ("", .b1),
    ])
    func levelOrder(text: String, expected: LanguageProficiency) {
        #expect(LegacyMapper.proficiency(text) == expected)
    }
}

@Suite("Reading the period the legacy app kept as text")
struct LegacyPeriodTests {
    @Test("ranges in the forms people wrote them", arguments: [
        ("2015 – 2018", (2015, nil as Int?), (2018, nil as Int?), false),
        ("2015 - 2018", (2015, nil), (2018, nil), false),
        ("2015—2018", (2015, nil), (2018, nil), false),
        ("2015 to 2018", (2015, nil), (2018, nil), false),
        ("Sep 2020 – Feb 2022", (2020, 9), (2022, 2), false),
        ("Marzo 2019 – oggi", (2019, 3), (0, nil), true),
        ("09/2018 - 11/2020", (2018, 9), (2020, 11), false),
        ("2020-Present", (2020, nil), (0, nil), true),
        ("Januar 2017 bis heute", (2017, 1), (0, nil), true),
        ("mai 2016 – juin 2017", (2016, 5), (2017, 6), false),
        ("2014 – actual", (2014, nil), (0, nil), true),
    ])
    func ranges(text: String, start: (Int, Int?), end: (Int, Int?), current: Bool) {
        let expected = try? Period.make(start: start, end: current ? nil : end, current: current)
        #expect(LegacyPeriod.read(text) == .period(expected!))
    }

    @Test("October and March in the six languages, short and full", arguments: [
        ("Oct", "Mar"), ("October", "March"), ("Ott", "Mar"), ("Ottobre", "Marzo"), ("Okt", "Mär"), ("Oktober", "März"),
        ("Oct", "Mar"), ("Octubre", "Marzo"), ("Oct", "Mars"), ("Octobre", "Mars"), ("Out", "Mar"), ("Outubro", "Março"),
    ])
    func octoberAndMarch(october: String, march: String) throws {
        let expected = try #require(try? Period.make(start: (2019, 10), end: (2021, 3), current: false))
        #expect(LegacyPeriod.read("\(october) 2019 – \(march) 2021") == .period(expected))
    }

    @Test("the separator word is read in any case", arguments: ["2015 TO 2018", "2015 To 2018", "2015 Bis 2018", "2015 BIS 2018"])
    func separatorCase(text: String) throws {
        let expected = try #require(try? Period.make(start: (2015, nil), end: (2018, nil), current: false))
        #expect(LegacyPeriod.read(text) == .period(expected))
    }

    @Test("empty is none; anything else that is not a range is unreadable", arguments: ["", "   ", "2020", "Present", "2020 – 2021 – 2022", "March – June", "2020 – ???"])
    func notARange(text: String) {
        let reading = LegacyPeriod.read(text)
        #expect(reading == (text.trimmingCharacters(in: .whitespaces).isEmpty ? .none : .unreadable))
    }
}
