import Foundation
@testable import DocsCheckKit

/// The documents every check needs, in a state the checker accepts. A test replaces or removes the ones it is about.
let acceptedBaseline: [String: String] = [
    "AGENTS.md": "# Guidelines\n\n- **Documentation is code.** Documentation changes with the code in the same pull request.",
    ".github/pull_request_template.md": "## Purpose\n\n## Documents updated\n\nWhich documents does this change update?",
    "docs/architecture/adr/README.md": "# ADRs\n\n| # | Decision | Status |\n|---|---|---|\n| [0001](0001-first.md) | First | Accepted |",
    "docs/architecture/adr/0001-first.md": "# 0001. First\n\n- **Status:** Accepted\n",
]

/// A repository built from a dictionary of paths and contents in a temporary directory, removed when the body returns.
@discardableResult
func withRepository<Result>(_ files: [String: String], directories: [String] = [], _ body: (URL) throws -> Result) throws -> Result {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("docscheck-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for directory in directories {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(directory), withIntermediateDirectories: true)
    }
    for (path, contents) in files {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }
    return try body(root)
}

/// The findings of a run over the accepted baseline plus `files` (which replace the baseline's files of the same path),
/// minus the paths in `removing`, as `file:line code` strings in the order the report prints them.
func findings(in files: [String: String], removing: [String] = [], directories: [String] = [], planned: String? = nil, knownTopLevel: [String]? = nil) throws -> [String] {
    var repository = acceptedBaseline.merging(files) { _, test in test }
    for path in removing { repository[path] = nil }
    return try withRepository(repository, directories: directories) { root in
        var plannedFile: URL?
        if let planned {
            plannedFile = root.appendingPathComponent("planned.json")
            try Data(planned.utf8).write(to: root.appendingPathComponent("planned.json"))
        }
        var knownFiles: [URL] = []
        if let knownTopLevel {
            knownFiles = [root.appendingPathComponent("known-top-level.txt")]
            try Data(knownTopLevel.joined(separator: "\n").utf8).write(to: knownFiles[0])
        }
        let report = try DocumentationChecker(root: root, plannedFile: plannedFile, knownTopLevelFiles: knownFiles).run()
        return report.findings.map { "\($0.file):\($0.line) \($0.code.rawValue)" }
    }
}
