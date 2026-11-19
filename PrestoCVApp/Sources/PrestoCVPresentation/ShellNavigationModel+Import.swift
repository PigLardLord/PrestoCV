extension ShellNavigationModel {

    /// The import's status changed. The view forwards every change and decides nothing: a ready import hands its draft
    /// to the editor (`open(_:)`), and any other status leaves the import on the screen (R5). Only a ready import holds
    /// a draft.
    public func importStatusChanged() {
        guard let imported = importer?.result else { return }
        open(imported)
    }

    /// Opens the draft of an import in the editor, through the path of any draft: the import is told it was opened, so
    /// its draft is not opened again, and goes. Like any draft, it is not in the list, so a change of the list leaves
    /// it open, and the editor stores it when the person leaves it, edited or not (decision 6 of #404).
    func open(_ imported: ImportedDraft) {
        importer?.opened()
        open(imported.start)
    }
}
