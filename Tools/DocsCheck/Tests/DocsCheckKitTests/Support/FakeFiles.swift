@testable import DocsCheckKit

/// A repository held in memory, for what a real disk cannot be made to do on every host: a case-insensitive file
/// system, and files and directories that cannot be read.
struct FakeFiles: RepositoryFiles {
    var contents: [String: String]
    /// Paths that cannot be read, whether files or directories.
    var unreadable: Set<String> = []
    /// Answers `kind(atExactPath:)` ignoring case, as a default macOS volume does.
    var caseInsensitive = false

    private var directories: Set<String> {
        var directories: Set<String> = [""]
        for path in contents.keys {
            var parts = path.split(separator: "/").map(String.init)
            parts.removeLast()
            for count in 0..<parts.count { directories.insert(parts[0...count].joined(separator: "/")) }
        }
        return directories
    }

    func names(inDirectory path: String) throws(DocsCheckError) -> [String]? {
        guard directories.contains(path) else { return nil }
        if unreadable.contains(path) { throw path.isEmpty ? .unreadableRoot(path: "/fake") : .unreadableDirectory(path: path) }
        let prefix = path.isEmpty ? "" : path + "/"
        var names: Set<String> = []
        for entry in contents.keys.sorted() + directories.sorted() where entry.hasPrefix(prefix) && entry != path {
            if let first = entry.dropFirst(prefix.count).split(separator: "/").first { names.insert(String(first)) }
        }
        return names.sorted()
    }

    func kind(atExactPath path: String) -> RepositoryTree.Kind? {
        func matches(_ other: String) -> Bool { caseInsensitive ? other.lowercased() == path.lowercased() : other == path }
        if directories.contains(where: matches) { return .directory }
        return contents.keys.contains(where: matches) ? .file : nil
    }

    func isSymbolicLink(_ path: String) -> Bool { false }

    func text(ofFile path: String) throws(DocsCheckError) -> String {
        guard let text = contents[path], !unreadable.contains(path) else { throw .unreadableFile(path: path) }
        return text
    }
}
