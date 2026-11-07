import Testing
import PrestoCVCoreTestSupport
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

        editor.removeRow(in: .experiences, id: editor.content.experiences[0].id)

        #expect(editor.content.experiences.isEmpty)
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a row with something in it waits for the confirmation, and goes with it")
    func rowWithContentWaitsForConfirmation() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .skills)
        editor.content.skills[0].name = "Prototyping"
        let id = editor.content.skills[0].id

        editor.removeRow(in: .skills, id: id)

        #expect(editor.content.skills.map(\.name) == ["Prototyping"])
        #expect(editor.pendingRemoval == RowRemoval(section: .skills, row: id))

        editor.confirmRemoval()

        #expect(editor.content.skills.isEmpty)
        #expect(editor.pendingRemoval == nil)
    }

    @Test("cancelling the request keeps the row, and confirming then removes nothing")
    func cancelKeepsTheRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .interests)
        editor.content.interests[0].text = "Cycling"
        editor.removeRow(in: .interests, id: editor.content.interests[0].id)

        editor.cancelRemoval()
        editor.confirmRemoval()

        #expect(editor.content.interests.map(\.text) == ["Cycling"])
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a request for a row that is not there asks for nothing")
    func removingARowThatIsNotThere() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .education)
        let gone = editor.content.education[0].id
        editor.removeRow(in: .education, id: gone)
        #expect(editor.content.education.isEmpty)

        editor.removeRow(in: .education, id: gone)
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

        editor.removeRow(in: .experiences, id: editor.content.experiences[0].id)
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

        for _ in 0...200 { editor.addRow(to: .skills) }

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

    // MARK: - Identity

    /// The skills the editor shows, by name, with the id of each.
    func addSkills(_ names: [String], to editor: EditorViewModel) -> [RowID] {
        names.map { name in
            editor.addRow(to: .skills)
            let id = editor.content.skills[editor.content.skills.count - 1].id
            editor.content.skills[editor.content.skills.count - 1].name = name
            return id
        }
    }

    @Test("a row keeps its id while it is typed in and while the rows around it come and go")
    func rowsKeepTheirIdentity() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B", "C"], to: editor)
        #expect(Set(ids).count == 3)

        editor.content.skills[1].name = "B typed in"
        editor.removeRow(in: .skills, id: ids[0])
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.id) == [ids[1], ids[2]])
        #expect(editor.content.skills.map(\.name) == ["B typed in", "C"])
    }

    @Test("the ids stay in the form: two forms of one CV differ in them, and the CV built from either is the same")
    func idsNeverReachTheCV() throws {
        let cv = CV(id: SequentialIDGenerator().next(), title: "Design roles", personal: PersonalDetails(fullName: "Mara Ellison"),
                    sections: CVSections(skills: [Skill(name: "Prototyping")], interests: ["Cycling"]))
        var ids = RowIDs()

        let first = EditorContent(cv, ids: &ids)
        let second = EditorContent(cv, ids: &ids)

        #expect(first != second)
        #expect(first.skills[0].id != second.skills[0].id)
        #expect(first.applied(to: cv) == second.applied(to: cv))
        #expect(first.applied(to: cv) == cv)
    }

    @Test("a removal asked for before a reload does not wait for the reloaded form: it is gone, and removes no other row")
    func pendingRemovalDoesNotSurviveAReload() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        let ids = addSkills(["Prototyping"], to: editor)
        editor.removeRow(in: .skills, id: ids[0])
        #expect(editor.pendingRemoval != nil)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.reload()
        #expect(editor.pendingRemoval == nil)
        let other = addSkills(["Research"], to: editor)
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.id) == other)
        #expect(editor.content.skills.map(\.name) == ["Research"])
    }

    @Test("a removal asked for stays on its row when the view replaces the rows above it")
    func pendingRemovalFollowsItsRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B", "C"], to: editor)
        editor.removeRow(in: .skills, id: ids[1])

        editor.content.skills.remove(at: 0)
        #expect(editor.pendingRemoval == RowRemoval(section: .skills, row: ids[1]))
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.name) == ["C"])
    }

    @Test("a removal asked for whose row the view replaced away removes nothing")
    func pendingRemovalOfAReplacedRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B"], to: editor)
        editor.removeRow(in: .skills, id: ids[0])

        editor.content.skills.remove(at: 0)
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.name) == ["B"])
        #expect(editor.pendingRemoval == nil)
    }

    @Test("opening a CV asks for no removal, and a form unchanged by a reload stays unchanged: nothing is written")
    func unchangedFormAfterAReload() async throws {
        let world = Editing()
        let stored = CV(id: world.editing.ids.next(), title: "Design roles", personal: PersonalDetails(fullName: "Mara Ellison"),
                        sections: CVSections(skills: [Skill(name: "Prototyping")]), language: DocumentLanguage("it"))
        let cv = try await world.editing.store.create(stored)
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.reload()
        let writes = world.editing.writeCount
        world.clock.advance(by: .seconds(5))
        await settle()

        #expect(editor.saveStatus == .saved)
        #expect(editor.content.skills.map(\.name) == ["Prototyping"])
        #expect(world.editing.writeCount == writes)
    }
}
