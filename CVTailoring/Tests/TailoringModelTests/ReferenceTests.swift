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
        #expect(try snapshot().experienceRef(at: index).index == index)
    }

    static let experiencesOutOfRange: [Int] = {
        var indices: [Int] = []
        indices.append(contentsOf: [Int.min, -1, 3, 4, Int.max])
        return indices
    }()

    @Test("an experience outside the snapshot cannot be referred to", arguments: experiencesOutOfRange)
    func experienceOutOfRange(index: Int) throws {
        let cv = try snapshot()
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.experienceRef(at: index) }
    }

    @Test("a snapshot without experiences has nothing to refer to")
    func noExperiences() throws {
        let cv = try SourceCV(language: .english, personal: Sample.personal())
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.experienceRef(at: 0) }
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statementRef(experience: 0, line: 0) }
    }

    @Test("a statement is referred to as experience n, line m, counted from 0")
    func statementInRange() throws {
        let cv = try snapshot()
        let ref = try cv.statementRef(experience: 0, line: 2)
        #expect(ref.experience == (try cv.experienceRef(at: 0)))
        #expect(ref.line == 2)
        #expect(try cv.statement(ref).text == "c")
        #expect(try cv.statement(cv.statementRef(experience: 1, line: 0)).text == "only line")
    }

    @Test("every line of every experience can be referred to, and resolves to its own statement")
    func everyLine() throws {
        let cv = try snapshot()
        for (index, experience) in cv.experiences.enumerated() {
            for (line, statement) in experience.statements.enumerated() {
                #expect(try cv.statement(cv.statementRef(experience: index, line: line)) == statement)
            }
        }
    }

    static let linesOutOfRange: [(Int, Int)] = {
        var cases: [(Int, Int)] = []
        cases.append((0, -1))
        cases.append((0, 3))
        cases.append((0, Int.max))
        cases.append((1, 1))
        cases.append((2, 0))
        cases.append((2, -1))
        return cases
    }()

    @Test("a line outside its experience cannot be referred to", arguments: linesOutOfRange)
    func lineOutOfRange(experience: Int, line: Int) throws {
        let cv = try snapshot()
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statementRef(experience: experience, line: line) }
    }

    static let linesOfExperiencesOutOfRange: [(Int, Int)] = {
        var cases: [(Int, Int)] = []
        cases.append((-1, 0))
        cases.append((3, 0))
        cases.append((Int.max, 0))
        return cases
    }()

    @Test("a line of an experience outside the snapshot cannot be referred to", arguments: linesOfExperiencesOutOfRange)
    func experienceOfLineOutOfRange(experience: Int, line: Int) throws {
        let cv = try snapshot()
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statementRef(experience: experience, line: line) }
    }

    @Test("references to the same place are equal and hash alike")
    func equality() throws {
        let cv = try snapshot()
        let one = try cv.statementRef(experience: 0, line: 1), same = try cv.statementRef(experience: 0, line: 1)
        #expect(one == same)
        #expect(Set([one, same]).count == 1)
        #expect(one != (try cv.statementRef(experience: 0, line: 2)))
        #expect(one != (try cv.statementRef(experience: 1, line: 0)))
    }

    @Test("a reference made by a bigger snapshot is refused by a smaller one, whether its experience or its line is out of range")
    func foreignReference() throws {
        let cv = try snapshot(), bigger = try Sample.biggerSource()
        let farExperience = try bigger.statementRef(experience: 4, line: 0)   // the snapshot has three experiences
        let farLine = try bigger.statementRef(experience: 1, line: 4)         // its second experience has one statement
        let emptyExperience = try bigger.statementRef(experience: 2, line: 0) // its third experience has no statement
        for foreign in [farExperience, farLine, emptyExperience] {
            #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statement(foreign) }
        }
    }

    @Test("a reference made by an equal snapshot resolves")
    func equalSnapshotReference() throws {
        let cv = try snapshot(), same = try snapshot()
        #expect(try cv.statement(same.statementRef(experience: 0, line: 1)).text == "b")
    }

    @Test("an experience reference resolves to the experience it names", arguments: 0..<3)
    func resolveExperience(index: Int) throws {
        let cv = try snapshot()
        #expect(try cv.experience(cv.experienceRef(at: index)) == cv.experiences[index])
    }

    @Test("an experience reference made by a bigger snapshot is refused by a smaller one")
    func foreignExperienceReference() throws {
        let cv = try snapshot(), bigger = try Sample.biggerSource()
        for index in 3..<6 {
            let foreign = try bigger.experienceRef(at: index)
            #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.experience(foreign) }
        }
    }

    @Test("an experience reference made by an equal snapshot resolves")
    func equalSnapshotExperienceReference() throws {
        let cv = try snapshot(), same = try snapshot()
        #expect(try cv.experience(same.experienceRef(at: 1)).role == "Second")
    }

    // MARK: A reference carries its snapshot

    @Test("a reference made by another snapshot is refused even when its indices are in range of this one")
    func otherSnapshotInRange() throws {
        let cv = try Sample.source(), other = try Sample.otherSource()
        #expect(cv != other)
        let foreignStatement = try other.statementRef(experience: 0, line: 1)
        let foreignExperience = try other.experienceRef(at: 1)
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statement(foreignStatement) }
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.experience(foreignExperience) }
        #expect(try other.statement(foreignStatement).text == "cut costs by 40%")
        #expect(try other.experience(foreignExperience).role == "Second")
    }

    @Test("references to the same place of different snapshots are different, and of equal snapshots are equal")
    func referencesAndSnapshots() throws {
        let cv = try Sample.source(), same = try Sample.source(), other = try Sample.otherSource()
        #expect(try cv.experienceRef(at: 0) == same.experienceRef(at: 0))
        #expect(try cv.statementRef(experience: 0, line: 2) == same.statementRef(experience: 0, line: 2))
        #expect(try cv.experienceRef(at: 0) != other.experienceRef(at: 0))
        #expect(try cv.statementRef(experience: 0, line: 2) != other.statementRef(experience: 0, line: 2))
        #expect(try Set([cv.statementRef(experience: 0, line: 0), same.statementRef(experience: 0, line: 0)]).count == 1)
    }

    @Test("a snapshot that differs in one word makes references of its own")
    func oneWordApart() throws {
        let cv = try Sample.source()
        var experiences = cv.experiences
        experiences[1] = try Sample.experience("Second", description: "- ran the on-call rotas")
        let changed = try SourceCV(language: cv.language, personal: cv.personal, summary: cv.summary, experiences: experiences)
        let ref = try changed.statementRef(experience: 1, line: 0)
        #expect(throws: TailoringModelError.referenceOutOfRange) { try cv.statement(ref) }
    }
}
