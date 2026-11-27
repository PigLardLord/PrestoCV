import Testing
import PrestoCVPresentation

/// A view binds a row's fields by the row's id, never by its place in the section, so that a field still on screen after
/// its row went can neither write to the row that took the place nor fail (#32).
@MainActor
@Suite("Row by id")
struct RowByIDTests {

    @Test("a row is read and written by its id, wherever the rows before it went")
    func rowIsFoundByItsID() {
        let editor = Editing().editor(.blank)
        editor.addRow(to: .skills)
        editor.addRow(to: .skills)
        editor.content.skills[0].name = "Swift"
        let second = editor.content.skills[1]
        editor.removeRow(in: .skills, id: editor.content.skills[0].id)
        editor.confirmRemoval()

        editor.content.skills[row: second.id, or: second].name = "Kotlin"

        #expect(editor.content.skills.map(\.name) == ["Kotlin"])
        #expect(editor.content.skills[row: second.id, or: second].name == "Kotlin")
    }

    @Test("a row that went reads as the row last shown, and a write to it changes nothing")
    func removedRowTakesNoWrite() {
        let editor = Editing().editor(.blank)
        editor.addRow(to: .interests)
        editor.addRow(to: .interests)
        let gone = editor.content.interests[0]
        editor.removeRow(in: .interests, id: gone.id)
        let before = editor.content

        editor.content.interests[row: gone.id, or: gone].text = "Cycling"

        #expect(editor.content == before)
        #expect(editor.content.interests[row: gone.id, or: gone] == gone)
    }
}
