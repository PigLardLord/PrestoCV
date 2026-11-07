import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// The files only the store knows how to make, by hand in a temporary directory.
private func harness(_ dir: URL) -> MaintenanceHarness {
    MaintenanceHarness(
        open: { repo(dir) },
        plantCorrupt: { id in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id)))
        },
        plantQuarantined: { id, cv, enteredAt in
            let q = dir.appendingPathComponent("Quarantine")
            try FileManager.default.createDirectory(at: q, withIntermediateDirectories: true)
            var name = fileName(id), n = 1
            while FileManager.default.fileExists(atPath: q.appendingPathComponent(name).path) { name = "\(n)~" + fileName(id); n += 1 }
            let data = try cv.map { try CVFileV1($0, createdAt: enteredAt, updatedAt: enteredAt).encoded() } ?? Data("{".utf8)
            try data.write(to: q.appendingPathComponent(name))
            try FileManager.default.setAttributes([.modificationDate: enteredAt], ofItemAtPath: q.appendingPathComponent(name).path)
            return name
        },
        adopt: { cv in try await repo(dir).adopt(cv) })
}

@Suite("The file store's maintenance, under the contract")
struct FileCVRepositoryMaintenanceContractTests {
    @Test("a corrupt file listed once is still in quarantined() on a new instance")
    func survivesRestart() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.corruptFileStaysQuarantinedAcrossInstances(harness(dir))
    }

    @Test("restore returns the CV and removes the quarantined copy; a second restore finds nothing")
    func restores() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.restoreMovesTheCVBack(harness(dir))
    }

    @Test("restore refuses ../x.cv.json, a name with a slash and a name not in the pattern")
    func refusesNames() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.restoreRefusesBadNames(harness(dir))
    }

    @Test("restore of a CV whose id is stored fails with alreadyExists and keeps both")
    func refusesStoredID() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.restoreRefusesAStoredID(harness(dir))
    }

    @Test("purge: 29 days kept, 31 days removed, the cutoff computed from the injected clock")
    func purges() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.purgeCountsFromTheClock(harness(dir))
    }

    @Test("eraseAll keeping the ledger leaves it and names it; a second adoption stores nothing")
    func keepsTheLedger() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.eraseAllKeepsTheLedgerOnRequest(harness(dir))
    }

    @Test("restore, purge, list and erase race on two instances without a lost or duplicated CV")
    func races() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.raceKeepsEveryCVOnce(harness(dir))
    }

    @Test("eraseAll racing 10 updates and 10 creates: no write succeeds after the erase, and the count adds up")
    func eraseAllRaces() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.eraseAllOrdersWithWrites(harness(dir))
    }

    @Test("eraseAll removes valid, corrupt and quarantined files, and a second call nothing")
    func erasesAll() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVStoreMaintenanceContract.eraseAllRemovesEveryKind(harness(dir))
    }
}

@Suite("Erasing the whole file store")
struct FileCVRepositoryEraseAllTests {
    private func entries(_ dir: URL) throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted() }

    @Test("eraseAll removes valid, corrupt, newer-schema, odd-named, quarantined, staged and ledger files; only .lock stays")
    func everyKind() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir), q = dir.appendingPathComponent("Quarantine")
        _ = try await r.create(named("Valid", id: id1))
        try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id2)))                                          // corrupt
        let id3 = CVID(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        try Data(fileJSON(id: id3.raw.uuidString, version: 9).utf8).write(to: dir.appendingPathComponent(fileName(id3)))   // newer schema
        try Data("x".utf8).write(to: dir.appendingPathComponent("not-a-uuid.cv.json"))                                  // a name no CV has
        try FileManager.default.createDirectory(at: q, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: q.appendingPathComponent(fileName(id1)))
        try Data("{".utf8).write(to: q.appendingPathComponent("1~" + fileName(id1)))
        try Data("{".utf8).write(to: dir.appendingPathComponent(FileCVRepository.stagedName(for: id2)))
        try Data(#"["\#(id1.raw.uuidString)"]"#.utf8).write(to: dir.appendingPathComponent(FileCVRepository.legacyLedgerName))

        let report = try await r.eraseAll(keepingLedger: false)
        #expect(report == EraseAllReport(erased: 8))
        #expect(try entries(dir) == [".lock"])
        #expect(try await r.eraseAll(keepingLedger: false) == EraseAllReport(erased: 0))
        #expect(try entries(dir) == [".lock"])
    }

    @Test("eraseAll on a store that was never created removes nothing and creates nothing")
    func neverCreated() async throws {
        let dir = tempDir()
        #expect(try await repo(dir).eraseAll(keepingLedger: false) == EraseAllReport(erased: 0))
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("eraseAll with a quarantine that cannot be changed reports its files and removes the rest; a rerun finishes",
          .enabled(if: !isRoot, "a root process can remove files from a read-only directory, so nothing would fail"))
    func partial() async throws {
        let dir = tempDir(); let q = dir.appendingPathComponent("Quarantine")
        defer { chmod(q.path, 0o755); try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(named("Valid", id: id1))
        try FileManager.default.createDirectory(at: q, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: q.appendingPathComponent(fileName(id2)))
        try Data("{".utf8).write(to: q.appendingPathComponent("1~" + fileName(id2)))
        chmod(q.path, 0o555)

        let report = try await r.eraseAll(keepingLedger: false)
        #expect(report.erased == 1)
        #expect(Set(report.remaining) == [RemainingItem(kind: .quarantined, name: fileName(id2)), RemainingItem(kind: .quarantined, name: "1~" + fileName(id2))])
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(fileName(id1)).path))

        chmod(q.path, 0o755)
        #expect(try await r.eraseAll(keepingLedger: false) == EraseAllReport(erased: 2))
        #expect(try entries(dir) == [".lock"])
    }

    @Test("eraseAll fails when the store is not a directory, and changes nothing")
    func notADirectory() async throws {
        let file = tempDir(); defer { try? FileManager.default.removeItem(at: file) }
        try Data("x".utf8).write(to: file)
        await #expect(throws: RepositoryError.storeUnavailable(.notADirectory)) { _ = try await repo(file).eraseAll(keepingLedger: false) }
        #expect(try Data(contentsOf: file) == Data("x".utf8))
    }

    @Test("a quarantine that is a link is removed as a link; its target is untouched")
    func linkedQuarantine() async throws {
        let dir = tempDir(), elsewhere = tempDir()
        defer { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: elsewhere) }
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: elsewhere.appendingPathComponent(fileName(id1)))
        _ = try await repo(dir).create(named("Valid", id: id2))
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("Quarantine"), withDestinationURL: elsewhere)
        #expect(try await repo(dir).eraseAll(keepingLedger: false) == EraseAllReport(erased: 2))
        #expect(try entries(dir) == [".lock"])
        #expect(try entries(elsewhere) == [fileName(id1)])
    }
}

