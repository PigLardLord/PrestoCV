/// The row of a section the person asked to remove, named by its id, which waits for the confirmation.
public struct RowRemoval: Hashable, Sendable {
    public let section: EditorSection
    public let row: RowID
}

extension EditorViewModel {

    /// Adds an empty row at the end of the section. It is an edit like typing: the autosave stores the CV with it.
    public func addRow(to section: EditorSection) {
        var changed = form
        changed.addRow(to: section, id: rowIDs.make())
        edit(changed)
    }

    /// Asks to remove the row of the section with `id`. A row with nothing in it goes at once; any other waits for
    /// `confirmRemoval()`, and `cancelRemoval()` keeps it. A row that is not there asks for nothing.
    public func removeRow(in section: EditorSection, id: RowID) {
        guard form.hasRow(in: section, id: id) else { return }
        let request = RowRemoval(section: section, row: id)
        if form.rowIsBlank(in: section, id: id) {
            pendingRemoval = nil
            remove(request)
        } else {
            pendingRemoval = request
        }
    }

    /// Removes the row last asked for, if it is still in its section. Without a request, or if the row went meanwhile
    /// (another form took its place, or the view replaced the rows), it does nothing.
    public func confirmRemoval() {
        guard let request = pendingRemoval else { return }
        pendingRemoval = nil
        remove(request)
    }

    /// Keeps the row last asked for.
    public func cancelRemoval() {
        pendingRemoval = nil
    }

    private func remove(_ request: RowRemoval) {
        guard form.hasRow(in: request.section, id: request.row) else { return }
        var changed = form
        changed.removeRow(in: request.section, id: request.row)
        edit(changed)
    }
}
