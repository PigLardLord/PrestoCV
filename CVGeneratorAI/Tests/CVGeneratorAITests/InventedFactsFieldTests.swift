import Testing
import Foundation
import CVGeneratorAI

// A phrase of the description is not proof that it belongs in the field that holds it: a language listed as a skill, the
// sentence of a school as a degree, a first-person clause as an interest are all phrases of the description, in the wrong
// field. Where the counter cannot tell, it sends the value to review; it keeps as a quote only a value that the field's
// kind allows. In prose, a capital letter at the start of a sentence says nothing about a proper name.

@Suite("Invented facts: a value in the wrong field is a doubt, not a quote")
struct InventedFactsFieldTests {
    // MARK: - Skills, languages, interests

    @Test("A skill, a language or an interest is a quote, a doubt in the wrong field or invented, by what the description makes it",
          arguments: FieldCase.all)
    func field(_ example: FieldCase) throws {
        let input = try InventedFactsTests.input(example.input)
        var draft = Draft(faithfulTo: input)
        let path = example.place(in: &draft)

        let report = InventedFacts.count(draft.cv, for: input)

        let finding = report.finding(at: path)
        #expect(finding?.kind == example.kind, "\(example): \(String(describing: finding))")
        #expect(report.invented.map(\.path) == (example.kind == .invented ? [path] : []), "\(example): \(report.invented)")
    }

    @Test("The languages written as skills, with no language left, are doubts and the languages are lost")
    func languagesAsSkills() throws {
        let input = try InventedFactsTests.input("en-traps")
        var draft = Draft(faithfulTo: input)
        draft.skills = draft.languages.map { Skill(name: $0.name) }
        draft.languages = []

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.finding(at: "skills[0].name")?.kind == .review, "\(report.findings)")
        #expect(report.finding(at: "skills[1].name")?.kind == .review, "\(report.findings)")
        #expect(report.lost.filter { $0.kind == .language }.count == 2, "\(report.lost)")
    }

    // MARK: - Degrees

    @Test("A degree is never a quote: the sentence of the school cannot tell it from another phrase", arguments: [
        ("es-plain", "terminé"), ("en-traps", "nurse"), ("en-plain", "logistics"), ("en-plain", "Leeds City College"),
    ])
    func degreeIsReviewed(_ id: String, _ degree: String) throws {
        let input = try InventedFactsTests.input(id)
        var draft = Draft(faithfulTo: input)
        draft.education[0] = Education(degree: degree, institution: draft.education[0].institution)

        let finding = InventedFacts.count(draft.cv, for: input).finding(at: "education[0].degree")

        #expect(finding?.kind == .review, "\(id): \(String(describing: finding))")
        #expect(finding?.context == draft.education[0].institution, "\(id): \(String(describing: finding))")
    }

    // MARK: - Prose

    @Test("A capitalised word at the start of a sentence is no proper name: it goes to review, not to the count",
          arguments: [
              ("en-plain", "Supervised carefully."),
              ("it-plain", "Coordinavo con cura."),
              ("de-plain", "Koordinierte sorgfältig."),
              ("es-plain", "Coordinaba con cuidado."),
              ("fr-plain", "Coordonnais avec soin."),
              ("pt-plain", "Coordenava com cuidado."),
          ])
    func sentenceStart(_ id: String, _ sentence: String) throws {
        let input = try InventedFactsTests.input(id)
        var draft = Draft(faithfulTo: input)
        draft.summary = sentence

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        let finding = try #require(report.finding(at: "summary"))
        #expect(finding.kind == .review, "\(finding)")
        #expect(finding.reason.contains(try #require(sentence.split(separator: " ").first)), "\(finding)")
    }

    @Test("Every sentence of the prose starts again, after a full stop and after a new line; a capital inside one is still invented",
          arguments: [("I plan the night shifts. Supervised carefully.", false), ("I plan the night shifts\nSupervised carefully", false),
                      ("I plan the night shifts! Then Halvorsen came.", true), ("I plan the night shifts, Supervised carefully", true)])
    func everySentenceStartsAgain(_ summary: String, _ invented: Bool) throws {
        let input = try InventedFactsTests.input("en-plain")
        var draft = Draft(faithfulTo: input)
        draft.summary = summary

        let finding = try #require(InventedFacts.count(draft.cv, for: input).finding(at: "summary"))

        #expect((finding.kind == .invented) == invented, "\(finding)")
        #expect(invented == false || finding.reason.contains("Supervised") || finding.reason.contains("Halvorsen"), "\(finding)")
        #expect(!finding.reason.contains("Then"), "\(finding)")
    }

    @Test("A number the description lacks is invented at the start of a sentence too")
    func numberAtTheStart() throws {
        let input = try InventedFactsTests.input("en-plain")
        var draft = Draft(faithfulTo: input)
        draft.summary = "5 years of experience."

        let finding = try #require(InventedFacts.count(draft.cv, for: input).finding(at: "summary"))

        #expect(finding.kind == .invented, "\(finding)")
        #expect(finding.reason.contains("5"), "\(finding)")
    }

    @Test("A review of prose names the job or the school it was written for")
    func proseKeepsItsEntry() throws {
        let input = try InventedFactsTests.input("en-plain")
        var draft = Draft(faithfulTo: input)
        let company = draft.experience[0].company
        let school = try #require(draft.education[0].institution)
        draft.summary = "where I plan the night shifts"
        draft.experience[0] = Experience(title: "Supervisor", company: company, description: "where I plan the night shifts")
        draft.experience[1] = Experience(company: draft.experience[1].company, achievements: ["a forklift driver"])
        draft.education[0] = Education(degree: "logistics", institution: school, description: "I studied logistics")

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.isEmpty, "\(report.invented)")
        #expect(report.finding(at: "summary")?.context == nil)
        #expect(report.finding(at: "experience[0].description")?.context == "Supervisor at \(company)")
        #expect(report.finding(at: "experience[1].achievements[0]")?.context == draft.experience[1].company)
        #expect(report.finding(at: "education[0].description")?.context == "logistics at \(school)")
    }
}

