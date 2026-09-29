import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import CVDesignCatalog
import CVDesignCatalogFileStore
import CVRenderingTestSupport

/// Runs `body` with a store directory of its own, removed afterwards (R10: hermetic). The directory is not created.
func inTemporaryStore(_ body: (URL) async throws -> Void) async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("design-store-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: url) }
    try await body(url)
}

extension URL {
    var index: URL { appendingPathComponent("index.json") }
    func file(_ id: String, generation: Int = 1) -> URL { appendingPathComponent("Designs/\(id).\(generation).mcvt") }
    var designFiles: Set<String> { Set((try? FileManager.default.contentsOfDirectory(atPath: appendingPathComponent("Designs").path)) ?? []) }
}

@Suite("R10 · design store contract")
struct DesignStoreContractTests {
    @Test("the in-memory store passes") func inMemory() async throws { try await DesignStoreContract.verify(InMemoryDesignStore()) }
    @Test("the file store passes") func file() async throws {
        try await inTemporaryStore { dir in try await DesignStoreContract.verify(FileDesignStore(directory: dir)) }
    }
}

@Suite("FileDesignStore (#75)")
struct FileDesignStoreTests {
    @Test("designs outlive the instance that saved them")
    func persists() async throws {
        try await inTemporaryStore { dir in
            let clean = try DesignStoreContract.design(id: "clean", preview: true)
            try await FileDesignStore(directory: dir).save(clean)
            let reopened = FileDesignStore(directory: dir)
            #expect(try await reopened.design(id: "clean") == clean)
            #expect(try await reopened.installedDesigns() == [clean.manifest])
        }
    }

    @Test("a store that does not exist yet is empty, and reading it creates nothing")
    func missingDirectory() async throws {
        try await inTemporaryStore { dir async throws in
            let store = FileDesignStore(directory: dir)
            #expect(try await store.installedDesigns().isEmpty)
            #expect(try await store.design(id: "clean") == nil)
            #expect(!FileManager.default.fileExists(atPath: dir.path))
        }
    }

