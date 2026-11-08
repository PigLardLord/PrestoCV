import DiagnosticLoggingTestSupport
import Foundation
import Testing
@testable import PrestoCVComposition

/// The Apple part of the import's file system: the identity the file system gives.
///
/// The security-scoped access is the system's, and what it answers differs by platform: on a Mac, outside the sandbox,
/// it starts for a file the system gave no scope. The adapter needs no answer in particular, only that each started
/// access is stopped once, which `ImportFileAdapterTests` checks with a spy.
@Suite("The file system of the import on a device")
struct DeviceImportFilesTests {
    /// A folder of its own for one test; the test removes it when it ends.
    private struct Scratch {
        let folder: URL

        init() throws {
            folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("DeviceImportFilesTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        func file(_ name: String, holding text: String) throws -> URL {
            let url = folder.appendingPathComponent(name)
            try Data(text.utf8).write(to: url)
            return url
        }

        func remove() {
            do {
                try FileManager.default.removeItem(at: folder)
            } catch {
                Issue.record(error, "The scratch folder stays: \(folder.path)")
            }
        }
    }

    private let files = DeviceImportFiles(logger: RecordingLogger())

    private func identity(of url: URL) -> String {
        files.identity(ofResolved: files.resolve(url))
    }

    @Test("a file and a symbolic link to it have one identity; another file has another")
    func identity() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("a.pdf", holding: "a")
        let other = try scratch.file("b.pdf", holding: "b")
        let link = scratch.folder.appendingPathComponent("link.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)

        #expect(identity(of: link) == identity(of: file))
        #expect(identity(of: other) != identity(of: file))
    }

    @Test("a hard link is the same file under another name: it has the file's identity")
    func hardLink() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("a.pdf", holding: "a")
        let link = scratch.folder.appendingPathComponent("hard.pdf")
        try FileManager.default.linkItem(at: file, to: link)

        #expect(identity(of: link) == identity(of: file))
    }

    @Test("a file read twice has the same identity, and it is not its path")
    func sameAtEachReading() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("a.pdf", holding: "a")

        let first = identity(of: file)
        #expect(identity(of: file) == first)
        #expect(first != files.resolve(file).path)
    }
}
