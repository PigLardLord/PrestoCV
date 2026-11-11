import Foundation
import Testing
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation

/// The order of the rows of a section: where a new row goes, and moving rows up and down or by a list's drag.
@MainActor
@Suite("Editor row order")
struct MoveRowTests {

    /// An editor on a stored CV whose skills are `names`, in that order, stored.
    func editor(withSkills names: [String], in world: Editing) async throws -> (EditorViewModel, CV) {
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        for name in names {
            editor.addRow(to: .skills)
            editor.content.skills[editor.content.skills.count - 1].name = name
        }
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(editor.content.skills.map(\.name) == names)
        return (editor, cv)
    }

    func skillID(_ name: String, in editor: EditorViewModel) throws -> RowID {
        try #require(editor.content.skills.first { $0.name == name }).id
    }

    // MARK: Up and down

    @Test("moving a row up is an edit: the status waits, and the store keeps the new order")
    func moveUpIsAnEdit() async throws {
        let world = Editing()
        let (editor, cv) = try await editor(withSkills: ["Sketching", "Prototyping", "Research"], in: world)

        editor.moveRow(in: .skills, id: try skillID("Research", in: editor), by: -2)

        #expect(editor.content.skills.map(\.name) == ["Research", "Sketching", "Prototyping"])
        #expect(editor.saveStatus == .pending)
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(try await world.editing.inStore(cv.id).sections.skills.map(\.name)
            == ["Research", "Sketching", "Prototyping"])
    }

    @Test("moving a row down keeps its id, so the row stays the same row")
    func moveDownKeepsTheID() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping"], in: world)
        let moved = try skillID("Sketching", in: editor)

        editor.moveRow(in: .skills, id: moved, by: 1)

        #expect(editor.content.skills.map(\.id).last == moved)
        #expect(editor.content.skills.map(\.name) == ["Prototyping", "Sketching"])
    }

    @Test("a move past either end, by 0 places, or of a row that is not there does nothing and is no edit")
    func refusedMovesDoNothing() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping", "Research"], in: world)
        let first = try skillID("Sketching", in: editor)
        let last = try skillID("Research", in: editor)
        let gone = RowID(value: 9_999)

        for (id, offset) in [(first, -1), (last, 1), (first, 3), (last, -3), (first, 0), (gone, 1)] {
            #expect(!editor.canMoveRow(in: .skills, id: id, by: offset))
            editor.moveRow(in: .skills, id: id, by: offset)
        }

        #expect(editor.content.skills.map(\.name) == ["Sketching", "Prototyping", "Research"])
        #expect(editor.saveStatus == .saved)
    }

    @Test("a row can move up from the second place and down from the second to last, and to either end")
    func allowedMoves() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping", "Research"], in: world)
        let first = try skillID("Sketching", in: editor)
        let middle = try skillID("Prototyping", in: editor)
        let last = try skillID("Research", in: editor)

        #expect(editor.canMoveRow(in: .skills, id: first, by: 1))
        #expect(editor.canMoveRow(in: .skills, id: first, by: 2))
        #expect(editor.canMoveRow(in: .skills, id: middle, by: -1))
        #expect(editor.canMoveRow(in: .skills, id: middle, by: 1))
        #expect(editor.canMoveRow(in: .skills, id: last, by: -2))
    }

    @Test("a row of one section cannot move in another")
    func rowOfAnotherSection() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping"], in: world)
        editor.addRow(to: .interests)
        editor.addRow(to: .interests)

        let skill = try skillID("Sketching", in: editor)

        #expect(!editor.canMoveRow(in: .interests, id: skill, by: 1))
    }

    // MARK: Drag

    @Test("a drag of the first row to the end puts it last, and is an edit")
    func dragToTheEnd() async throws {
        let world = Editing()
        let (editor, cv) = try await editor(withSkills: ["Sketching", "Prototyping", "Research"], in: world)

        editor.moveRows(in: .skills, from: IndexSet(integer: 0), to: 3)

        #expect(editor.content.skills.map(\.name) == ["Prototyping", "Research", "Sketching"])
        #expect(editor.saveStatus == .pending)
        await editor.saveNow()
        #expect(try await world.editing.inStore(cv.id).sections.skills.map(\.name)
            == ["Prototyping", "Research", "Sketching"])
    }

    @Test("a drag of several rows keeps them in their order, before the row at the destination")
    func dragOfSeveralRows() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["A1", "B2", "C3", "D4", "E5"], in: world)

        editor.moveRows(in: .skills, from: IndexSet([0, 2]), to: 4)

        #expect(editor.content.skills.map(\.name) == ["B2", "D4", "A1", "C3", "E5"])
    }

    @Test("a drag that changes no place, or names a place outside the section, does nothing and is no edit")
    func refusedDragsDoNothing() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping", "Research"], in: world)

        editor.moveRows(in: .skills, from: IndexSet(integer: 1), to: 1)
        editor.moveRows(in: .skills, from: IndexSet(integer: 1), to: 2)
        editor.moveRows(in: .skills, from: IndexSet(), to: 0)
        editor.moveRows(in: .skills, from: IndexSet(integer: 3), to: 0)
        editor.moveRows(in: .skills, from: IndexSet(integer: 0), to: 4)
        editor.moveRows(in: .skills, from: IndexSet(integer: 0), to: -1)

        #expect(editor.content.skills.map(\.name) == ["Sketching", "Prototyping", "Research"])
        #expect(editor.saveStatus == .saved)
    }

    // MARK: Where a new row goes

    @Test("a new job, study or certification goes first, as a CV lists the newest first", arguments: [
        EditorSection.experiences, .education, .certifications,
    ])
    func newRowGoesFirst(_ section: EditorSection) async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: section)
        let older = try #require(editor.addedRow)

        editor.addRow(to: section)

        let rows = editor.content.rowIDs(in: section)
        #expect(rows.count == 2)
        #expect(rows.last == older)
        #expect(rows.first == editor.addedRow)
    }

    @Test("a new skill, language, profile or interest goes last", arguments: [
        EditorSection.skills, .languages, .profiles, .interests,
    ])
    func newRowGoesLast(_ section: EditorSection) async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: section)
        let older = try #require(editor.addedRow)

        editor.addRow(to: section)

        let rows = editor.content.rowIDs(in: section)
        #expect(rows.count == 2)
        #expect(rows.first == older)
        #expect(rows.last == editor.addedRow)
    }

    // MARK: Around a move

    @Test("a move changes only its section")
    func moveChangesOnlyItsSection() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping"], in: world)
        editor.addRow(to: .interests)
        editor.content.interests[0].text = "Cycling"
        editor.addRow(to: .interests)
        editor.content.interests[1].text = "Chess"
        let before = editor.content

        editor.moveRow(in: .skills, id: try skillID("Prototyping", in: editor), by: -1)

        #expect(editor.content.interests == before.interests)
        #expect(editor.content.experiences == before.experiences)
        #expect(editor.content.skills.map(\.name) == ["Prototyping", "Sketching"])
    }

    @Test("a removal waiting for its confirmation still removes its row after a move")
    func pendingRemovalSurvivesAMove() async throws {
        let world = Editing()
        let (editor, _) = try await editor(withSkills: ["Sketching", "Prototyping", "Research"], in: world)
        let asked = try skillID("Prototyping", in: editor)
        editor.removeRow(in: .skills, id: asked)
        #expect(editor.pendingRemoval?.row == asked)

        editor.moveRow(in: .skills, id: try skillID("Sketching", in: editor), by: 2)
        #expect(editor.pendingRemoval?.row == asked)
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.name) == ["Research", "Sketching"])
    }
}

