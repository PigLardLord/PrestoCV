import Testing
import Foundation
import CVGeneratorAI

// A trap is a temptation the description sets for the model: a colleague's employer, a wished title, a denied skill, another
// person's email. A draft that holds a trap, or only a part of one that the description gives nowhere else (the first
// word of the colleague's employer, a first name read from an email address), states a fact the person did not.

@Suite("Invented facts: a trap, or a part of it, is invented in any field")
struct InventedFactsTrapTests {
    @Test("A part of a trap that the description gives nowhere else is invented, in the field where a model puts it",
          arguments: TrapPart.all)
    func partOfATrap(_ part: TrapPart) throws {
        let input = try InventedFactsTests.input(part.input)
        var draft = Draft(faithfulTo: input)
        let path = part.place(in: &draft)

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path) == [path], "\(part): \(report.findings)")
        #expect(report.finding(at: path)?.reason.contains("part of a trap") == true, "\(part): \(report.invented)")
    }

    @Test("A value that holds a whole trap is invented, whatever else it holds", arguments: [
        ("en-traps", "Tom's clinic", TrapPart.Field.company),
        ("en-traps", "Epic Systems", .skill),
        ("fr-traps", "Antoine Roux", .company),
        ("es-traps", "Seguros Pilar S.L.", .company),
        ("pt-traps", "Kotlin avançado", .skill),
    ])
    func valueHoldingATrap(_ id: String, _ value: String, _ field: TrapPart.Field) throws {
        let input = try InventedFactsTests.input(id)
        var draft = Draft(faithfulTo: input)
        let path = TrapPart(input: id, value: value, field: field).place(in: &draft)

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(report.invented.map(\.path) == [path], "\(report.findings)")
        #expect(report.finding(at: path)?.reason.hasPrefix("trap:") == true, "\(report.invented)")
    }

    @Test("The figures of the team, in a date, are invented as traps", arguments: DraftingInputs.written.filter { $0.kind == .traps })
    func figureInADate(_ input: DraftingInput) throws {
        let figures = Array(input.traps.suffix(2))
        var draft = Draft(faithfulTo: input)
        draft.experience[0] = Experience(company: draft.experience[0].company, startDate: figures[0], endDate: figures[1])

        let report = InventedFacts.count(draft.cv, for: input)

        #expect(
            report.invented.map(\.path) == ["experience[0].startDate", "experience[0].endDate"],
            "\(input.id): \(report.findings)"
        )
        #expect(report.invented.allSatisfy { $0.reason.hasPrefix("trap:") }, "\(report.invented)")
    }

    @Test("A word that the description also says outside the trap is not a part of a trap")
    func partSaidElsewhere() throws {
        // A skill that is a piece of the employer or of the title is a doubt for that reason, never a trap.
        let praxis = try InventedFactsTests.input("de-traps")
        var draft = Draft(faithfulTo: praxis)
        draft.skills.append(Skill(name: "Praxis"))
        let skill = InventedFacts.count(draft.cv, for: praxis).finding(at: "skills[\(draft.skills.count - 1)].name")
        #expect(skill?.kind == .review, "\(String(describing: skill))")
        #expect(skill?.reason.contains("trap") == false, "\(String(describing: skill))")

        let nurse = try InventedFactsTests.input("en-traps")
        var other = Draft(faithfulTo: nurse)
        other.skills.append(Skill(name: "nurse"))
        let word = InventedFacts.count(other.cv, for: nurse).finding(at: "skills[\(other.skills.count - 1)].name")
        #expect(word?.kind == .review, "\(String(describing: word))")
        #expect(word?.reason.contains("trap") == false, "\(String(describing: word))")

        // A word that is nothing else is a quote.
        var ward = Draft(faithfulTo: nurse)
        ward.skills.append(Skill(name: "ward"))
        let plain = InventedFacts.count(ward.cv, for: nurse).finding(at: "skills[\(ward.skills.count - 1)].name")
        #expect(plain?.kind == .quote, "\(String(describing: plain))")
    }

    @Test("A faithful draft of a description with traps holds none of them", arguments: DraftingInputs.written.filter { $0.kind == .traps })
    func faithfulDraftHoldsNoTrap(_ input: DraftingInput) {
        let report = InventedFacts.count(Draft(faithfulTo: input).cv, for: input)

        #expect(report.invented.isEmpty, "\(input.id): \(report.invented)")
    }
}

/// A word or a phrase that is a part of a trap, put in the field where a model would put it.
struct TrapPart: Sendable, CustomTestStringConvertible {
    enum Field: Sendable { case company, skill, headline, achievement }

    let input: String
    let value: String
    let field: Field

    var testDescription: String { "\(input): \(value)" }

    /// Puts the value in the draft and returns the path of the field that holds it.
    func place(in draft: inout Draft) -> String {
        switch field {
        case .company:
            draft.experience.append(Experience(company: value))
            return "experience[\(draft.experience.count - 1)].company"
        case .skill:
            draft.skills.append(Skill(name: value))
            return "skills[\(draft.skills.count - 1)].name"
        case .headline:
            draft.title = value
            return "personalInfo.title"
        case .achievement:
            draft.experience[0] = Experience(company: draft.experience[0].company, achievements: [value])
            return "experience[0].achievements[0]"
        }
    }

    static let all: [TrapPart] = [
        // The first or the last word of the colleague's employer.
        TrapPart(input: "en-traps", value: "Riverside", field: .company),
        TrapPart(input: "en-traps", value: "Clinic", field: .company),
        TrapPart(input: "en-traps", value: "works at Riverside", field: .achievement),
        TrapPart(input: "it-traps", value: "Cantina", field: .company),
        TrapPart(input: "it-traps", value: "Querce", field: .company),
        TrapPart(input: "de-traps", value: "Stadtpark", field: .company),
        TrapPart(input: "es-traps", value: "Seguros", field: .company),
        TrapPart(input: "es-traps", value: "Pilar", field: .company),
        TrapPart(input: "pt-traps", value: "Azul", field: .company),
        // A word of the wished title.
        TrapPart(input: "it-traps", value: "consulente", field: .headline),
        TrapPart(input: "fr-traps", value: "administrateur", field: .headline),
        TrapPart(input: "fr-traps", value: "réseau", field: .headline),
        TrapPart(input: "pt-traps", value: "arquiteto", field: .headline),
        // A first name read from the other person's email address.
        TrapPart(input: "en-traps", value: "Grace", field: .skill),
        TrapPart(input: "it-traps", value: "Paolo", field: .skill),
        TrapPart(input: "de-traps", value: "Anja", field: .skill),
        TrapPart(input: "es-traps", value: "Rafael", field: .skill),
        TrapPart(input: "fr-traps", value: "Nadia", field: .skill),
        TrapPart(input: "pt-traps", value: "Marcos", field: .skill),
    ]
}
