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

/// A writer for the store's files that logs every write it is asked for, in order, and can refuse one file.
private final class WriteLog: Sendable {
    let names = Mutex<[String]>([])
    let failing: String?
    init(failing: String? = nil) { self.failing = failing }
    func write(_ data: Data, to url: URL) throws {
        names.withLock { $0.append(url.lastPathComponent) }
        if url.lastPathComponent == failing || (failing == "package" && url.pathExtension == "mcvt") { throw CocoaError(.fileWriteNoPermission) }
        try data.write(to: url, options: .atomic)
    }
    var written: [String] { names.withLock { $0 } }
    func store(_ dir: URL) -> FileDesignStore { FileDesignStore(directory: dir, writeFile: { try self.write($0, to: $1) }) }
}

/// Which save a failure scenario runs, over an installed "clean" design at 1.0.0 whose recorded origin is `start`.
enum FailureScenario: CaseIterable, CustomTestStringConvertible {
    case importOverUnrecorded, importOverImported, syncUpgradeOverBundled, syncOverUnrecorded
    var testDescription: String { String(describing: self).replacingOccurrences(of: "Over", with: " over ") }
    var start: DesignOrigin? {
        switch self {
        case .importOverUnrecorded, .syncOverUnrecorded: nil
        case .importOverImported: .imported
        case .syncUpgradeOverBundled: .bundled
        }
    }
    /// The origin the save records when it writes.
    var recorded: DesignOrigin {
        switch self {
        case .importOverUnrecorded, .importOverImported: .imported
        case .syncUpgradeOverBundled, .syncOverUnrecorded: .bundled
        }
    }
    /// Whether the save replaces the installed design (a sync over a design that is not recorded as bundled keeps it).
    var replaces: Bool { self != .syncOverUnrecorded }
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

