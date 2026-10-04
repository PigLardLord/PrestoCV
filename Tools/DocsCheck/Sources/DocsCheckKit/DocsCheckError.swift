/// Why a run could not read what it has to check. A check that cannot read is an error, never a pass.
public enum DocsCheckError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The repository root, as it was given.
    case unreadableRoot(path: String)
    /// A directory of the repository, by its path relative to the root.
    case unreadableDirectory(path: String)
    /// A file of the repository, by its path relative to the root.
    case unreadableFile(path: String)
    /// The planned-paths file, relative to the root when it is inside it, else by its name.
    case plannedFileUnreadable(path: String)

    public var description: String {
        switch self {
        case .unreadableRoot(let path), .unreadableDirectory(let path), .unreadableFile(let path), .plannedFileUnreadable(let path):
            return "cannot read \(path)"
        }
    }
}