    @Test("two instances on one directory lose no index update")
    func twoInstances() async throws {
        try await inTemporaryStore { dir in
            let stores = [FileDesignStore(directory: dir), FileDesignStore(directory: dir)]
            let designs = try (0..<40).map { try DesignStoreContract.design(id: "design-\($0)") }
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (n, design) in designs.enumerated() { group.addTask { try await stores[n % 2].save(design) } }
                try await group.waitForAll()
            }
            let expected = designs.map(\.manifest).sorted { $0.id < $1.id }
            #expect(try await FileDesignStore(directory: dir).installedDesigns() == expected)
        }
    }

    @Test("a design file changed on disk is validated again: rejected, never returned and never reported as absent",
          arguments: [(".cv{display:none}", "clean"), (".cv-name{color:var(--color-primary)}", "other")])
    func tampered(css: String, manifestID: String) async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            try DesignStoreContract.package(id: manifestID, css: css).write(to: dir.file("clean"))
            let error = await #expect(throws: FileDesignStoreError.self) { _ = try await store.design(id: "clean") }
            guard case .designRejected(id: "clean", _)? = error else { Issue.record("\(String(describing: error))"); return }
        }
    }

    @Test("a listed design whose file is missing is unreadable, not absent")
    func missingFile() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            try FileManager.default.removeItem(at: dir.file("clean"))
            await #expect(throws: FileDesignStoreError.designUnreadable(id: "clean")) { _ = try await store.design(id: "clean") }
        }
    }

    @Test("a design file that is a symbolic link is not followed")
    func symbolicLink() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            let elsewhere = dir.appendingPathComponent("elsewhere.mcvt")
            try DesignStoreContract.package(id: "clean").write(to: elsewhere)
            try FileManager.default.removeItem(at: dir.file("clean"))
            try FileManager.default.createSymbolicLink(at: dir.file("clean"), withDestinationURL: elsewhere)
            await #expect(throws: FileDesignStoreError.designUnreadable(id: "clean")) { _ = try await store.design(id: "clean") }
        }
    }

    @Test("an oversized design file is reported without being read")
    func oversized() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir, validator: DesignPackageValidator(maxBytes: 4096))
            try await store.save(DesignStoreContract.design(id: "clean"))
            try Data(repeating: 0x20, count: 4097).write(to: dir.file("clean"))
            await #expect(throws: FileDesignStoreError.designTooLarge(id: "clean", bytes: 4097)) { _ = try await store.design(id: "clean") }
        }
    }

    @Test("an index from a newer version or a corrupt one is reported and left untouched, even by a save",
          arguments: [(#"{"schemaVersion":2,"designs":[],"themes":[]}"#, FileDesignStoreError.indexFromNewerVersion(2)),
                      ("not JSON", .indexCorrupt("no schema version")),
                      (#"{"schemaVersion":1,"designs":[{"generation":1,"manifest":{"id":"../x","name":"","version":"1","description":"","markupContract":1}}]}"#,
                       .indexCorrupt("entries")),
                      (#"{"schemaVersion":1,"designs":[{"generation":0,"manifest":{"id":"x","name":"","version":"1","description":"","markupContract":1}}]}"#,
                       .indexCorrupt("entries")),
                      (#"{"schemaVersion":1}"#, .indexCorrupt("not an index"))] as [(String, FileDesignStoreError)])
    func badIndex(contents: String, error: FileDesignStoreError) async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            try Data(contents.utf8).write(to: dir.index)
            await #expect(throws: error) { _ = try await store.installedDesigns() }
            await #expect(throws: error) { _ = try await store.design(id: "clean") }
            await #expect(throws: error) { try await store.save(DesignStoreContract.design(id: "bold")) }
            #expect(try Data(contentsOf: dir.index) == Data(contents.utf8))
            #expect(!FileManager.default.fileExists(atPath: dir.file("bold").path))
        }
    }

    @Test("an index that is a symbolic link is not followed")
    func linkedIndex() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            let elsewhere = dir.appendingPathComponent("elsewhere.json")
            try FileManager.default.moveItem(at: dir.index, to: elsewhere)
            try FileManager.default.createSymbolicLink(at: dir.index, withDestinationURL: elsewhere)
            await #expect(throws: FileDesignStoreError.indexUnreadable) { _ = try await store.installedDesigns() }
        }
    }

    @Test("nothing is written that the store could not read back")
    func wouldNotReadBack() async throws {
        try await inTemporaryStore { dir async throws in
            let store = FileDesignStore(directory: dir, validator: DesignPackageValidator(maxBytes: 64))
            await #expect(throws: FileDesignStoreError.wouldNotReadBack(id: "clean")) {
                try await store.save(DesignStoreContract.design(id: "clean", preview: true))
            }
            #expect(try await store.installedDesigns().isEmpty)
            #expect(!FileManager.default.fileExists(atPath: dir.file("clean").path))
        }
    }

    @Test("a replace writes a new generation; superseded files go at the next save, other files stay")
    func generations() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let cleanV2 = try DesignStoreContract.design(id: "clean", version: "2.0.0")
            try await store.save(DesignStoreContract.design(id: "clean"))
            try await store.save(cleanV2)
            try Data("mine".utf8).write(to: dir.appendingPathComponent("Designs/notes.txt"))
            try await store.save(DesignStoreContract.design(id: "bold"))
            #expect(dir.designFiles == ["bold.1.mcvt", "clean.2.mcvt", "notes.txt"])
            #expect(try await store.design(id: "clean") == cleanV2)
        }
    }

    @Test("a replace whose index cannot be written keeps the previous version", .enabled(if: geteuid() != 0, "root ignores permissions"))
    func failedReplace() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)   // Designs/ stays writable
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path) }
            await #expect(throws: FileDesignStoreError.writeFailed(id: "clean")) {
                try await store.save(DesignStoreContract.design(id: "clean", version: "2.0.0"))
            }
            #expect(try await store.design(id: "clean") == clean)
            #expect(try await store.installedDesigns() == [clean.manifest])
        }
    }

    @Test("a named pipe in place of a file is unreadable, and never blocks the store", .timeLimit(.minutes(1)))
    func namedPipe() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            try FileManager.default.removeItem(at: dir.file("clean"))
            #expect(mkfifo(dir.file("clean").path, 0o600) == 0)
            await #expect(throws: FileDesignStoreError.designUnreadable(id: "clean")) { _ = try await store.design(id: "clean") }
            try FileManager.default.removeItem(at: dir.index)
            #expect(mkfifo(dir.index.path, 0o600) == 0)
            await #expect(throws: FileDesignStoreError.indexUnreadable) { _ = try await store.installedDesigns() }
        }
    }

    @Test("a Designs folder that is a link makes the store unavailable, and nothing is written through it")
    func linkedDesignsFolder() async throws {
        try await inTemporaryStore { dir in
            let elsewhere = dir.appendingPathComponent("elsewhere", isDirectory: true)
            try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("Designs"), withDestinationURL: elsewhere)
            let store = FileDesignStore(directory: dir)
            await #expect(throws: FileDesignStoreError.storeUnavailable) { try await store.save(DesignStoreContract.design(id: "clean")) }
            await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.design(id: "clean") }
            #expect(try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty)
            #expect(!FileManager.default.fileExists(atPath: dir.index.path))
        }
    }

    @Test("a store that exists but cannot be reached is unavailable, never empty", .enabled(if: geteuid() != 0, "root ignores permissions"))
    func unreachable() async throws {
        try await inTemporaryStore { parent in
            let dir = parent.appendingPathComponent("store", isDirectory: true)
            try await FileDesignStore(directory: dir).save(DesignStoreContract.design(id: "clean"))
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: parent.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path) }
            let store = FileDesignStore(directory: dir)
            await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.installedDesigns() }
            await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.design(id: "clean") }
        }
    }

    @Test("a store path that is a file is unavailable, never empty")
    func notADirectory() async throws {
        try await inTemporaryStore { parent in
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let file = parent.appendingPathComponent("store")
            try Data("x".utf8).write(to: file)
            let store = FileDesignStore(directory: file)
            await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.installedDesigns() }
            await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await FileDesignStore(directory: file.appendingPathComponent("inner")).installedDesigns() }
        }
    }

    @Test("a store reached through a link whose target is gone is unavailable, never empty")
    func danglingLink() async throws {
        try await inTemporaryStore { parent in
            let target = parent.appendingPathComponent("target", isDirectory: true), link = parent.appendingPathComponent("store")
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
            try await FileDesignStore(directory: link).save(DesignStoreContract.design(id: "clean"))
            try FileManager.default.removeItem(at: target)
            for dir in [link, link.appendingPathComponent("inner")] {   // the link itself, or an ancestor
                let store = FileDesignStore(directory: dir)
                await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.installedDesigns() }
                await #expect(throws: FileDesignStoreError.storeUnavailable) { _ = try await store.design(id: "clean") }
                await #expect(throws: FileDesignStoreError.storeUnavailable) { try await store.save(DesignStoreContract.design(id: "bold")) }
            }
            #expect(!FileManager.default.fileExists(atPath: target.path))
        }
    }
}
