extension ShellNavigationModel {

    /// Goes where a way to start leads: a draft opens in the editor and the import shows, each in place of what was
    /// open (R5: the view forwards the destination and decides nothing). No destination changes nothing.
    @discardableResult
    public func start(at destination: StartDestination?) -> LeaveVerdict {
        switch destination {
        case .draft(let draft)?: open(.draft(draft))
        case .importCV?: showImport()
        case nil: .left
        }
    }

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