/// A skill, a language, an interest or a degree put in a draft, and the class the counter must give it.
struct FieldCase: Sendable, CustomTestStringConvertible {
    enum Field: Sendable { case skill, language, interest }

    let input: String
    let field: Field
    let value: String
    let kind: InventedFacts.Class

    var testDescription: String { "\(input) \(field) \(value) is \(kind)" }

    /// Puts the value in the draft and returns the path of the field that holds it.
    func place(in draft: inout Draft) -> String {
        switch field {
        case .skill:
            draft.skills.append(Skill(name: value))
            return "skills[\(draft.skills.count - 1)].name"
        case .language:
            draft.languages.append(Language(name: value))
            return "languages[\(draft.languages.count - 1)].name"
        case .interest:
            draft.interests.append(value)
            return "interests[\(draft.interests.count - 1)]"
        }
    }

    static let all: [FieldCase] = [
        // A skill the description says, and nothing else it could be.
        FieldCase(input: "en-plain", field: .skill, value: "Excel", kind: .quote),
        FieldCase(input: "it-plain", field: .skill, value: "HACCP", kind: .quote),
        // A language, an employer, a school, the person, or a piece of one of them, listed as a skill.
        FieldCase(input: "en-plain", field: .skill, value: "English", kind: .review),
        FieldCase(input: "en-plain", field: .skill, value: "Polish", kind: .review),
        FieldCase(input: "it-plain", field: .skill, value: "italiano", kind: .review),
        FieldCase(input: "en-plain", field: .skill, value: "Leeds City College", kind: .review),
        FieldCase(input: "en-plain", field: .skill, value: "Northfield Logistics", kind: .review),
        FieldCase(input: "en-plain", field: .skill, value: "Daniel Hart", kind: .review),
        FieldCase(input: "en-plain", field: .skill, value: "Daniel", kind: .review),
        FieldCase(input: "en-traps", field: .skill, value: "English", kind: .review),
        FieldCase(input: "en-traps", field: .skill, value: "Hindi", kind: .review),
        // A skill listed as a language.
        FieldCase(input: "en-plain", field: .language, value: "Polish", kind: .quote),
        FieldCase(input: "en-plain", field: .language, value: "SAP", kind: .review),
        FieldCase(input: "en-plain", field: .language, value: "Excel", kind: .review),
        FieldCase(input: "de-plain", field: .language, value: "KNX", kind: .review),
        FieldCase(input: "en-plain", field: .language, value: "Klingon", kind: .invented),
        // A hobby is one word of the description; a clause with a verb in it is a doubt.
        FieldCase(input: "it-plain", field: .interest, value: "bicicletta", kind: .quote),
        FieldCase(input: "it-plain", field: .interest, value: "chitarra", kind: .quote),
        FieldCase(input: "en-plain", field: .interest, value: "football", kind: .quote),
        FieldCase(input: "it-plain", field: .interest, value: "vado in bicicletta", kind: .review),
        FieldCase(input: "it-plain", field: .interest, value: "suono la chitarra", kind: .review),
        FieldCase(input: "en-plain", field: .interest, value: "play football", kind: .review),
        FieldCase(input: "en-plain", field: .interest, value: "Excel", kind: .review),
        FieldCase(input: "en-plain", field: .interest, value: "English", kind: .review),
        FieldCase(input: "en-plain", field: .interest, value: "Origami", kind: .invented),
    ]
}