/// The order a move gives, as the places the rows had.
@Suite("Row order")
struct RowOrderTests {

    @Test("a row moved by places, up or down")
    func moveByPlaces() {
        #expect(RowOrder.moving(0, by: 1, among: 3) == [1, 0, 2])
        #expect(RowOrder.moving(2, by: -2, among: 3) == [2, 0, 1])
        #expect(RowOrder.moving(1, by: 1, among: 3) == [0, 2, 1])
    }

    @Test("no order for an offset of 0, a row or a place outside the rows")
    func refusedMoveByPlaces() {
        #expect(RowOrder.moving(1, by: 0, among: 3) == nil)
        #expect(RowOrder.moving(0, by: -1, among: 3) == nil)
        #expect(RowOrder.moving(2, by: 1, among: 3) == nil)
        #expect(RowOrder.moving(3, by: -1, among: 3) == nil)
        #expect(RowOrder.moving(-1, by: 1, among: 3) == nil)
        #expect(RowOrder.moving(0, by: Int.max, among: 3) == nil)
        #expect(RowOrder.moving(2, by: Int.min, among: 3) == nil)
        #expect(RowOrder.moving(0, by: 1, among: 0) == nil)
    }

    @Test("rows dragged before the row at the destination, in their order")
    func drag() {
        #expect(RowOrder.moving(IndexSet(integer: 0), to: 3, among: 3) == [1, 2, 0])
        #expect(RowOrder.moving(IndexSet(integer: 3), to: 0, among: 4) == [3, 0, 1, 2])
        #expect(RowOrder.moving(IndexSet([0, 2]), to: 4, among: 5) == [1, 3, 0, 2, 4])
        #expect(RowOrder.moving(IndexSet([1, 3]), to: 0, among: 4) == [1, 3, 0, 2])
    }

    @Test("no order for a drag that changes no place, or names a place outside the rows")
    func refusedDrag() {
        #expect(RowOrder.moving(IndexSet(integer: 1), to: 1, among: 3) == nil)
        #expect(RowOrder.moving(IndexSet(integer: 1), to: 2, among: 3) == nil)
        #expect(RowOrder.moving(IndexSet([0, 1]), to: 0, among: 3) == nil)
        #expect(RowOrder.moving(IndexSet(), to: 0, among: 3) == nil)
        #expect(RowOrder.moving(IndexSet(integer: 3), to: 0, among: 3) == nil)
        #expect(RowOrder.moving(IndexSet(integer: 0), to: 4, among: 3) == nil)
        #expect(RowOrder.moving(IndexSet(integer: 0), to: -1, among: 3) == nil)
    }

    @Test("rows in an order, and as they are when the order does not hold each place once")
    func arranged() {
        #expect(RowOrder.arranged(["a", "b", "c"], in: [2, 0, 1]) == ["c", "a", "b"])
        #expect(RowOrder.arranged(["a", "b"], in: [0, 0]) == ["a", "b"])
        #expect(RowOrder.arranged(["a", "b"], in: [1]) == ["a", "b"])
        #expect(RowOrder.arranged(["a", "b"], in: [0, 2]) == ["a", "b"])
        #expect(RowOrder.arranged(["a", "a"], in: [1, 0]) == ["a", "a"])
    }
}
