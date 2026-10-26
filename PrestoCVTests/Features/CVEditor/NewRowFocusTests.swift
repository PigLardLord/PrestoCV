import Testing
@testable import PrestoCV

@MainActor
@Suite("New row focus - the row just added takes the keyboard focus, once")
struct NewRowFocusTests {

    @Test("The row that was asked for takes the focus")
    func requestedRowTakesTheFocus() {
        let focus = NewRowFocus()

        focus.request(row: 2)

        #expect(focus.take(row: 2))
    }

    @Test("Another row of the section does not take the focus")
    func otherRowsDoNotTakeTheFocus() {
        let focus = NewRowFocus()

        focus.request(row: 2)

        #expect(!focus.take(row: 0))
        #expect(!focus.take(row: 1))
        #expect(focus.take(row: 2), "Rows asked first must not use up the request of the new row")
    }

    @Test("The new row takes the focus once, so that scrolling it back into view does not take it again")
    func theFocusIsTakenOnce() {
        let focus = NewRowFocus()
        focus.request(row: 0)

        _ = focus.take(row: 0)

        #expect(!focus.take(row: 0))
    }

    @Test("Without a request no row takes the focus, as when the editor opens")
    func noRequestNoFocus() {
        #expect(!NewRowFocus().take(row: 0))
    }
}
