import Testing
import PrestoCVPresentation

/// An entry on a page of its own, where the screen is narrow (an iPhone): a row of a section with several fields opens
/// there, and the page closes when the row goes, the screen widens or the CV is read again. Skills and interests, one
/// field each, stay in the form, as every row does on a wide screen.
@MainActor
@Suite("Entry page")
struct EntryPageTests {

    nonisolated static let pageSections: [EditorSection] = [.experiences, .education, .languages, .certifications, .profiles]
    nonisolated static let inPlaceSections: [EditorSection] = [.skills, .interests]

    func editor(narrow: Bool) -> EditorViewModel {
        let editor = Editing().editor(.blank)
        editor.layoutChanged(isNarrow: narrow)
        return editor
    }

    /// The ids of a section's rows, in the form's order.
    func ids(_ editor: EditorViewModel, _ section: EditorSection) -> [RowID] {
        switch section {
        case .experiences: editor.content.experiences.map(\.id)
        case .education: editor.content.education.map(\.id)
        case .skills: editor.content.skills.map(\.id)
        case .languages: editor.content.languages.map(\.id)
        case .certifications: editor.content.certifications.map(\.id)
        case .profiles: editor.content.profiles.map(\.id)
        case .interests: editor.content.interests.map(\.id)
        }
    }

    func isOpen(_ editor: EditorViewModel, _ section: EditorSection, _ row: RowID?) -> Bool {
        editor.openedEntry?.section == section && editor.openedEntry?.row == row && row != nil
    }

    // MARK: Opening

    @Test("on a narrow screen, a row added to a section with several fields opens on its page", arguments: pageSections)
    func addingOpensThePage(section: EditorSection) {
        let editor = editor(narrow: true)

        editor.addRow(to: section)

        #expect(editor.showsOnAPage(section))
        #expect(isOpen(editor, section, editor.addedRow))
    }

    @Test("skills and interests stay in the form, on a narrow screen too", arguments: inPlaceSections)
    func oneFieldRowsStayInTheForm(section: EditorSection) throws {
        let editor = editor(narrow: true)

        editor.addRow(to: section)
        let added = try #require(editor.addedRow)
        editor.openEntry(in: section, id: added)

        #expect(!editor.showsOnAPage(section))
        #expect(editor.openedEntry == nil)
    }

    @Test("on a wide screen every row stays in the form", arguments: EditorSection.allCases)
    func wideScreenOpensNoPage(section: EditorSection) throws {
        let editor = editor(narrow: false)

        editor.addRow(to: section)
        let added = try #require(editor.addedRow)
        editor.openEntry(in: section, id: added)

        #expect(!editor.showsOnAPage(section))
        #expect(editor.openedEntry == nil)
    }

