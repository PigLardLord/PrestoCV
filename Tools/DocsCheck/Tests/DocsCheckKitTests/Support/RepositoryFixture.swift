import Foundation
@testable import DocsCheckKit

/// A repository built from a dictionary of paths and contents in a temporary directory, removed when the body returns.
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

/// The findings of a run, as `file:line code` strings, in the order the report prints them.
func findings(in files: [String: String], directories: [String] = [], planned: String? = nil) throws -> [String] {
    try withRepository(files, directories: directories) { root in
        var plannedFile: URL?
        if let planned {
            plannedFile = root.appendingPathComponent("planned.json")
            try Data(planned.utf8).write(to: root.appendingPathComponent("planned.json"))
        }
        let report = try DocumentationChecker(root: root, plannedFile: plannedFile).run()
        return report.findings.map { "\($0.file):\($0.line) \($0.code.rawValue)" }
    }
}
