/// What the button that leaves the editor offers.
enum EditorExit: Equatable {
    /// Leaving drops what is not saved, after asking.
    case cancel
    /// The CV is stored and nothing is unsaved: leaving loses nothing.
    case done
}