    @Test("the index lists each design's origin in its own entry, and no other file records one")
    func originInTheEntry() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            _ = try await store.saveIfNewer(DesignStoreContract.design(id: "bold"))
            let designs = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: dir.index)) as? [String: Any])["designs"] as? [[String: Any]]
            #expect(designs?.map { ($0["manifest"] as? [String: Any])?["id"] as? String } == ["bold", "clean"])
            #expect(designs?.map { $0["origin"] as? String } == ["bundled", "imported"])
            #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted() == [".lock", "Designs", "index.json"])
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
            try dir.removeOrigins()
            #expect(try await store.installedOrigins().isEmpty)
            #expect(try await store.installedDesigns() == [clean.manifest])
            #expect(try await store.design(id: "clean") == clean)
            try await store.save(DesignStoreContract.design(id: "bold"))
            #expect(try await store.installedOrigins() == ["bold": .imported])
        }
    }

    @Test("adopting records a design that has no origin as bundled, rewrites only the index, and the design upgrades as bundled later")
    func adoptsUnrecorded() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try await store.save(DesignStoreContract.design(id: "bold"))
            try dir.removeOrigins()
            try await store.save(DesignStoreContract.design(id: "plain"))   // "plain" is the only design with a recorded origin
            let files = dir.designFiles
            #expect(try await store.adoptAsBundled(clean))
            #expect(try await store.installedOrigins() == ["clean": .bundled, "plain": .imported], "\"bold\" stays unrecorded")
            #expect(dir.designFiles == files)
            let index = try Data(contentsOf: dir.index)
            #expect(try await store.adoptAsBundled(clean))   // already recorded: nothing to do
            #expect(try Data(contentsOf: dir.index) == index)
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
            try dir.removeOrigins()
            try await store.save(DesignStoreContract.design(id: "mine"))
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "mine")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "clean", version: "1.0.0")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "clean", version: "2.0.1")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "other")) == false)
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "clean", version: "2.0.0", css: ".cv-skill{font-weight:700}")) == false)
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(dir.designFiles == files)
        }
    }

    @Test("adopting compares the design on disk, not only the index: a file changed on disk is not adopted, and an unreadable one is an error")
    func adoptionReadsTheFile() async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try dir.removeOrigins()
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            try DesignStoreContract.package(id: "clean", css: ".cv-skill{font-weight:700}").write(to: dir.file("clean"))
            #expect(try await store.adoptAsBundled(clean) == false)
            try DesignStoreContract.package(id: "clean", css: ".cv{display:none}").write(to: dir.file("clean"))
            let rejected = await #expect(throws: FileDesignStoreError.self) { _ = try await store.adoptAsBundled(clean) }
            guard case .designRejected(id: "clean", _)? = rejected else { Issue.record("\(String(describing: rejected))"); return }
            try FileManager.default.removeItem(at: dir.file("clean"))
            await #expect(throws: FileDesignStoreError.designUnreadable(id: "clean")) { _ = try await store.adoptAsBundled(clean) }
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(dir.designFiles == files.subtracting(["clean.1.mcvt"]))
        }
    }

    @Test("an origin name the store does not know makes the index corrupt: it is reported and left untouched, even by a save",
          arguments: ["purchased", "Bundled", ""])
    func badOrigin(origin: String) async throws {
        try await inTemporaryStore { dir in
            let store = FileDesignStore(directory: dir)
            let clean = try DesignStoreContract.design(id: "clean")
            try await store.save(clean)
            try dir.index.rewriteIndexEntries { $0.merging(["origin": origin]) { $1 } }
            let contents = try Data(contentsOf: dir.index), corrupt = FileDesignStoreError.indexCorrupt("not an index")
            await #expect(throws: corrupt) { _ = try await store.installedOrigins() }
            await #expect(throws: corrupt) { try await store.save(DesignStoreContract.design(id: "bold")) }
            await #expect(throws: corrupt) { _ = try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) }
            await #expect(throws: corrupt) { _ = try await store.adoptAsBundled(clean) }
            #expect(try Data(contentsOf: dir.index) == contents)
            #expect(!FileManager.default.fileExists(atPath: dir.file("bold").path))
        }
    }

    @Test("a save writes the package file, then the index and nothing after it; an adoption writes the index only; a kept design writes nothing")
    func writeOrder() async throws {
        try await inTemporaryStore { dir in
            let log = WriteLog(), store = log.store(dir)
            try await store.save(DesignStoreContract.design(id: "clean"))
            #expect(log.written == ["clean.1.mcvt", "index.json"])
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) == .installed)
            #expect(log.written.suffix(2) == ["bold.1.mcvt", "index.json"])
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold", version: "1.1.0")) == .upgraded)
            #expect(log.written.suffix(2) == ["bold.2.mcvt", "index.json"])
            let count = log.written.count
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "bold")) == .keptInstalled)
            #expect(try await store.save(DesignStoreContract.design(id: "clean", version: "2.0.0")) == .saved)
            #expect(log.written.count == count + 2)
            try dir.removeOrigins(of: ["bold"])
            let before = log.written.count
            #expect(try await store.adoptAsBundled(DesignStoreContract.design(id: "bold", version: "1.1.0")))
            #expect(Array(log.written.dropFirst(before)) == ["index.json"])
        }
    }

    @Test("after a failed write, whichever file it was, the store reports the old state or the new state, nothing in between",
          arguments: FailureScenario.allCases, ["package", "index.json"])
    func failedWriteNeverChangesTheOrigin(scenario: FailureScenario, failing: String) async throws {
        try await inTemporaryStore { dir in
            let old = try DesignStoreContract.design(id: "clean"), new = try DesignStoreContract.design(id: "clean", version: "2.0.0")
            let seed = FileDesignStore(directory: dir)
            if scenario.start == .bundled { _ = try await seed.saveIfNewer(old) } else { try await seed.save(old) }
            if scenario.start == nil { try dir.removeOrigins() }
            let store = WriteLog(failing: failing).store(dir)
            do {
                if scenario == .importOverUnrecorded || scenario == .importOverImported { try await store.save(new) } else { _ = try await store.saveIfNewer(new) }
            } catch {}
            let fresh = FileDesignStore(directory: dir)
            let listed = try await fresh.installedDesigns(), origin = try await fresh.installedOrigins()["clean"]
            if listed == [old.manifest] {
                #expect(origin == scenario.start, "the old design is listed, and its origin is as it was")
                #expect(try await fresh.design(id: "clean") == old)
            } else {
                #expect(listed == [new.manifest] && scenario.replaces)
                #expect(origin == scenario.recorded, "the new design has the origin its save gave it")
                #expect(try await fresh.design(id: "clean") == new)
            }
        }
    }

    @Test("a save whose index write fails leaves the listed designs and every origin as they were, and a retry installs it")
    func indexWriteFails() async throws {
        try await inTemporaryStore { dir in
            let clean = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(clean)
            let index = try Data(contentsOf: dir.index)
            let log = WriteLog(failing: "index.json"), store = log.store(dir)
            await #expect(throws: FileDesignStoreError.writeFailed(id: "bold")) { try await store.save(DesignStoreContract.design(id: "bold")) }
            #expect(log.written == ["bold.1.mcvt", "index.json"])
            #expect(try Data(contentsOf: dir.index) == index)
            #expect(try await store.installedDesigns() == [clean.manifest])
            #expect(try await store.installedOrigins() == ["clean": .imported])
            #expect(try await store.design(id: "bold") == nil)
            let retry = try await FileDesignStore(directory: dir).saveIfNewer(DesignStoreContract.design(id: "bold"))
            #expect(retry == .installed)
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .imported, "bold": .bundled])
        }
    }

    @Test("an adoption whose index write fails leaves the index as it was, with the design unrecorded, and a retry adopts it")
    func adoptionWriteFails() async throws {
        try await inTemporaryStore { dir in
            let clean = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(clean)
            try dir.removeOrigins()
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            let log = WriteLog(failing: "index.json"), store = log.store(dir)
            await #expect(throws: FileDesignStoreError.writeFailed(id: "clean")) { _ = try await store.adoptAsBundled(clean) }
            #expect(log.written == ["index.json"])
            #expect(try Data(contentsOf: dir.index) == index && dir.designFiles == files)
            #expect(try await store.installedOrigins().isEmpty)
            #expect(try await store.design(id: "clean") == clean)
            #expect(try await FileDesignStore(directory: dir).adoptAsBundled(clean))
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .bundled])
        }
    }

    @Test("two instances on one directory adopting 40 designs at once lose no record update")
    func twoInstancesAdopt() async throws {
        try await inTemporaryStore { dir in
            let designs = try (0..<40).map { try DesignStoreContract.design(id: "design-\($0)") }
            let seed = FileDesignStore(directory: dir)
            for design in designs { try await seed.save(design) }
            try dir.removeOrigins()   // every design now has no recorded origin
            let stores = [FileDesignStore(directory: dir), FileDesignStore(directory: dir)]
            let adopted = try await withThrowingTaskGroup(of: Bool.self) { group in
                for (n, design) in designs.enumerated() { group.addTask { try await stores[n % 2].adoptAsBundled(design) } }
                return try await group.reduce(into: []) { $0.append($1) }
            }
            #expect(adopted.count == 40 && adopted.allSatisfy { $0 })
            let expected = Dictionary(uniqueKeysWithValues: designs.map { ($0.manifest.id, DesignOrigin.bundled) })
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == expected)
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
            try dir.removeOrigins()   // "shipped", "mine" and "legacy" now have no origin
            #expect(try await store.adoptAsBundled(shipped))
            let index = try Data(contentsOf: dir.index), files = dir.designFiles
            for version in ["0.0.1", "1.0.0", "999999999.0.0"] {
                let outcome = try await store.save(DesignStoreContract.design(id: "shipped", version: version, css: ".cv-skill{font-weight:700}"))
                #expect(outcome == .keptBundled)
            }
            #expect(try Data(contentsOf: dir.index) == index)
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

    @Test("the index's version follows the origins it holds: bump it when an origin is added")
    func indexVersionFollowsOrigins() {
        let message: Comment = "an index written with a new origin cannot be read by an older app: bump the index version when an origin is added"
        #expect(FileDesignStore.indexVersion == 2, message)
        #expect(DesignOrigin.allCases.map { "\($0)" } == ["bundled", "imported"], message)
    }
}