/// A legacy source that is rewritten between the listing and the removal, as another process would.
private struct ChangingSource: LegacyStore {
    let base: DirectoryLegacyStore, directory: URL, changing: String
    func records() async throws(RepositoryError) -> [LegacyRecord] { try await base.records() }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        if key == LegacyRecord.Key(name: changing) { try? Data("{\"changed\":true}".utf8).write(to: directory.appendingPathComponent(changing)) }
        return try await base.remove(key, ifUnchanged: version)
    }
}

@Suite("Erasing everything, legacy sources included")
struct EraseEverythingTests {
    @Test("unremoved legacy sources go with the store; a source whose bytes changed stays and is named")
    func sources() async throws {
        let a = LegacyFixtures.fileName(LegacyFixtures.idA), b = LegacyFixtures.fileName(LegacyFixtures.idB)
        let legacy = try legacyDir([a: LegacyFixtures.v10(), b: LegacyFixtures.v101(), "notes.txt": "not a candidate"])
        let store = tempDir()
        defer { try? FileManager.default.removeItem(at: legacy); try? FileManager.default.removeItem(at: store) }
        let r = repo(store)
        _ = try await r.create(named("Valid", id: id1))
        let directoryStore = DirectoryLegacyStore(directory: legacy, clock: SteppingClock())

        let outcome = try await EraseEverything(maintenance: r, legacy: ChangingSource(base: directoryStore, directory: legacy, changing: b))()
        #expect(outcome == .partial(erased: 2, remaining: [RemainingItem(kind: .legacySource, name: b)]))
        #expect(try Set(FileManager.default.contentsOfDirectory(atPath: legacy.path)) == [b, "notes.txt"])
        #expect(try Data(contentsOf: legacy.appendingPathComponent(b)) == Data("{\"changed\":true}".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.path) == [".lock"])

        // The source that changed is a file the person's old app wrote; a rerun reads it as it is now, and it is not a CV: it stays named.
        let again = try await EraseEverything(maintenance: r, legacy: directoryStore)()
        #expect(again == .erased(1))
        #expect(try Set(FileManager.default.contentsOfDirectory(atPath: legacy.path)) == ["notes.txt"])
    }

    @Test("a legacy file the importer cannot read stays and is named, and the store is erased all the same")
    func unreadableSource() async throws {
        let a = LegacyFixtures.fileName(LegacyFixtures.idA)
        let legacy = try legacyDir([a: LegacyFixtures.v10()]), store = tempDir()
        defer { try? FileManager.default.removeItem(at: legacy); try? FileManager.default.removeItem(at: store) }
        let r = repo(store)
        _ = try await r.create(named("Valid", id: id1))
        let tiny = DirectoryLegacyStore(directory: legacy, clock: SteppingClock(), maxFileBytes: 10)
        let outcome = try await EraseEverything(maintenance: r, legacy: tiny)()
        #expect(outcome == .partial(erased: 1, remaining: [RemainingItem(kind: .legacySource, name: a)]))
        #expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent(a).path))
    }

    @Test("with no legacy directory, the outcome is the store's")
    func noLegacy() async throws {
        let store = tempDir(); defer { try? FileManager.default.removeItem(at: store) }
        let r = repo(store)
        _ = try await r.create(named("Valid", id: id1))
        let none = DirectoryLegacyStore(directory: tempDir(), clock: SteppingClock())
        #expect(try await EraseEverything(maintenance: r, legacy: none)() == .erased(1))
        #expect(try await EraseEverything(maintenance: r, legacy: none)() == .erased(0))
    }
}
