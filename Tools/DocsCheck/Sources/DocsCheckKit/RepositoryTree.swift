/// A read-only view of the repository. Paths are relative to the root, with `/` separators.
struct RepositoryTree {
    let files: any RepositoryFiles

    enum Kind: Equatable {
        case file
        case directory
    }

    /// Directories that are never read: git's own data and build products, which hold copies of other packages' READMEs.
    private static let skippedDirectories: Set<String> = [".git", ".build"]

    // MARK: Documents

    /// The Markdown files the checks read: everything under `docs/`, every `README.md`, and `AGENTS.md`. Sorted.
    func documentPaths() throws(DocsCheckError) -> [String] {
        try markdownFiles(in: "").filter { path in
            path == "AGENTS.md" || path.hasPrefix("docs/") || path == "README.md" || path.hasSuffix("/README.md")
        }
    }

    private func markdownFiles(in directory: String) throws(DocsCheckError) -> [String] {
        var paths: [String] = []
        for name in try files.names(inDirectory: directory)?.sorted() ?? [] {
            let path = directory.isEmpty ? name : directory + "/" + name
            switch files.kind(atExactPath: path) {
            case .directory where !Self.skippedDirectories.contains(name) && !files.isSymbolicLink(path):
                paths += try markdownFiles(in: path)
            case .file where name.hasSuffix(".md"):
                paths.append(path)
            default:
                break
            }
        }
        return paths
    }

    func text(of path: String) throws(DocsCheckError) -> String {
        try files.text(ofFile: path)
    }

    // MARK: Existence

    /// What `path` is, matching every component with its exact case, as GitHub does: each name must be in the
    /// listing of its directory, whatever the file system would accept. Nil if it does not exist.
    func kind(of path: String) throws(DocsCheckError) -> Kind? {
        var directory = ""
        for name in path.split(separator: "/").map(String.init) {
            guard let names = try files.names(inDirectory: directory), names.contains(where: { $0.unicodeScalars.elementsEqual(name.unicodeScalars) }) else {
                return nil
            }
            directory = directory.isEmpty ? name : directory + "/" + name
        }
        return directory.isEmpty ? .directory : files.kind(atExactPath: directory)
    }

    /// The names at the top of the repository.
    func topLevelEntries() throws(DocsCheckError) -> Set<String> {
        Set(try files.names(inDirectory: "") ?? [])
    }
}
