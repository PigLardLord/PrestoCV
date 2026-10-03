import Testing
import TailoringModel

@Suite("ADR 0013 / R6 · typed references into a snapshot")
struct ReferenceTests {
    private func snapshot() throws -> SourceCV {
        var experiences: [SourceExperience] = []
        experiences.append(try Sample.experience("First", description: "- a\n- b\n- c"))
        experiences.append(try Sample.experience("Second", description: "only line"))
        experiences.append(try Sample.experience("Third"))
        return try SourceCV(language: .english, personal: Sample.personal(), experiences: experiences)
    }

    @Test("an experience is referred to by its position, counted from 0", arguments: 0..<3)
    func experienceInRange(index: Int) throws {
        #expect(try snapshot().experience(index).index == index)
    }

    @Test("an experience outside the snapshot cannot be referred to", arguments: [Int.min, -1, 3, 4, Int.max])
    func experienceOutOfRange(index: Int) throws {
        let cv = try snapshot()
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.experience(index) }
    }

    @Test("a snapshot without experiences has nothing to refer to")
    func noExperiences() throws {
        let cv = try SourceCV(language: .english, personal: Sample.personal())
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.experience(0) }
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statement(experience: 0, line: 0) }
    }

    @Test("a statement is referred to as experience n, line m, counted from 0")
    func statementInRange() throws {
        let cv = try snapshot()
        let ref = try cv.statement(experience: 0, line: 2)
        #expect(ref.experience == (try cv.experience(0)))
        #expect(ref.line == 2)
        #expect(cv.statement(ref).text == "c")
        #expect(cv.statement(try cv.statement(experience: 1, line: 0)).text == "only line")
    }

    @Test("every line of every experience can be referred to, and resolves to its own statement")
    func everyLine() throws {
        let cv = try snapshot()
        for (index, experience) in cv.experiences.enumerated() {
            for (line, statement) in experience.statements.enumerated() {
                #expect(cv.statement(try cv.statement(experience: index, line: line)) == statement)
            }
        }
    }

    @Test("a line outside its experience cannot be referred to", arguments: [(0, -1), (0, 3), (0, Int.max), (1, 1), (2, 0), (2, -1)])
    func lineOutOfRange(experience: Int, line: Int) throws {
        let cv = try snapshot()
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statement(experience: experience, line: line) }
    }

    @Test("a line of an experience outside the snapshot cannot be referred to", arguments: [(-1, 0), (3, 0), (Int.max, 0)])
    func experienceOfLineOutOfRange(experience: Int, line: Int) throws {
        let cv = try snapshot()
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statement(experience: experience, line: line) }
    }

    @Test("references to the same place are equal and hash alike")
    func equality() throws {
        let cv = try snapshot()
        let one = try cv.statement(experience: 0, line: 1), same = try cv.statement(experience: 0, line: 1)
        #expect(one == same)
        #expect(Set([one, same]).count == 1)
        #expect(one != (try cv.statement(experience: 0, line: 2)))
        #expect(one != (try cv.statement(experience: 1, line: 0)))
    }
}
