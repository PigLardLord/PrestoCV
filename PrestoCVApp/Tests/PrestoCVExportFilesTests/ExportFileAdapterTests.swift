import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVExportFiles
import PrestoCVWorkflowPorts
import Testing

@Suite("The file adapter of the export's share")
struct ExportFileAdapterTests {
    private static let pdf = Data("%PDF-1.7 Mara Ellison".utf8)
    private static let name = "Mara Ellison – CV.pdf"

    // MARK: Writing and removing

    @Test("a write puts the PDF under its name, in a folder of its own under the root")
    func writePutsThePDFUnderItsName() async throws {
        let world = World()
        defer { world.remove() }

        let file = try await world.adapter.write(Self.pdf, named: Self.name)

        #expect(file.url.lastPathComponent == Self.name)
        #expect(file.url.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL.path
            == world.shares.standardizedFileURL.path)
        #expect(try Data(contentsOf: file.url) == Self.pdf)
        #expect(try world.names(in: file.url.deletingLastPathComponent()) == [Self.name])
        #expect(world.logger.entries.isEmpty)
    }

    @Test("two writes of one PDF give two files, in two folders")
    func twoWritesGiveTwoFolders() async throws {
        let world = World()
        defer { world.remove() }

        let first = try await world.adapter.write(Self.pdf, named: Self.name)
        let second = try await world.adapter.write(Self.pdf, named: Self.name)

        #expect(first.id != second.id)
        #expect(first.url.deletingLastPathComponent() != second.url.deletingLastPathComponent())
        #expect(try world.names(in: world.shares).count == 2)
        #expect(try Data(contentsOf: first.url) == Self.pdf)
        #expect(try Data(contentsOf: second.url) == Self.pdf)
    }

    @Test("a remove deletes the file and its folder, and leaves the other share's file")
    func removeDeletesTheFolder() async throws {
        let world = World()
        defer { world.remove() }
        let first = try await world.adapter.write(Self.pdf, named: Self.name)
        let second = try await world.adapter.write(Self.pdf, named: Self.name)

        world.adapter.remove(first)

        #expect(!FileManager.default.fileExists(atPath: first.url.deletingLastPathComponent().path))
        #expect(try Data(contentsOf: second.url) == Self.pdf)
        #expect(world.logger.entries.isEmpty)
    }

    @Test("a second remove, and the remove of a file never written, do nothing")
    func secondRemoveDoesNothing() async throws {
        let world = World()
        defer { world.remove() }
        let first = try await world.adapter.write(Self.pdf, named: Self.name)
        let second = try await world.adapter.write(Self.pdf, named: Self.name)
        world.adapter.remove(first)

        world.adapter.remove(first)
        world.adapter.remove(SharedFile(id: 99, url: second.url))

        #expect(try Data(contentsOf: second.url) == Self.pdf)
        #expect(world.logger.entries.isEmpty)
    }

    @Test("the remove of a file whose folder is already gone logs nothing")
    func removeOfAGoneFolderLogsNothing() async throws {
        let world = World()
        defer { world.remove() }
        let file = try await world.adapter.write(Self.pdf, named: Self.name)
        try FileManager.default.removeItem(at: file.url.deletingLastPathComponent())

        world.adapter.remove(file)

        #expect(world.logger.entries.isEmpty)
    }

    @Test("a folder that cannot be removed is logged by the kind of failure, and nothing is thrown",
          .enabled(if: geteuid() != 0, "the superuser removes any file"))
    func aFailedRemoveIsLogged() async throws {
        let world = World()
        defer { world.remove() }
        let file = try await world.adapter.write(Self.pdf, named: Self.name)
        let folder = file.url.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        defer { world.allowWrites(folder) }

        world.adapter.remove(file)

        let entries = world.logger.entries("export.share.notRemoved")
        #expect(entries.count == 1)
        #expect(entries.first?.value("of") == .token("share"))
        #expect(entries.first?.value("error") == .error(type: "ExportFileError", code: "noPermission"))
        #expect(FileManager.default.fileExists(atPath: file.url.path))
    }

    // MARK: Names

    @Test("a name that is not one file name is refused, logged, and nothing is written",
          arguments: ["", ".", "..", "a/b.pdf", "../cv.pdf", "cv\0.pdf", String(repeating: "a", count: 256)])
    func notANameIsRefused(_ name: String) async throws {
        let world = World()
        defer { world.remove() }

        await #expect(throws: ExportFileError.notAName) {
            _ = try await world.adapter.write(Self.pdf, named: name)
        }

        #expect(world.logger.entries("export.share.notWritten").map { $0.value("error") }
            == [.error(type: "ExportFileError", code: "notAName")])
        #expect(!FileManager.default.fileExists(atPath: world.shares.path))
    }

    @Test("the longest name the domain makes, 200 bytes of two-byte letters, is written whole")
    func theLongestDomainNameIsWritten() async throws {
        let world = World()
        defer { world.remove() }
        let name = String(repeating: "Ž", count: 98) + ".pdf"
        #expect(name.utf8.count == 200)

        let file = try await world.adapter.write(Self.pdf, named: name)

        #expect(file.url.lastPathComponent == name)
        #expect(try Data(contentsOf: file.url) == Self.pdf)
    }

    // MARK: Leftovers

    @Test("making the adapter removes what an earlier launch left under the root, and its writes remove nothing")
    func leftoversGoWhenTheAdapterIsMade() async throws {
        let world = World()
        defer { world.remove() }
        let old = world.shares.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Self.pdf.write(to: old.appendingPathComponent(Self.name))
        try Self.pdf.write(to: world.shares.appendingPathComponent("stray.pdf"))

        let adapter = world.newAdapter()

        #expect(try world.names(in: world.shares).isEmpty)

        let first = try await adapter.write(Self.pdf, named: Self.name)
        let later = world.shares.appendingPathComponent("later", isDirectory: true)
        try FileManager.default.createDirectory(at: later, withIntermediateDirectories: true)
        let second = try await adapter.write(Self.pdf, named: Self.name)

        #expect(FileManager.default.fileExists(atPath: later.path))
        #expect(try Data(contentsOf: first.url) == Self.pdf)
        #expect(try Data(contentsOf: second.url) == Self.pdf)
        #expect(world.logger.entries.isEmpty)
    }

    @Test("writes that start together all keep their files, each in a folder of its own")
    func concurrentWritesKeepTheirFiles() async throws {
        let world = World()
        defer { world.remove() }
        try FileManager.default.createDirectory(at: world.shares.appendingPathComponent("old"), withIntermediateDirectories: true)
        let adapter = world.newAdapter()

        let files = try await withThrowingTaskGroup(of: SharedFile.self) { group in
            for _ in 0..<16 {
                group.addTask { try await adapter.write(Self.pdf, named: Self.name) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        #expect(Set(files.map(\.id)).count == 16)
        for file in files {
            #expect(try Data(contentsOf: file.url) == Self.pdf)
        }
        #expect(try world.names(in: world.shares).count == 16)
    }

    // MARK: Failures

    @Test("a write that fails is logged by the kind of failure, thrown, and leaves no folder")
    func aFailedWriteLeavesNothing() async throws {
        let world = World()
        defer { world.remove() }
        // The root is a file, so no folder can be made in it
        try FileManager.default.createDirectory(at: world.scratch, withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: world.shares)

        await #expect {
            _ = try await world.adapter.write(Self.pdf, named: Self.name)
        } throws: { error in
            guard case .system = error as? ExportFileError else { return false }
            return true
        }

        let written = world.logger.entries("export.share.notWritten")
        #expect(written.count == 1)
        if case .error(let type, let code) = written.first?.value("error") {
            #expect(type == "ExportFileError")
            #expect(["noSpace", "noPermission", "readOnly", "notFound", "other"].contains(code))
        } else {
            Issue.record("the line names no error: \(written)")
        }
        // The folder that was never made is not looked for; the adapter was made before the root, which then held nothing
        #expect(world.logger.entries("export.share.notRemoved").isEmpty)
        #expect(try Data(contentsOf: world.shares) == Data("not a folder".utf8))
    }

    @Test("a failure of the file system is named by its kind",
          arguments: [
            (CocoaError(.fileWriteOutOfSpace), ExportFileError.system(.noSpace), "noSpace"),
            (CocoaError(.fileWriteNoPermission), .system(.noPermission), "noPermission"),
            (CocoaError(.fileReadNoPermission), .system(.noPermission), "noPermission"),
            (CocoaError(.fileWriteVolumeReadOnly), .system(.readOnly), "readOnly"),
            (CocoaError(.fileNoSuchFile), .system(.notFound), "notFound"),
            (CocoaError(.fileReadNoSuchFile), .system(.notFound), "notFound"),
            (CocoaError(.fileWriteUnknown), .system(.other), "other"),
          ] as [(CocoaError, ExportFileError, String)])
    func failuresAreNamedByKind(_ error: CocoaError, _ expected: ExportFileError, _ code: String) {
        let failure = ExportFileError(error)

        #expect(failure == expected)
        #expect(failure.logCode.description == code)
    }

    @Test("an error that is not the file system's is other, and one of the adapter's stays as it is")
    func otherErrors() {
        struct Unknown: Error {}

        #expect(ExportFileError(Unknown()) == .system(.other))
        #expect(ExportFileError(ExportFileError.notAName) == .notAName)
        #expect(ExportFileError.notAName.logCode.description == "notAName")
    }
}

/// An adapter whose root lies in a scratch folder of its own, with a logger to read.
private struct World {
    let scratch: URL
    let shares: URL
    let logger = RecordingLogger()
    let adapter: ExportFileAdapter

    /// The adapter is made before the root exists, as at the first launch.
    init() {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        shares = scratch.appendingPathComponent("ExportShare", isDirectory: true)
        adapter = ExportFileAdapter(root: shares, logger: logger)
    }

    /// Another adapter over the same root, as at a later launch.
    func newAdapter() -> ExportFileAdapter {
        ExportFileAdapter(root: shares, logger: logger)
    }

    func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    func allowWrites(_ folder: URL) {
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        } catch {
            Issue.record("the folder stays read-only: \(error)")
        }
    }

    func remove() {
        guard FileManager.default.fileExists(atPath: scratch.path) else { return }
        do {
            try FileManager.default.removeItem(at: scratch)
        } catch {
            Issue.record("the scratch folder stays: \(error)")
        }
    }
}
