/// Reading the repository: the one place the checks touch files, so that a test can supply a file system a real
/// disk cannot be made to be. Paths are relative to the repository root, with `/` separators, and `""` is the root.
protocol RepositoryFiles: Sendable {
    /// The names in a directory, or nil if there is no directory there.
    func names(inDirectory path: String) throws(DocsCheckError) -> [String]?

    /// What is at a path that was read from a listing, so its case is exact. Nil if nothing is there.
    func kind(atExactPath path: String) -> RepositoryTree.Kind?

    func isSymbolicLink(_ path: String) -> Bool

    func text(ofFile path: String) throws(DocsCheckError) -> String
}
