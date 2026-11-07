import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// Adding and removing the rows of the form's sections.
@MainActor
@Suite("Editor rows")
struct EditorRowTests {

    @Test("a row with nothing in it goes at once, and nothing waits")
    func emptyRowGoesAtOnce() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        #expect(editor.content.experiences.count == 1)

        editor.removeRow(in: .experiences, at: 0)

        #expect(editor.content.experiences.isEmpty)
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a row with something in it waits for the confirmation, and goes with it")
    func rowWithContentWaitsForConfirmation() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .skills)
        editor.content.skills[0].name = "Prototyping"

        editor.removeRow(in: .skills, at: 0)

        #expect(editor.content.skills.map(\.name) == ["Prototyping"])
        #expect(editor.pendingRemoval == RowRemoval(section: .skills, index: 0))

        editor.confirmRemoval()

        #expect(editor.content.skills.isEmpty)
        #expect(editor.pendingRemoval == nil)
    }

    @Test("cancelling the request keeps the row, and confirming then removes nothing")
    func cancelKeepsTheRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .interests)
        editor.content.interests[0] = "Cycling"
        editor.removeRow(in: .interests, at: 0)

        editor.cancelRemoval()
        editor.confirmRemoval()

        #expect(editor.content.interests == ["Cycling"])
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a request for a row that is not there asks for nothing")
    func removingARowThatIsNotThere() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())

        editor.removeRow(in: .education, at: 3)
        editor.confirmRemoval()

        #expect(editor.pendingRemoval == nil)
        #expect(editor.content.education.isEmpty)
    }

    @Test("adding a row is an edit: the autosave stores the CV with the entry, and the status says it waits")
    func addRowIsAnEdit() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        #expect(editor.saveStatus == .saved)

        editor.addRow(to: .experiences)

        #expect(editor.saveStatus == .pending)
        await world.passThePause(thenWrites: 1)
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(try await world.editing.inStore(cv.id).sections.experiences.count == 1)
    }

    @Test("removing a row is an edit too, as soon as the row goes")
    func removeRowIsAnEdit() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.addRow(to: .experiences)
        await editor.saveNow()
        #expect(try await world.editing.inStore(cv.id).sections.experiences.count == 1)

        editor.removeRow(in: .experiences, at: 0)
        #expect(editor.saveStatus == .pending)
        await editor.saveNow()

        #expect(try await world.editing.inStore(cv.id).sections.experiences.isEmpty)
        #expect(editor.saveStatus == .saved)
    }

    @Test("a text too long in a row names its field, in whichever section")
    func textTooLongInARowNamesItsField() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .certifications)

        editor.content.certifications[0].issuer = String(repeating: "x", count: 10_001)

        #expect(editor.saveStatus == .textTooLong(.certificationIssuer))
    }

    @Test("a section above its limit names the section")
    func tooManyRowsNamesTheSection() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())

        editor.content.skills = Array(repeating: SkillRow(name: "Swift", level: nil), count: 201)

        #expect(editor.saveStatus == .tooManyEntries(.skills))
    }

    @Test("a period the domain cannot read is a field code, and the rest of the entry is stored")
    func unreadablePeriodInARow() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.addRow(to: .experiences)
        editor.content.experiences[0].role = "Designer"
        editor.content.experiences[0].periodStart = "last spring"

        await editor.saveNow()

        #expect(editor.saveStatus == .unreadable(.experiencePeriod))
        #expect(editor.content.experiences[0].periodStart == "last spring")
        let stored = try await world.editing.inStore(cv.id).sections.experiences
        #expect(stored.map(\.role) == ["Designer"])
        #expect(stored.map(\.period) == [nil])
    }
}
