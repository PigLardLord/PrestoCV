/// The row of a section the person asked to remove, which waits for the confirmation.
public struct RowRemoval: Hashable, Sendable {
    public let section: EditorSection
    public let index: Int
}

extension EditorViewModel {

    /// Adds an empty row at the end of the section. It is an edit like typing: the autosave stores the CV with it.
    public func addRow(to section: EditorSection) {
        var changed = form
        changed.addRow(to: section)
        edit(changed)
    }

    /// Asks to remove the row of the section at `index`. A row with nothing in it goes at once; any other waits for
    /// `confirmRemoval()`, and `cancelRemoval()` keeps it. A row that is not there asks for nothing.
    public func removeRow(in section: EditorSection, at index: Int) {
        guard form.hasRow(in: section, at: index) else { return }
        if form.rowIsBlank(in: section, at: index) {
            pendingRemoval = nil
            remove(RowRemoval(section: section, index: index))
        } else {
            pendingRemoval = RowRemoval(section: section, index: index)
        }
    }

    /// Removes the row last asked for. Without a request, or if the row went meanwhile, it does nothing.
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
        var changed = form
        changed.removeRow(in: request.section, at: request.index)
        edit(changed)
    }
}
