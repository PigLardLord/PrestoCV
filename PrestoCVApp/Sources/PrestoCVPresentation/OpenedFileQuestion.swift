/// What the shell asks when a PDF is opened in the app while the open CV's text cannot be stored as it is
/// (`ShellNavigationModel.receive(file:)`): a code, which the view puts in words (R13).
public enum OpenedFileQuestion: Hashable, Sendable {
    /// Keep editing, and the file is let go, or discard the edits the store does not have and import the file. The
    /// status is why the text cannot be stored, for the question to say.
    case keepEditingOrDiscard(SaveStatus)
}