    @Test("a tap on a row opens its page, and Back closes it")
    func openAndClose() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .education)
        editor.addRow(to: .education)
        editor.closeEntry()
        #expect(editor.openedEntry == nil)
        let older = try #require(ids(editor, .education).last)

        editor.openEntry(in: .education, id: older)
        #expect(isOpen(editor, .education, older))

        editor.closeEntry()
        #expect(editor.openedEntry == nil)
        #expect(ids(editor, .education).count == 2)
    }

    @Test("the hint to move a row shows where rows open on a page and there are two to order")
    func moveHint() {
        let narrow = editor(narrow: true)
        narrow.addRow(to: .experiences)
        #expect(!narrow.showsMoveHint(in: .experiences))
        narrow.addRow(to: .experiences)
        narrow.addRow(to: .skills)
        narrow.addRow(to: .skills)
        #expect(narrow.showsMoveHint(in: .experiences))
        #expect(!narrow.showsMoveHint(in: .skills))
        #expect(!narrow.showsMoveHint(in: .education))

        narrow.layoutChanged(isNarrow: false)

        #expect(!narrow.showsMoveHint(in: .experiences))
    }

    @Test("the page finds its row by id wherever it stands, and nothing once the row went")
    func rowByID() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .experiences)
        let first = try #require(editor.addedRow)
        editor.addRow(to: .experiences)
        editor.content.experiences[0].role = "Site foreman"
        let second = try #require(editor.content.experiences.first?.id)

        #expect(editor.content.experiences[row: second]?.role == "Site foreman")
        #expect(editor.content.experiences[row: first]?.id == first)

        editor.removeRow(in: .experiences, id: first)

        #expect(editor.content.experiences[row: first] == nil)
        #expect(editor.content.experiences[row: second] != nil)
    }

    @Test("a row opens only from its own section")
    func openNeedsTheRowInItsSection() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .experiences)
        editor.closeEntry()
        let job = try #require(editor.content.experiences.first?.id)

        editor.openEntry(in: .education, id: job)

        #expect(editor.openedEntry == nil)
    }

    // MARK: Closing

    @Test("the page closes when the screen widens, and the row stays")
    func wideningClosesThePage() {
        let editor = editor(narrow: true)
        editor.addRow(to: .certifications)

        editor.layoutChanged(isNarrow: false)

        #expect(editor.openedEntry == nil)
        #expect(editor.content.certifications.count == 1)
    }

    @Test("a blank row removed from its page goes at once, and the page closes")
    func removingABlankRowClosesThePage() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .languages)
        let added = try #require(editor.addedRow)

        editor.removeRow(in: .languages, id: added)

        #expect(editor.content.languages.isEmpty)
        #expect(editor.openedEntry == nil)
    }

    @Test("a filled row removed from its page asks there, and the page closes once the person confirms")
    func removingAFilledRowAsksOnThePage() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .experiences)
        let added = try #require(editor.addedRow)
        editor.content.experiences[0].role = "Site foreman"

        editor.removeRow(in: .experiences, id: added)
        #expect(editor.asksToRemove(row: added, onItsPage: true))
        #expect(!editor.asksToRemove(row: added, onItsPage: false))

        editor.cancelRemoval()
        #expect(isOpen(editor, .experiences, added))
        #expect(!editor.asksToRemove(row: added, onItsPage: true))

        editor.removeRow(in: .experiences, id: added)
        editor.confirmRemoval()
        #expect(editor.content.experiences.isEmpty)
        #expect(editor.openedEntry == nil)
    }

    @Test("a row removed from the form, with no page open, asks in the form")
    func removingFromTheFormAsksThere() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .profiles)
        let added = try #require(editor.addedRow)
        editor.content.profiles[0].platform = "Portfolio"
        editor.closeEntry()

        editor.removeRow(in: .profiles, id: added)

        #expect(editor.asksToRemove(row: added, onItsPage: false))
        #expect(!editor.asksToRemove(row: added, onItsPage: true))
    }

    @Test("removing another row leaves the page open")
    func removingAnotherRowKeepsThePage() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .experiences)
        let first = try #require(editor.addedRow)
        editor.addRow(to: .experiences)
        let second = try #require(editor.addedRow)

        editor.removeRow(in: .experiences, id: first)

        #expect(ids(editor, .experiences) == [second])
        #expect(isOpen(editor, .experiences, second))
    }

    @Test("moving the open row keeps its page open")
    func movingKeepsThePage() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .education)
        editor.addRow(to: .education)
        let newest = try #require(editor.addedRow)

        editor.moveRow(in: .education, id: newest, by: 1)

        #expect(ids(editor, .education).last == newest)
        #expect(isOpen(editor, .education, newest))
    }

    @Test("the page closes when the form no longer has its row")
    func contentWithoutTheRowClosesThePage() {
        let editor = editor(narrow: true)
        editor.addRow(to: .languages)
        var changed = editor.content
        changed.languages = []

        editor.content = changed

        #expect(editor.openedEntry == nil)
    }

    @Test("the page closes when its row's id arrives on two rows, which cannot be told apart")
    func duplicatedIDClosesThePage() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .languages)
        var changed = editor.content
        changed.languages.append(try #require(changed.languages.first))

        editor.content = changed

        #expect(editor.openedEntry == nil)
        #expect(editor.content.languages.count == 2)
    }

    @Test("the page closes when the CV is read again after a conflict")
    func reloadClosesThePage() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.layoutChanged(isNarrow: true)
        editor.addRow(to: .experiences)
        #expect(editor.openedEntry != nil)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.reload()

        #expect(editor.saveStatus != .conflict)
        #expect(editor.openedEntry == nil)
    }

    @Test("the page stays open when the form is saved as a copy after a conflict: the rows stay as they were")
    func saveAsCopyKeepsThePage() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.layoutChanged(isNarrow: true)
        editor.addRow(to: .experiences)
        let opened = try #require(editor.openedEntry)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.saveAsCopy()

        #expect(editor.saveStatus != .conflict)
        #expect(editor.openedEntry == opened)
        #expect(editor.content.experiences.map(\.id).contains(opened.row))
    }

    @Test("closing the page before its new row was shown forgets the row, so the form gives it no focus later")
    func closingBeforeShownForgetsTheAddedRow() {
        let editor = editor(narrow: true)
        editor.addRow(to: .experiences)
        #expect(editor.addedRow != nil)

        editor.closeEntry()

        #expect(editor.addedRow == nil)
        #expect(editor.openedEntry == nil)
    }

    @Test("closing the page leaves a row added elsewhere waiting for its focus")
    func closingKeepsAnotherAddedRow() throws {
        let editor = editor(narrow: true)
        editor.addRow(to: .experiences)
        let page = try #require(editor.openedEntry)
        editor.addRow(to: .skills)
        let skill = try #require(editor.addedRow)
        #expect(editor.openedEntry == page)

        editor.closeEntry()

        #expect(editor.addedRow == skill)
    }
}
