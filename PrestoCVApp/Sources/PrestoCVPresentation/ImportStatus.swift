// The codes of the import screen (#396): where the import stands, why it gave no draft, and where its text came from.
// Codes, not sentences: the view chooses the words (R13). Contents and allowed imports: docs/architecture/modules.md.

/// Where the import stands.
public enum ImportStatus: Hashable, Sendable {
    case idle
    case importing
    /// The import gave no draft; the text typed is kept.
    case failed(ImportProblem)
    /// The draft is in `ImportViewModel.result`, until the editor opened it.
    case ready
}

/// Why an import gave no draft: one for each reason the import port gives. A cancelled import is none of them.
public enum ImportProblem: Hashable, Sendable, CaseIterable {
    /// No text at all.
    case empty
    case tooLarge
    case tooManyPages
    /// A PDF that needs a password.
    case encrypted
    /// The text or the PDF cannot be read.
    case unreadable
    /// A PDF without a text layer, such as a scan: the person can paste its text instead.
    case noText
    /// The file the person chose could not be read.
    case fileNotRead
}

/// Where the text of an import came from: typed or pasted, or a PDF, from a file or the clipboard.
public enum ImportSource: Hashable, Sendable {
    case pasted
    case file
}
