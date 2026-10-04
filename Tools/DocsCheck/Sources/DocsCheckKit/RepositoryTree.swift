import Foundation

/// A read-only view of the repository on disk. Paths are relative to the root, with `/` separators.
struct RepositoryTree {
    let root: URL

    enum Kind: Equatable {
        case file
        case directory
    }

    /// Directories that are never read: git's own data and build products, which hold copies of other packages' READMEs.
    private static let skippedDirectories: Set<String> = [".git", ".build"]

    // MARK: Documents

    /// The Markdown files the checks read: everything under `docs/`, every `README.md`, and `AGENTS.md`. Sorted.
    func documentPaths() throws -> [String] {
        try markdownFiles(in: "").filter { path in
            path == "AGENTS.md" || path.hasPrefix("docs/") || path == "README.md" || path.hasSuffix("/README.md")
        }
    }

    private func markdownFiles(in directory: String) throws -> [String] {
        var paths: [String] = []
        for name in try FileManager.default.contentsOfDirectory(atPath: absolutePath(directory)).sorted() {
            let path = directory.isEmpty ? name : directory + "/" + name
            switch kind(atExactPath: path) {
            case .directory where !Self.skippedDirectories.contains(name) && !isSymbolicLink(path):
                paths += try markdownFiles(in: path)
            case .file where name.hasSuffix(".md"):
                paths.append(path)
            default:
                break
            }
        }
        return paths
    }

    func text(of path: String) throws -> String {
        String(decoding: try Data(contentsOf: URL(fileURLWithPath: absolutePath(path))), as: UTF8.self)
    }

    // MARK: Existence

    /// What `path` is, matching every component with its exact case, as GitHub does. Nil if it does not exist.
    func kind(of path: String) -> Kind? {
        var directory = ""
        for name in path.split(separator: "/").map(String.init) {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: absolutePath(directory)), names.contains(name) else { return nil }
            directory = directory.isEmpty ? name : directory + "/" + name
        }
        return kind(atExactPath: directory)
    }

    /// The names at the top of the repository.
    func topLevelEntries() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
    }

    private func kind(atExactPath path: String) -> Kind? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absolutePath(path), isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue ? .directory : .file
    }

    private func isSymbolicLink(_ path: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: absolutePath(path))[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    private func absolutePath(_ path: String) -> String {
        path.isEmpty ? root.path : root.appendingPathComponent(path).path
    }
}
