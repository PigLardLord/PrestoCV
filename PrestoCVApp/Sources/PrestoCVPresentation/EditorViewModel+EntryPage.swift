/// A row open on a page of its own: its section and its id.
public struct EditorEntry: Hashable, Sendable {
    public let section: EditorSection
    public let row: RowID
}

extension EditorSection {
    /// Whether a row of the section opens on a page of its own where the screen is narrow: a row with several fields does.
    /// A skill and an interest, a field or two each, stay in the form.
    var opensOnAPage: Bool {
        switch self {
        case .experiences, .education, .languages, .certifications, .profiles: true
        case .skills, .interests: false
        }
    }
}

extension EditorContent {
    /// Whether the row of `entry` is in its section and its id on no other row.
    func holdsOnce(_ entry: EditorEntry) -> Bool {
        rowCount(withID: entry.row) == 1 && hasRow(in: entry.section, id: entry.row)
    }
}

extension EditorViewModel {

    /// The view tells the width of the screen, before the form shows and whenever it changes. A screen that widens shows
    /// every row in place again, so the open page closes.
    public func layoutChanged(isNarrow: Bool) {
        self.isNarrow = isNarrow
        if !isNarrow { openedEntry = nil }
    }

    /// Whether the rows of `section` show as a line that opens a page of their own, rather than with their fields in the
    /// form.
    public func showsOnAPage(_ section: EditorSection) -> Bool {
        isNarrow && section.opensOnAPage
    }

    /// Whether the form says under the section's rows that a touch and hold moves one: where they open on a page, so that
    /// a tap opens it, and there are two or more to put in order.
    public func showsMoveHint(in section: EditorSection) -> Bool {
        showsOnAPage(section) && form.rowIDs(in: section).count > 1
    }

    /// Opens the page of the row of `section` with `id`. A row that shows in place, or is not in the section, opens none.
    public func openEntry(in section: EditorSection, id: RowID) {
        let entry = EditorEntry(section: section, row: id)
        guard showsOnAPage(section), form.holdsOnce(entry) else { return }
        openedEntry = entry
    }

    /// The person went back to the form.
    public func closeEntry() {
        openedEntry = nil
    }

    /// Whether the removal of the row with `id` waits for the person's answer on its page (`onItsPage`) or in the form:
    /// on the page while it is open, so that one question shows, where the person asked.
    public func asksToRemove(row id: RowID, onItsPage: Bool) -> Bool {
        guard pendingRemoval?.row == id else { return false }
        return (openedEntry?.row == id) == onItsPage
    }
}
