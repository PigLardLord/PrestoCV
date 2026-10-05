import Testing
import Foundation
import Synchronization
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import CVDesignCatalog
@testable import CVDesignCatalogFileStore
import CVRenderingTestSupport

extension URL {
    var origins: URL { appendingPathComponent("origins.json") }
}

private func record(_ designs: String = "[]", schemaVersion: Int = 1) -> String { #"{"designs":\#(designs),"schemaVersion":\#(schemaVersion)}"# }
private func entry(_ id: String, _ origin: String = "imported") -> String { #"{"id":"\#(id)","origin":"\#(origin)"}"# }

/// Origin records the store refuses, with the error it reports. Built step by step: a long literal array is slow to type-check.
private let badRecords: [(String, FileDesignStoreError)] = {
    var cases: [(String, FileDesignStoreError)] = []
    cases.append((#"{"schemaVersion":2,"designs":[],"themes":[]}"#, .originsFromNewerVersion(2)))
    cases.append(("not JSON", .originsCorrupt("no schema version")))
    cases.append((record(schemaVersion: 0), .originsCorrupt("schema version 0")))
    cases.append((#"{"schemaVersion":1}"#, .originsCorrupt("not an origin record")))
    cases.append((record("[\(entry("clean", "purchased"))]"), .originsCorrupt("not an origin record")))
    cases.append((record("[\(entry("clean", "Bundled"))]"), .originsCorrupt("not an origin record")))
    cases.append((record("[{\"id\":\"clean\"}]"), .originsCorrupt("not an origin record")))
    cases.append((record("[\(entry("../clean"))]"), .originsCorrupt("entries")))
    cases.append((record("[\(entry("Clean"))]"), .originsCorrupt("entries")))
    cases.append((record("[\(entry("clean")),\(entry("bold"))]"), .originsCorrupt("entries")))
    cases.append((record("[\(entry("clean")),\(entry("clean", "bundled"))]"), .originsCorrupt("entries")))
    return cases
}()

/// A writer for the store's files that logs every write it is asked for, in order, and can refuse one file.
private final class WriteLog: Sendable {
    let names = Mutex<[String]>([])
    let failing: String?
    init(failing: String? = nil) { self.failing = failing }
    func write(_ data: Data, to url: URL) throws {
        names.withLock { $0.append(url.lastPathComponent) }
        if url.lastPathComponent == failing { throw CocoaError(.fileWriteNoPermission) }
        try data.write(to: url, options: .atomic)
    }
    var written: [String] { names.withLock { $0 } }
    func store(_ dir: URL) -> FileDesignStore { FileDesignStore(directory: dir, writeFile: { try self.write($0, to: $1) }) }
}

@Suite("FileDesignStore records each design's origin (#127)")
struct FileDesignStoreOriginTests {
    @Test("a save is recorded as imported, a conditional save as bundled, and an upgrade keeps the origin")
    func recordsOrigins() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) == .installed)
            #expect(try await store.installedOrigins() == ["clean": .imported, "bold": .bundled])
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold", version: "1.1.0")) == .upgraded)
            try await store.save(DesignStoreContract.design(id: "clean", version: "2.0.0"))
            #expect(try await store.installedOrigins() == ["clean": .imported, "bold": .bundled])
        }
    }

    @Test("the record is a versioned file of its own, listing each design's origin by identifier")
    func recordFormat() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            _ = try await store.saveIfNewer(DesignStoreContract.design(id: "bold"))
            let expected = record("[\(entry("bold", "bundled")),\(entry("clean", "imported"))]")
            #expect(try String(decoding: Data(contentsOf: dir.origins), as: UTF8.self) == expected)
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .imported, "bold": .bundled])
        }
    }

    @Test("a store that does not exist yet has no origins, and asking creates nothing")
    func missingDirectory() async throws {
        try await inTemporaryStore { dir async throws in
            #expect(try await FileDesignStore(directory: dir).installedOrigins().isEmpty)
            #expect(!FileManager.default.fileExists(atPath: dir.path))
        }
    }

    @Test("a design that has no recorded origin is installed and readable, and has no origin")
    func unrecorded() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try FileManager.default.removeItem(at: dir.origins)
            #expect(try await store.installedOrigins().isEmpty)
            #expect(try await store.installedDesigns() == [clean.manifest])
            #expect(try await store.design(id: "clean") == clean)
            try await store.save(DesignStoreContract.design(id: "bold"))
            #expect(try await store.installedOrigins() == ["bold": .imported])
        }
    }

    @Test("adopting records a design that has no origin as bundled, writes only the record, and the design upgrades as bundled later")
    func adoptsUnrecorded() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try await store.save(DesignStoreContract.design(id: "bold"))
            try FileManager.default.removeItem(at: dir.origins)
            try await store.save(DesignStoreContract.design(id: "plain"))   // the record lists "plain" only
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            #expect(try await store.adoptAsBundled(clean))
            #expect(try String(decoding: Data(contentsOf: dir.origins), as: UTF8.self) == record("[\(entry("clean", "bundled")),\(entry("plain"))]"))
            #expect(try await store.adoptAsBundled(clean))   // already recorded: nothing to do
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(dir.designFiles == files)
            #expect(try await store.design(id: "clean") == clean)
            #expect(try await store.installedOrigins() == ["clean": .bundled, "plain": .imported])
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "clean", version: "1.1.0")) == .upgraded)
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .bundled, "plain": .imported])
        }
    }

    @Test("adopting a design that is imported, of another version, of other content or not installed changes nothing")
    func notAdopted() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean", version: "2.0.0"))
            try FileManager.default.removeItem(at: dir.origins)
            try await store.save(DesignStoreContract.design(id: "mine"))
            let index = try Data(contentsOf: dir.index), origins = try Data(contentsOf: dir.origins), files = dir.designFiles
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "mine")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "clean", version: "1.0.0")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "clean", version: "2.0.1")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "other")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "clean", version: "2.0.0", css: ".cv-skill{font-weight:700}")) == false)
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(try Data(contentsOf: dir.origins) == origins)
            #expect(dir.designFiles == files)
        }
    }

    @Test("adopting compares the design on disk, not only the index: a file changed on disk is not adopted, and an unreadable one is an error")
    func adoptionReadsTheFile() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try FileManager.default.removeItem(at: dir.origins)
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            try DesignStoreContract.package(id: "clean", css: ".cv-skill{font-weight:700}").write(to: dir.file("clean"))
            #expect(try await store.adoptAsBundled(clean) == false)
            try DesignStoreContract.package(id: "clean", css: ".cv{display:none}").write(to: dir.file("clean"))
            let rejected = await #expect(throws: FileDesignStoreError.self) { _ = try await store.adoptAsBundled(clean) }
            guard case .designRejected(id: "clean", _)? = rejected else { Issue.record("\(String(describing: rejected))"); return }
            try FileManager.default.removeItem(at: dir.file("clean"))
            await #expect(throws: FileDesignStoreError.designUnreadable(id: "clean")) { _ = try await store.adoptAsBundled(clean) }
            #expect(!FileManager.default.fileExists(atPath: dir.origins.path))
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(dir.designFiles == files.subtracting(["clean.1.mcvt"]))
        }
    }

    @Test("an entry for a design the index does not list is not reported, and the next save drops it")
    func orphanEntry() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            try Data(record("[\(entry("clean", "bundled")),\(entry("ghost", "bundled"))]").utf8).write(to: dir.origins)
            #expect(try await store.installedOrigins() == ["clean": .bundled])
            try await store.save(DesignStoreContract.design(id: "bold"))
            #expect(try String(decoding: Data(contentsOf: dir.origins), as: UTF8.self) == record("[\(entry("bold")),\(entry("clean", "bundled"))]"))
        }
    }

    @Test("a record from a newer version or a corrupt one is reported and left untouched, even by a save; the designs stay readable",
          arguments: badRecords)
    func badRecord(contents: String, error: FileDesignStoreError) async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try Data(contents.utf8).write(to: dir.origins)
            await #expect(throws: error) { _ = try await store.installedOrigins() }
            await #expect(throws: error) { try await store.save(DesignStoreContract.design(id: "bold")) }
            await #expect(throws: error) { _ = try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) }
            await #expect(throws: error) { _ = try await store.adoptAsBundled(clean) }
            #expect(try Data(contentsOf: dir.origins) == Data(contents.utf8))
            #expect(!FileManager.default.fileExists(atPath: dir.file("bold").path))
            #expect(try await store.installedDesigns() == [clean.manifest])
            #expect(try await store.design(id: "clean") == clean)
        }
    }

    @Test("a save writes the package file, then the record, then the index; an adoption writes the record only; a kept design writes nothing")
    func writeOrder() async throws {
        try await inTemporaryStore { dir in
            let log = WriteLog(), store = log.store(dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            #expect(log.written == ["clean.1.mcvt", "origins.json", "index.json"])
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) == .installed)
            #expect(log.written.suffix(3) == ["bold.1.mcvt", "origins.json", "index.json"])
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold", version: "1.1.0")) == .upgraded)
            #expect(log.written.suffix(3) == ["bold.2.mcvt", "origins.json", "index.json"])
            let count = log.written.count
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) == .keptInstalled)
            #expect(try await store.save(DesignStoreContract.design(id: "clean", version: "2.0.0")) == .saved)
            #expect(log.written.count == count + 3)
            try FileManager.default.removeItem(at: dir.origins)
            let before = log.written.count
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "bold", version: "1.1.0")))
            #expect(Array(log.written.dropFirst(before)) == ["origins.json"])
        }
    }

    @Test("a save whose index write fails leaves the listed designs as they were; the record's extra entry is not reported and a retry records it")
    func indexWriteFails() async throws {
        try await inTemporaryStore { dir in
            let clean = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(clean)
            let index = try Data(contentsOf: dir.index)
            let log = WriteLog(failing: "index.json"), store = log.store(dir)
            await #expect(throws: FileDesignStoreError.writeFailed(id: "bold")) { try await store.save(DesignStoreContract.design(id: "bold")) }
            #expect(log.written == ["bold.1.mcvt", "origins.json", "index.json"])
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(try String(decoding: Data(contentsOf: dir.origins), as: UTF8.self) == record("[\(entry("bold")),\(entry("clean"))]"))
            #expect(try await store.installedDesigns() == [clean.manifest])
            #expect(try await store.installedOrigins() == ["clean": .imported])
            #expect(try await store.design(id: "bold") == nil)
            let retry = try await FileDesignStore(directory: dir).saveIfNewer(DesignStoreContract.design(id: "bold"))
            #expect(retry == .installed)
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .imported, "bold": .bundled])
        }
    }

    @Test("a save whose record write fails writes no index: the design is not listed, and the record is as it was")
    func recordWriteFails() async throws {
        try await inTemporaryStore { dir in
            let clean = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(clean)
            let index = try Data(contentsOf: dir.index), origins = try Data(contentsOf: dir.origins)
            let log = WriteLog(failing: "origins.json"), store = log.store(dir)
            await #expect(throws: FileDesignStoreError.writeFailed(id: "bold")) { try await store.save(DesignStoreContract.design(id: "bold")) }
            #expect(log.written == ["bold.1.mcvt", "origins.json"])
            #expect(try Data(contentsOf: dir.index) == index && Data(contentsOf: dir.origins) == origins)
            #expect(try await store.installedDesigns() == [clean.manifest])
            try FileManager.default.removeItem(at: dir.origins)
            await #expect(throws: FileDesignStoreError.writeFailed(id: "clean")) { _ = try await store.adoptAsBundled(clean) }
            #expect(!FileManager.default.fileExists(atPath: dir.origins.path))
        }
    }

    @Test("a record that would exceed its cap is not written: nothing is, and the previous state stays")
    func recordWouldNotReadBack() async throws {
        try await inTemporaryStore { dir in
            let importedRecord = record("[\(entry("clean"))]")
            let tight = FileDesignStore(directory: dir, originsCap: record("[\(entry("clean", "bundled"))]").utf8.count - 1)   // "bundled" is the shorter
            await #expect(throws: FileDesignStoreError.wouldNotReadBack(id: "clean")) { try await tight.save(DesignStoreContract.design(id: "clean")) }
            await #expect(throws: FileDesignStoreError.wouldNotReadBack(id: "clean")) { _ = try await tight.saveIfNewer(DesignStoreContract.design(id: "clean")) }
            #expect(dir.designFiles.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: dir.index.path) && !FileManager.default.fileExists(atPath: dir.origins.path))
            let fitting = FileDesignStore(directory: dir, originsCap: importedRecord.utf8.count)
            try await fitting.save(DesignStoreContract.design(id: "clean"))
            #expect(try String(decoding: Data(contentsOf: dir.origins), as: UTF8.self) == importedRecord)
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            await #expect(throws: FileDesignStoreError.wouldNotReadBack(id: "bold")) { try await fitting.save(DesignStoreContract.design(id: "bold")) }
            #expect(try Data(contentsOf: dir.index) == index && dir.designFiles == files)
            #expect(try String(decoding: Data(contentsOf: dir.origins), as: UTF8.self) == importedRecord)
            #expect(try await fitting.installedOrigins() == ["clean": .imported])
        }
    }

    @Test("adopting does not write a record that would exceed its cap")
    func adoptionRecordWouldNotReadBack() async throws {
        try await inTemporaryStore { dir in
            let clean = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(clean)
            try FileManager.default.removeItem(at: dir.origins)
            let tight = FileDesignStore(directory: dir, originsCap: record("[\(entry("clean", "bundled"))]").utf8.count - 1)
            await #expect(throws: FileDesignStoreError.wouldNotReadBack(id: "clean")) { _ = try await tight.adoptAsBundled(clean) }
            #expect(!FileManager.default.fileExists(atPath: dir.origins.path))
        }
    }

    @Test("a record larger than the cap is reported without being read, and left untouched")
    func oversizedRecord() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            let oversized = Data(repeating: 0x20, count: FileDesignStore.maxOriginsBytes + 1)
            try oversized.write(to: dir.origins)
            await #expect(throws: FileDesignStoreError.originsCorrupt("too large")) { _ = try await store.installedOrigins() }
            await #expect(throws: FileDesignStoreError.originsCorrupt("too large")) { try await store.save(DesignStoreContract.design(id: "bold")) }
            #expect(try Data(contentsOf: dir.origins) == oversized)
        }
    }

    @Test("a record that is a symbolic link or a named pipe is unreadable, and never followed or waited on", .timeLimit(.minutes(1)))
    func unreadableRecord() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            let elsewhere = dir.appendingPathComponent("elsewhere.json")
            try FileManager.default.moveItem(at: dir.origins, to: elsewhere)
            try FileManager.default.createSymbolicLink(at: dir.origins, withDestinationURL: elsewhere)
            await #expect(throws: FileDesignStoreError.originsUnreadable) { _ = try await store.installedOrigins() }
            await #expect(throws: FileDesignStoreError.originsUnreadable) { try await store.save(DesignStoreContract.design(id: "bold")) }
            try FileManager.default.removeItem(at: dir.origins)
            #expect(mkfifo(dir.origins.path, 0o600) == 0)
            await #expect(throws: FileDesignStoreError.originsUnreadable) { _ = try await store.installedOrigins() }
        }
    }

    @Test("an import over a bundled design is refused under the lock and writes nothing; over an import or an unrecorded design it replaces")
    func importOverBundled() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let shipped = try DesignStoreContract.design(id: "shipped")
            #expect(try await store.saveIfNewer(shipped) == .installed)
            try await store.save(DesignStoreContract.design(id: "mine"))
            try await store.save(DesignStoreContract.design(id: "legacy"))
            try FileManager.default.removeItem(at: dir.origins)   // "shipped", "mine" and "legacy" now have no origin
            #expect(try await store.adoptAsBundled(shipped))
            let index = try Data(contentsOf: dir.index), origins = try Data(contentsOf: dir.origins), files = dir.designFiles
            for version in ["0.0.1", "1.0.0", "999999999.0.0"] {
                let outcome = try await store.save(DesignStoreContract.design(id: "shipped", version: version, css: ".cv-skill{font-weight:700}"))
                #expect(outcome == .keptBundled)
            }
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(try Data(contentsOf: dir.origins) == origins)
            #expect(dir.designFiles == files)
            #expect(try await store.design(id: "shipped") == shipped)
            #expect(try await store.save(DesignStoreContract.design(id: "mine", version: "2.0.0")) == .saved)
            #expect(try await store.save(DesignStoreContract.design(id: "legacy", version: "2.0.0")) == .saved)
            #expect(try await store.installedOrigins() == ["shipped": .bundled, "mine": .imported, "legacy": .imported])
        }
    }

    @Test("a bundled save and an import of one identifier from two instances: exactly one of them wins, never both")
    func bundledAndImportRace() async throws {
        try await inTemporaryStore { dir in
            let stores = [FileDesignStore(directory: dir), FileDesignStore(directory: dir)]
            let ids = (0..<40).map { "design-\($0)" }
            for id in ids {
                let bundled = try DesignStoreContract.design(id: id), imported = try DesignStoreContract.design(id: id, css: ".cv-skill{font-weight:700}")
                async let fromSync = stores[0].saveIfNewer(bundled)
                async let fromImport = stores[1].save(imported)
                let (syncOutcome, importOutcome) = try await (fromSync, fromImport)
                switch (syncOutcome, importOutcome) {
                case (.installed, .keptBundled):
                    #expect(try await stores[0].design(id: id) == bundled)
                    #expect(try await stores[0].installedOrigins()[id] == .bundled)
                case (.keptImported, .saved):
                    #expect(try await stores[0].design(id: id) == imported)
                    #expect(try await stores[0].installedOrigins()[id] == .imported)
                default:
                    Issue.record("\(id): \(syncOutcome) and \(importOutcome)")
                }
            }
            #expect(try await stores[0].installedOrigins().count == ids.count)
        }
    }

    @Test("the sync through the file store never replaces an imported design, and still upgrades the bundled ones it installed")
    func syncThroughTheFileStore() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir), gate = FakeRenderingGate()
            let mine = try DesignStoreContract.design(id: "clean", version: "0.0.1", css: ".cv-skill{font-weight:700}")
            try await store.save(mine)
            func sync(_ packages: [(name: String, data: Data)]) async throws -> SyncReport {
                try await SyncBundledDesigns(source: FixedBundledSource(packages: packages), gate: gate, store: store)()
            }
            let first = try await sync([("clean", DesignStoreContract.package(id: "clean")), ("bold", DesignStoreContract.package(id: "bold"))])
            #expect(first.conflicts == ["clean"] && first.installed == ["bold"])
            #expect(try await store.design(id: "clean") == mine)
            #expect(try await store.installedOrigins() == ["clean": .imported, "bold": .bundled])
            let second = try await sync([("clean", DesignStoreContract.package(id: "clean")), ("bold", DesignStoreContract.package(id: "bold"))])
            #expect(second.conflicts == ["clean"] && second.unchanged == ["bold"] && second.installed.isEmpty)
            let third = try await sync([("bold", DesignStoreContract.package(id: "bold", version: "1.1.0"))])
            #expect(third.upgraded == ["bold"] && third.conflicts.isEmpty)
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .imported, "bold": .bundled])
            #expect(await gate.verified == ["bold", "bold"])
        }
    }

    @Test("an import shadowing a bundled design through the file store is refused, and the bundled design still upgrades")
    func importShadowingThroughTheFileStore() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir), gate = FakeRenderingGate()
            let source = FixedBundledSource(packages: [("modern", try DesignStoreContract.package(id: "modern"))])
            _ = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
            let bundledModern = try await store.design(id: "modern")
            let shadow = try DesignStoreContract.package(id: "modern", version: "999999999.0.0", css: ".cv-skill{font-weight:700}")
            await #expect(throws: DesignCatalogError.bundledIdentifier("modern")) {
                _ = try await InstallDesign(source: source, gate: gate, store: store)(shadow)
            }
            #expect(try await store.design(id: "modern") == bundledModern)
            let fixed = FixedBundledSource(packages: [("modern", try DesignStoreContract.package(id: "modern", version: "1.0.1"))])
            let report = try await SyncBundledDesigns(source: fixed, gate: gate, store: store)()
            #expect(report.upgraded == ["modern"] && report.conflicts.isEmpty)
            #expect(try await store.installedOrigins() == ["modern": .bundled])
        }
    }

    @Test("the record's version follows the origins it holds: bump it when an origin is added")
    func recordVersionFollowsOrigins() {
        let message: Comment = "a record written with a new origin cannot be read by an older app: bump the record version when an origin is added"
        #expect(FileDesignStore.originsVersion == 1, message)
        #expect(DesignOrigin.allCases.map(\.rawValue) == ["bundled", "imported"], message)
    }
}
