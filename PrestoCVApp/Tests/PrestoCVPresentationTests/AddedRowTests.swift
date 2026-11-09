import Testing
import PrestoCVPresentation

/// The row just added, which the view focuses and scrolls into view once.
@MainActor
@Suite("Added row")
struct AddedRowTests {

    @Test("adding a row names it as the one to show, the newest one when several are added")
    func addRowNamesTheNewRow() {
        let editor = Editing().editor(.blank)
        #expect(editor.addedRow == nil)

        editor.addRow(to: .skills)
        editor.addRow(to: .skills)

        #expect(editor.content.skills.count == 2)
        #expect(editor.addedRow == editor.content.skills.last?.id)
        editor.addRow(to: .profiles)
        #expect(editor.addedRow == editor.content.profiles.last?.id)
    }

    @Test("once the view has shown the row, no row waits to be shown")
    func shownClearsIt() {
        let editor = Editing().editor(.blank)
        editor.addRow(to: .interests)

        editor.rowWasShown()

        #expect(editor.addedRow == nil)
        #expect(editor.content.interests.count == 1)
    }
}
