extension EditorViewModel {

    /// The CV as the form shows it now, stored or not, with the look and the language chosen last, for the export sheet;
    /// nil until the CV is open. It reads no store and leaves the save status alone.
    public func exportSnapshot() -> ExportSnapshot? {
        held.map { ExportSnapshot(cv: form.applied(to: $0)) }
    }
}