@Suite("FileDesignStore commits a design's origin with its generation (the index entry)")
struct FileDesignStoreOriginCommitTests {
    @Test("a first bundled save whose write fails leaves nothing that blocks a newer bundled version after reopening", arguments: ["package", "index.json"])
    func failedFirstBundledSaveThenNewer(failing: String) async throws {
        try await inTemporaryStore { dir in
            let v1 = try DesignStoreContract.design(id: "clean"), v2 = try DesignStoreContract.design(id: "clean", version: "1.1.0")
            await #expect(throws: FileDesignStoreError.writeFailed(id: "clean")) { _ = try await WriteLog(failing: failing).store(dir).saveIfNewer(v1) }
            let reopened = FileDesignStore(directory: dir)
            #expect(try await reopened.saveIfNewer(v2) == .installed, "the newer version is installed, not kept as an unrecorded design")
            #expect(try await FileDesignStore(directory: dir).installedOrigins() == ["clean": .bundled])
            #expect(try await FileDesignStore(directory: dir).design(id: "clean") == v2)
        }
    }

    @Test("a sync whose first run fails a write installs a newer bundled package at the next run, recorded as bundled", arguments: ["package", "index.json"])
    func syncAfterFailedFirstInstall(failing: String) async throws {
        try await inTemporaryStore { dir in
            let gate = FakeRenderingGate()
            let first = FixedBundledSource(packages: [("clean", try DesignStoreContract.package(id: "clean"))])
            let report = try await SyncBundledDesigns(source: first, gate: gate, store: WriteLog(failing: failing).store(dir))()
            #expect(report.failed == ["clean"])
            let second = FixedBundledSource(packages: [("clean", try DesignStoreContract.package(id: "clean", version: "1.1.0"))])
            let store = FileDesignStore(directory: dir)
            let next = try await SyncBundledDesigns(source: second, gate: gate, store: store)()
            #expect(next.installed == ["clean"] && next.conflicts.isEmpty && next.failed.isEmpty, "installed, not a conflict")
            #expect(try await store.installedOrigins() == ["clean": .bundled])
            #expect(try await store.design(id: "clean") == DesignStoreContract.design(id: "clean", version: "1.1.0"))
        }
    }

    @Test("a design whose index entry has no origin is never replaced by a newer bundled version, and never adopted when the bundle differs")
    func unrecordedStaysAConflict() async throws {
        try await inTemporaryStore { dir in
            let gate = FakeRenderingGate(), mine = try DesignStoreContract.design(id: "clean")
            try await FileDesignStore(directory: dir).save(mine)
            try dir.removeOrigins()
            let store = FileDesignStore(directory: dir)
            #expect(try await store.installedOrigins().isEmpty)
            #expect(try await store.saveIfNewer(DesignStoreContract.design(id: "clean", version: "1.1.0")) == .keptImported)
            let source = FixedBundledSource(packages: [("clean", try DesignStoreContract.package(id: "clean", version: "1.1.0"))])
            let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
            #expect(report.conflicts == ["clean"] && report.installed.isEmpty && report.upgraded.isEmpty && report.adopted.isEmpty)
            #expect(try await store.design(id: "clean") == mine)
            #expect(try await store.installedOrigins().isEmpty)
        }
    }
}
