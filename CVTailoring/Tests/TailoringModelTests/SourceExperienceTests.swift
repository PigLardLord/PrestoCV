import Foundation
import Testing
import TailoringModel

@Suite("ADR 0013 / R8 · an experience of a source CV")
struct SourceExperienceTests {
    @Test("an experience is built from its description, held as statements")
    func built() throws {
        let period = try TailoringPeriod(start: TailoringDate(year: 2019, month: 4), end: .current)
        let experience = try SourceExperience(role: "Engineer", company: "Acme", location: "Turin", period: period,
                                              description: "\u{2022} Built the API\n\n- Cut costs by 30%\nTrained two juniors")
        #expect(experience.role == "Engineer")
        #expect(experience.company == "Acme")
        #expect(experience.location == "Turin")
        #expect(experience.period == period)
        #expect(experience.statements.map(\.text) == ["Built the API", "Cut costs by 30%", "Trained two juniors"])
    }

    @Test("the statements are the ones the split makes")
    func usesTheSplit() throws {
        let description = "  - one  \r\n* two\n\n1. three"
        #expect(try SourceExperience(role: "r", company: "c", description: description).statements == Statement.split(description))
    }

    @Test("an experience needs only a role and a company")
    func minimal() throws {
        let experience = try SourceExperience(role: "Engineer", company: "Acme")
        #expect(experience.location.isEmpty)
        #expect(experience.period == nil)
        #expect(experience.statements.isEmpty)
    }

    @Test("a description of one paragraph is one statement")
    func oneParagraph() throws {
        #expect(try SourceExperience(role: "r", company: "c", description: "Did the work.").statements.count == 1)
    }

    static let fields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.role) { _ = try SourceExperience(role: $0, company: "x") })
        cases.append(TextFieldCase(.company) { _ = try SourceExperience(role: "x", company: $0) })
        cases.append(TextFieldCase(.location) { _ = try SourceExperience(role: "x", company: "x", location: $0) })
        cases.append(TextFieldCase(.statement) { _ = try SourceExperience(role: "x", company: "x", description: $0) })
        cases.append(TextFieldCase(.statement) { _ = try SourceExperience(role: "x", company: "x", description: "first\n" + $0 + "\nlast") })
        return cases
    }()

    @Test("each field, and each statement, accepts 10,000 bytes and refuses one more", arguments: fields)
    func bounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    @Test("a statement is bounded after its bullet is removed")
    func boundAfterBullet() throws {
        _ = try SourceExperience(role: "r", company: "c", description: "- " + ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(.statement)) { try SourceExperience(role: "r", company: "c", description: "- " + ascii(10_001)) }
    }

    private func lines(_ count: Int) -> String { (0..<count).map { "line \($0)" }.joined(separator: "\n") }

    @Test("an experience holds at most 200 statements")
    func statementCount() throws {
        #expect(TailoringLimits.maxStatementsPerExperience == 200)
        #expect(try SourceExperience(role: "r", company: "c", description: lines(200)).statements.count == 200)
        #expect(throws: TailoringModelError.tooMany(.statements)) { try SourceExperience(role: "r", company: "c", description: lines(201)) }
    }

    @Test("blank lines and bare bullets do not count as statements")
    func blanksDoNotCount() throws {
        let description = lines(200).replacingOccurrences(of: "\n", with: "\n\n- \n")
        #expect(try SourceExperience(role: "r", company: "c", description: description).statements.count == 200)
    }

    // MARK: Built from statements

    @Test("an experience built from statements keeps them as they are")
    func fromStatements() throws {
        let statements = Statement.split("- Built the API\n- Cut costs")
        let experience = try SourceExperience(role: "Engineer", company: "Acme", location: "Turin", statements: statements)
        #expect(experience.statements == statements)
        #expect(experience.role == "Engineer" && experience.company == "Acme" && experience.location == "Turin")
        #expect(experience.period == nil)
    }

    @Test("an experience built from a description is the one built from the statements of its split")
    func descriptionIsItsSplit() throws {
        let description = "\u{2022} Built the API\n\n- Cut costs by 30%\nTrained two juniors"
        #expect(try SourceExperience(role: "r", company: "c", description: description)
                == SourceExperience(role: "r", company: "c", statements: Statement.split(description)))
    }

    @Test("statements are never split again, because a reference is an index and the split is not idempotent")
    func neverSplitAgain() throws {
        #expect(Statement.split("- - x").map(\.text) == ["- x"])
        #expect(Statement.split("- x").map(\.text) == ["x"])
        let once = try Statement(text: "- x")
        let experience = try SourceExperience(role: "r", company: "c", statements: [once, once])
        #expect(experience.statements.map(\.text) == ["- x", "- x"])
    }

    static let statementFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.role) { _ = try SourceExperience(role: $0, company: "x", statements: []) })
        cases.append(TextFieldCase(.company) { _ = try SourceExperience(role: "x", company: $0, statements: []) })
        cases.append(TextFieldCase(.location) { _ = try SourceExperience(role: "x", company: "x", location: $0, statements: []) })
        cases.append(TextFieldCase(.statement) { _ = try SourceExperience(role: "x", company: "x", statements: Statement.split($0)) })
        cases.append(TextFieldCase(.statement) { _ = try SourceExperience(role: "x", company: "x", statements: Statement.split("first\n" + $0)) })
        return cases
    }()

    @Test("each field, and each statement, of an experience built from statements accepts 10,000 bytes and refuses one more", arguments: statementFields)
    func statementBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    @Test("an experience built from statements holds at most 200")
    func statementsCount() throws {
        let one = try Statement(text: "line")
        _ = try SourceExperience(role: "r", company: "c", statements: Array(repeating: one, count: 200))
        #expect(throws: TailoringModelError.tooMany(.statements)) {
            try SourceExperience(role: "r", company: "c", statements: Array(repeating: one, count: 201))
        }
    }
}
