import Foundation
import Testing
@testable import DocsCheckKit

/// The error a run throws, or nil if it completes.
private func thrown<Value>(by body: () throws(DocsCheckError) -> Value) -> DocsCheckError? {
    do { _ = try body() } catch { return error }
    return nil
}

@Suite("A check that cannot read is an error, never a pass")
struct DocsCheckErrorTests {
    private func failure(of fake: FakeFiles, planned: URL? = nil) -> DocsCheckError? {
        thrown { () throws(DocsCheckError) in try DocumentationChecker(files: fake, rootPath: "/fake", plannedFile: planned).run() }
    }

    @Test("a root that is not a directory cannot be read")
    func unreadableRoot() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("docscheck-missing-" + UUID().uuidString)
        let error = thrown { () throws(DocsCheckError) in try DocumentationChecker(root: missing).run() }
        #expect(error == .unreadableRoot(path: missing.path))
        #expect(error?.description == "cannot read \(missing.path)")
    }

    @Test("a root that cannot be listed cannot be read")
    func unlistableRoot() {
        #expect(failure(of: FakeFiles(contents: ["README.md": "x"], unreadable: [""])) == .unreadableRoot(path: "/fake"))
    }

    @Test("a directory that cannot be listed is named by its path")
    func unreadableDirectory() {
        let error = failure(of: FakeFiles(contents: ["README.md": "x", "docs/a.md": "x"], unreadable: ["docs"]))
        #expect(error == .unreadableDirectory(path: "docs"))
        #expect(error?.description == "cannot read docs")
    }

    @Test("a document that cannot be read is named by its path")
    func unreadableFile() {
        let error = failure(of: FakeFiles(contents: ["README.md": "x", "docs/a.md": "x"], unreadable: ["docs/a.md"]))
        #expect(error == .unreadableFile(path: "docs/a.md"))
        #expect(error?.description == "cannot read docs/a.md")
    }

    @Test("a planned file that cannot be read is named relative to the root")
    func plannedFileUnreadable() throws {
        try withRepository(["README.md": "x"]) { root in
            let error = thrown { () throws(DocsCheckError) in
                try DocumentationChecker(root: root, plannedFile: root.appendingPathComponent("missing.json")).run()
            }
            #expect(error == .plannedFileUnreadable(path: "missing.json"))
            #expect(error?.description == "cannot read missing.json")
        }
    }

    @Test("a planned file outside the root is named by its file name")
    func plannedFileOutsideTheRoot() {
        let error = failure(of: FakeFiles(contents: ["README.md": "x"]), planned: URL(fileURLWithPath: "/nowhere/at/all/planned.json"))
        #expect(error == .plannedFileUnreadable(path: "planned.json"))
    }
}
