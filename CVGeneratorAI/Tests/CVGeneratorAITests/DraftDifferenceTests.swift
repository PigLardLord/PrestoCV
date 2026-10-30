import Testing
@testable import CVGeneratorAI

/// What a stage of the AI draft changed, value by value, as the trace of a test build names it (ADR 0032): entries are matched by
/// their values, not by their place, so that a removed job is one removal and not a change of every job after it.
@Suite("The difference a stage of the draft made")
struct DraftDifferenceTests {

    private typealias Change = DraftDifference.Change

    private static let teacher = Experience(title: "insegnante", company: "scuola Don Milani", startDate: "2016", current: true)
    private static let assistant = Experience(title: "assistente", company: "asilo nido", startDate: "2012", endDate: "2016")
    private static let tutor = Experience(title: "tutor", company: "doposcuola Arcobaleno", startDate: "2010", endDate: "2012")

    @Test("Two equal drafts differ in nothing")
    func equal() {
        let draft = CVData(personalInfo: PersonalInfo(name: "Maria Rossi"), summary: "Insegnante.", experience: [Self.teacher])
        #expect(DraftDifference(from: draft, to: draft).isEmpty)
    }

    @Test("A value the stage removed is named by its path, with what it was")
    func removedValue() {
        let difference = DraftDifference(
            from: CVData(personalInfo: PersonalInfo(name: "Maria Rossi", location: "Bologna"), summary: "Un'insegnante attenta."),
            to: CVData(personalInfo: PersonalInfo(name: "Maria Rossi"))
        )
        #expect(difference.removed == [
            Change(path: "person.location", before: "Bologna", after: nil), Change(path: "summary", before: "Un'insegnante attenta.", after: nil),
        ])
        #expect(difference.changed.isEmpty)
        #expect(difference.added.isEmpty)
    }

    @Test("A job removed from the middle is the removal of its values, at its own index, and moves no other job")
    func removedEntry() {
        let difference = DraftDifference(
            from: CVData(experience: [Self.teacher, Self.assistant, Self.tutor]), to: CVData(experience: [Self.teacher, Self.tutor])
        )
        #expect(difference.removed.map(\.path) == [
            "experience[1].title", "experience[1].company", "experience[1].startDate", "experience[1].endDate", "experience[1].current",
        ])
        #expect(difference.removed.first?.before == "assistente")
        #expect(difference.changed.isEmpty)
        #expect(difference.added.isEmpty)
        #expect(difference.reordered.isEmpty)
    }

    @Test("A value the stage rewrote is a change, from the old value to the new one")
    func changed() {
        let rewritten = Experience(title: "maestra", company: "scuola Don Milani", startDate: "2016", current: true)
        let difference = DraftDifference(from: CVData(experience: [Self.teacher]), to: CVData(experience: [rewritten]))
        #expect(difference.changed == [Change(path: "experience[0].title", before: "insegnante", after: "maestra")])
        #expect(difference.removed.isEmpty)
        #expect(difference.added.isEmpty)
    }

    @Test("An entry the stage added is named at its index after the stage")
    func added() {
        let difference = DraftDifference(
            from: CVData(skills: [Skill(name: "didattica")]), to: CVData(skills: [Skill(name: "didattica"), Skill(name: "Montessori")])
        )
        #expect(difference.added == [Change(path: "skills[1].name", before: nil, after: "Montessori")])
        #expect(difference.removed.isEmpty)
    }

    @Test("Jobs that came out in another order are one line, with the index each had before")
    func reordered() {
        let difference = DraftDifference(
            from: CVData(experience: [Self.teacher, Self.assistant, Self.tutor]),
            to: CVData(experience: [Self.tutor, Self.teacher, Self.assistant])
        )
        #expect(difference.reordered == ["experience: 2, 0, 1"])
        #expect(difference.removed.isEmpty)
        #expect(difference.changed.isEmpty)
        #expect(difference.added.isEmpty)
    }

    @Test("A new entry among reordered ones is shown with a plus")
    func reorderedWithNewEntry() {
        let difference = DraftDifference(
            from: CVData(interests: ["scacchi", "escursioni"]), to: CVData(interests: ["escursioni", "lettura", "scacchi"])
        )
        #expect(difference.reordered == ["interests: 1, +, 0"])
        #expect(difference.added == [Change(path: "interests[1]", before: nil, after: "lettura")])
    }

    @Test("An achievement removed from a job is one removal, not a change of every achievement after it")
    func achievements() {
        let before = Experience(title: "insegnante", company: "scuola Don Milani", achievements: ["Formato 3 insegnanti", "Gite", "Laboratori"])
        let after = Experience(title: "insegnante", company: "scuola Don Milani", achievements: ["Formato 3 insegnanti", "Laboratori"])
        let difference = DraftDifference(from: CVData(experience: [before]), to: CVData(experience: [after]))
        #expect(difference.removed == [Change(path: "experience[0].achievements[1]", before: "Gite", after: nil)])
        #expect(difference.changed.isEmpty)
        #expect(difference.added.isEmpty)
    }

    @Test("A level that many skills share does not make two different skills one", arguments: [
        (CVData(skills: [Skill(name: "Swift", level: .advanced)]), CVData(skills: [Skill(name: "Kotlin", level: .advanced)])),
        (CVData(languages: [Language(name: "inglese", proficiency: .native)]), CVData(languages: [Language(name: "tedesco", proficiency: .native)])),
    ])
    func sharedFields(before: CVData, after: CVData) {
        let difference = DraftDifference(from: before, to: after)
        #expect(difference.changed.isEmpty)
        #expect(difference.removed.count == 2)
        #expect(difference.added.count == 2)
    }

    @Test("Two jobs with no title are not the same job for it")
    func emptyValues() {
        let first = Experience(company: "scuola Don Milani")
        let other = Experience(company: "asilo nido")
        let difference = DraftDifference(from: CVData(experience: [first]), to: CVData(experience: [other]))
        #expect(difference.changed.isEmpty)
        #expect(difference.removed.contains(Change(path: "experience[0].company", before: "scuola Don Milani", after: nil)))
        #expect(difference.added.contains(Change(path: "experience[0].company", before: nil, after: "asilo nido")))
    }
}
