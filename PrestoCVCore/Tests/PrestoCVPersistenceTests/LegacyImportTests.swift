import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

private let idA = CVID(UUID(uuidString: LegacyFixtures.idA)!)
private let idB = CVID(UUID(uuidString: LegacyFixtures.idB)!)

private func key(_ name: String) -> LegacyRecord.Key { .init(name: name) }

private struct World {
    let legacy: URL, store: URL
    let repository: FileCVRepository
    var source: DirectoryLegacyStore { DirectoryLegacyStore(directory: legacy, clock: SteppingClock()) }
    func importer(removing: Bool = true) -> ImportLegacyStore {
        ImportLegacyStore(source: source, target: repository, removingVerifiedSources: removing)
    }
    func legacyFile(_ id: String) -> URL { legacy.appendingPathComponent(LegacyFixtures.fileName(id)) }
}

private func world(_ files: [String: String]) throws -> World {
    let legacy = try legacyDir(files), store = tempDir()
    return World(legacy: legacy, store: store, repository: repo(store))
}

private func standard() throws -> World {
    try world([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(),
               LegacyFixtures.fileName(LegacyFixtures.idB): LegacyFixtures.v101()])
}

@Suite("Importing the legacy store once")
struct LegacyImportTests {
    @Test("both released shapes are imported with their times, and the list keeps its order")
    func importsBoth() async throws {
        let w = try standard()
        let report = try await w.importer().run()
        #expect(Set(report.imported) == [idA, idB] && report.failures.isEmpty)
        let listing = try await w.repository.list()
        #expect(listing.issues.isEmpty)
        #expect(listing.cvs.map(\.id) == [idB, idA])   // 1.0.1 was changed later
        let a = try await w.repository.load(idA)
        #expect(a.revision == 1 && a.title == "Lab roles")
        #expect(a.updatedAt == ISO8601DateFormatter().date(from: "2026-09-20T10:00:00Z"))
        let b = try await w.repository.load(idB)
        #expect(b.design == DesignChoice(design: "modern", palette: "ocean", fonts: "classic"))
    }

    @Test("what was dropped is reported for the CV it was dropped from")
    func reportsDrops() async throws {
        let w = try world([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.minimal(#""look":{"palette":"ocean"}"#)])
        let report = try await w.importer().run()
        #expect(report.drops[idA] == [.look])
    }

    @Test("a source is removed only once its copy is stored, and the copy reads back")
    func removesVerifiedSources() async throws {
        let w = try standard()
        let report = try await w.importer().run()
        #expect(Set(report.removedSources) == [key(LegacyFixtures.fileName(LegacyFixtures.idA)), key(LegacyFixtures.fileName(LegacyFixtures.idB))])
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        let cvs = try await w.repository.list().cvs
        #expect(cvs.count == 2)
    }

    @Test("with removal off, the sources stay")
    func keepsSourcesWhenAsked() async throws {
        let w = try standard()
        let report = try await w.importer(removing: false).run()
        #expect(report.removedSources.isEmpty && report.imported.count == 2)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a second run imports nothing and never overwrites a CV the person has changed since")
    func idempotent() async throws {
        let w = try standard()
        _ = try await w.importer(removing: false).run()
        var edited = try await w.repository.load(idA)
        edited.rename("Edited since")
        _ = try await w.repository.update(edited)
        let again = try await w.importer(removing: false).run()
        #expect(again.imported.isEmpty && Set(again.alreadyStored) == [idA, idB] && again.failures.isEmpty)
        let kept = try await w.repository.load(idA)
        #expect(kept.title == "Edited since" && kept.revision == 2)
    }

    @Test("a CV the person deleted does not come back, even when its source was kept")
    func deletedStaysDeleted() async throws {
        let w = try standard()
        _ = try await w.importer(removing: false).run()
        let adopted = try await w.repository.load(idA)
        try await w.repository.delete(idA, revision: adopted.revision)
        let again = try await w.importer().run()
        #expect(again.imported.isEmpty && Set(again.alreadyStored) == [idA, idB] && again.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        #expect(try await w.repository.list().cvs.map(\.id) == [idB])
    }

    @Test("a CV stored without a ledger entry (a stop between the two writes) is existing, and gets its entry")
    func storedWithoutEntry() async throws {
        let w = try standard()
        _ = try await w.repository.create(named("Stored first", id: idA))
        let report = try await w.importer().run()
        #expect(report.alreadyStored == [idA] && report.imported == [idB] && report.failures.isEmpty)
        #expect(try await w.repository.load(idA).personal.fullName == "Stored first")
        let ledger = try JSONDecoder().decode([String].self, from: Data(contentsOf: w.store.appendingPathComponent(FileCVRepository.legacyLedgerName)))
        #expect(ledger == [LegacyFixtures.idA, LegacyFixtures.idB])
    }

    @Test("a ledger that cannot be read keeps the source and stores nothing")
    func corruptLedger() async throws {
        let w = try standard()
        try FileManager.default.createDirectory(at: w.store, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: w.store.appendingPathComponent(FileCVRepository.legacyLedgerName))
        let report = try await w.importer().run()
        #expect(report.imported.isEmpty && report.failures.count == 2)
        #expect(report.failures.allSatisfy { $0.reason == .notStored(.corrupt(file: FileCVRepository.legacyLedgerName)) })
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        #expect(try await w.repository.list().cvs.isEmpty)
    }

    @Test("the ledger is left alone by listing, erasing, purging the quarantine and restoring")
    func ledgerIsLeftAlone() async throws {
        let w = try standard()
        _ = try await w.importer().run()
        let url = w.store.appendingPathComponent(FileCVRepository.legacyLedgerName)
        let before = try Data(contentsOf: url)
        let listing = try await w.repository.list()
        #expect(listing.issues.isEmpty)
        try await w.repository.erase(idA)
        _ = try await w.repository.purgeQuarantine(olderThan: .distantFuture)
        #expect(try Data(contentsOf: url) == before)
        #expect(!FileManager.default.fileExists(atPath: w.store.appendingPathComponent("Quarantine").path))
    }

    // MARK: A CV becomes visible only after the ledger holds its id

    /// A staged copy of `id`, as a run killed after the staged write leaves it.
    private func stageCopy(_ id: CVID, in w: World) async throws {
        let scratch = tempDir()
        _ = try await ImportLegacyStore(source: w.source, target: repo(scratch), removingVerifiedSources: false).run()
        try FileManager.default.createDirectory(at: w.store, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: scratch.appendingPathComponent(id.raw.uuidString + ".cv.json"),
                                         to: w.store.appendingPathComponent(FileCVRepository.stagedName(for: id)))
    }

    private func writeLedger(_ ids: [String], in w: World) throws {
        try FileManager.default.createDirectory(at: w.store, withIntermediateDirectories: true)
        try JSONEncoder().encode(ids).write(to: w.store.appendingPathComponent(FileCVRepository.legacyLedgerName))
    }

    @Test("a stop after the staged write and before the ledger: the CV is not listed, and the next run stores it")
    func killedBeforeLedger() async throws {
        let w = try standard()
        try await stageCopy(idA, in: w)
        #expect(try await w.repository.list().cvs.isEmpty)
        let report = try await w.importer().run()
        #expect(Set(report.imported) == [idA, idB] && report.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: w.store.appendingPathComponent(FileCVRepository.stagedName(for: idA)).path))
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a stop after the ledger and before the rename: the CV is not listed, the next run finishes the rename, and the source goes only then")
    func killedBeforeRename() async throws {
        let w = try standard()
        try await stageCopy(idA, in: w)
        try writeLedger([LegacyFixtures.idA], in: w)
        #expect(try await w.repository.list().cvs.isEmpty)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        let report = try await w.importer().run()
        #expect(Set(report.imported) == [idA, idB] && report.failures.isEmpty)
        #expect(try await w.repository.load(idA).revision == 1)
        #expect(!FileManager.default.fileExists(atPath: w.store.appendingPathComponent(FileCVRepository.stagedName(for: idA)).path))
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a CV erased before the rename was finished stays erased: its staged copy goes with it")
    func erasedStagedCopy() async throws {
        let w = try standard()
        try await stageCopy(idA, in: w)
        try writeLedger([LegacyFixtures.idA], in: w)
        try await w.repository.erase(idA)
        let report = try await w.importer().run()
        #expect(report.alreadyStored == [idA] && report.imported == [idB])
        #expect(try await w.repository.list().cvs.map(\.id) == [idB])
    }

    @Test("listing, quarantine, purging and restoring leave a staged copy and the ledger alone")
    func stagedCopyIsLeftAlone() async throws {
        let w = try standard()
        try await stageCopy(idA, in: w)
        try writeLedger([LegacyFixtures.idA], in: w)
        let staged = w.store.appendingPathComponent(FileCVRepository.stagedName(for: idA))
        let before = try Data(contentsOf: staged)
        #expect(try await w.repository.list().issues.isEmpty)
        try await w.repository.erase(idB)
        _ = try await w.repository.purgeQuarantine(olderThan: .distantFuture)
        #expect(try Data(contentsOf: staged) == before)
        #expect(!FileManager.default.fileExists(atPath: w.store.appendingPathComponent("Quarantine").path))
    }

    @Test("the CV file's sync failed on a run: the retry syncs it before saying existing, and the source goes only then", .enabled(if: !isRoot))
    func retrySyncsTheCVFile() async throws {
        let w = try standard()
        _ = try await w.importer(removing: false).run()
        let file = w.store.appendingPathComponent(LegacyFixtures.idA + ".cv.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o200], ofItemAtPath: file.path)   // cannot be opened to be synced
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
        let failed = try await w.importer().run()
        #expect(!failed.failures.isEmpty)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        let retried = try await w.importer().run()
        #expect(retried.alreadyStored == [idA] && retried.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("the ledger's sync failed on a run: the retry syncs it again before saying existing", .enabled(if: !isRoot))
    func retrySyncsTheLedger() async throws {
        let w = try standard()
        _ = try await w.importer(removing: false).run()
        let ledger = w.store.appendingPathComponent(FileCVRepository.legacyLedgerName)
        try FileManager.default.setAttributes([.posixPermissions: 0o200], ofItemAtPath: ledger.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: ledger.path) }
        let failed = try await w.importer().run()
        #expect(failed.removedSources.isEmpty && failed.failures.count == 2)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: ledger.path)
        let retried = try await w.importer().run()
        #expect(Set(retried.alreadyStored) == [idA, idB] && retried.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a store that cannot be made durable keeps the source", .enabled(if: !isRoot))
    func syncFailureKeepsSource() async throws {
        let w = try standard()
        try FileManager.default.createDirectory(at: w.store, withIntermediateDirectories: true)
        // Writable and searchable but not readable: the directory cannot be opened to be synced.
        try FileManager.default.setAttributes([.posixPermissions: 0o300], ofItemAtPath: w.store.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: w.store.path) }
        let report = try await w.importer().run()
        #expect(report.imported.isEmpty && report.removedSources.isEmpty && report.failures.count == 2)
        #expect(report.failures.allSatisfy { if case .notStored(.writeFailed) = $0.reason { true } else { false } })
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a stored file that is not there after the write fails, instead of passing as read back")
    func missingReadBack() {
        #expect(throws: RepositoryError.wouldNotReadBack(file: "x.cv.json")) { try FileCVRepository.verified(nil, file: "x.cv.json") }
        let cv = CV(id: idA, personal: PersonalDetails(fullName: "N"))
        #expect(throws: Never.self) { try FileCVRepository.verified(cv, file: "x.cv.json") }
    }

    @Test("a run after a complete run finds nothing to do")
    func rerunAfterRemoval() async throws {
        let w = try standard()
        _ = try await w.importer().run()
        let again = try await w.importer().run()
        #expect(again == LegacyImportReport())
    }

    @Test("one bad file does not stop the others, and it stays where it was, byte for byte")
    func partialFailure() async throws {
        let bad = "{ this is not json"
        let w = try world([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(), LegacyFixtures.fileName(LegacyFixtures.idB): bad])
        let report = try await w.importer().run()
        #expect(report.imported == [idA])
        #expect(report.failures == [LegacyImportFailure(key: key(LegacyFixtures.fileName(LegacyFixtures.idB)), reason: .invalid(.json))])
        let kept = try String(contentsOf: w.legacyFile(LegacyFixtures.idB), encoding: .utf8)
        #expect(kept == bad)
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a file whose id is outside the pattern, or does not match its name, is reported and left alone")
    func idOutsidePattern() async throws {
        let files = ["cv_not-a-uuid.json": #"{"id":"not-a-uuid"}"#,
                     LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(id: LegacyFixtures.idB),
                     "cv_../../escape.json": "{}"]
        let w = try world(files.filter { !$0.key.contains("/") })
        let report = try await w.importer().run()
        #expect(report.imported.isEmpty && report.failures.count == 2)
        #expect(report.failures.allSatisfy { if case .invalid = $0.reason { true } else { false } })
        let left = try FileManager.default.contentsOfDirectory(atPath: w.legacy.path)
        #expect(left.count == 2)
        let listing = try await w.repository.list()
        #expect(listing.cvs.isEmpty)
    }

    @Test("a file too large, and a link, are never read; they stay")
    func hostileFiles() async throws {
        let w = try world([LegacyFixtures.fileName(LegacyFixtures.idA): String(repeating: " ", count: 2_000)])
        let target = w.legacy.appendingPathComponent("elsewhere.json")
        try Data(LegacyFixtures.v101().utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: w.legacyFile(LegacyFixtures.idB), withDestinationURL: target)
        let source = DirectoryLegacyStore(directory: w.legacy, clock: SteppingClock(), maxFileBytes: 1_000)
        let report = try await ImportLegacyStore(source: source, target: w.repository).run()
        #expect(report.imported.isEmpty && report.failures.count == 2)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        let listing = try await w.repository.list()
        #expect(listing.cvs.isEmpty)
    }

    @Test("a legacy store that is not there is an empty import")
    func noLegacyStore() async throws {
        let w = try world([:])
        try FileManager.default.removeItem(at: w.legacy)
        let report = try await w.importer().run()
        #expect(report == LegacyImportReport())
    }

    @Test("legacy files in the new store are neither listed nor quarantined: they are not schema 1")
    func legacyIsNotSchemaOne() async throws {
        let dir = try legacyDir([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(),
                                 LegacyFixtures.fileName(LegacyFixtures.idB): LegacyFixtures.v101()])
        let listing = try await repo(dir).list()
        #expect(listing.cvs.isEmpty && listing.issues.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.filter { $0.hasPrefix("cv_") }.count == 2 && !files.contains { $0.hasSuffix(".cv.json") })
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine").path))
    }

    @Test("a legacy file that holds a schemaVersion is still not read as schema 1 by the store")
    func legacyWithEnvelopeKey() async throws {
        let dir = try legacyDir([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.minimal(#""schemaVersion":1,"revision":1"#)])
        let listing = try await repo(dir).list()
        #expect(listing.cvs.isEmpty && listing.issues.isEmpty)
    }
}

// MARK: - The source is kept until the new copy is verified

private struct FakeSource: LegacyStore {
    let recordsToServe: [LegacyRecord]
    let removed = Recorder()
    func records() async throws(RepositoryError) -> [LegacyRecord] { recordsToServe }
    func remove(_ key: LegacyRecord.Key) async throws(RepositoryError) { removed.add(key.name) }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []
    func add(_ name: String) { lock.lock(); names.append(name); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return names }
}

private struct FakeTarget: LegacyImportTarget {
    let answer: @Sendable (CV) throws(RepositoryError) -> Adoption
    func adopt(_ cv: CV) async throws(RepositoryError) -> Adoption { try answer(cv) }
}

private func oneRecord() -> LegacyRecord {
    let cv = CV(id: idA, revision: 0, createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 200), title: "T",
                personal: PersonalDetails(fullName: "N"), sections: CVSections(), design: nil, language: nil)
    return LegacyRecord(key: key("cv_x.json"), content: .cv(LegacyCV(cv: cv, drops: [])))
}

@Suite("The source is kept until the new copy is verified")
struct LegacySourceKeptTests {
    private func run(_ answer: @escaping @Sendable (CV) throws(RepositoryError) -> Adoption) async throws -> (LegacyImportReport, [String]) {
        let source = FakeSource(recordsToServe: [oneRecord()])
        let report = try await ImportLegacyStore(source: source, target: FakeTarget(answer: answer)).run()
        return (report, source.removed.all)
    }

    @Test("a copy that reads back as what was mapped lets the source go")
    func verified() async throws {
        let (report, removed) = try await run { cv throws(RepositoryError) in .stored(cv.adoptedAsRevisionOne) }
        #expect(report.imported == [idA] && removed == ["cv_x.json"])
    }

    @Test("a copy that reads back as something else keeps the source")
    func differentCopy() async throws {
        let (report, removed) = try await run { cv throws(RepositoryError) in
            var other = cv.adoptedAsRevisionOne
            other.rename("changed on the way")
            return .stored(other)
        }
        #expect(report.imported.isEmpty && removed.isEmpty)
        #expect(report.failures.map(\.reason) == [.didNotReadBack])
    }

    @Test("a write that fails keeps the source")
    func failedWrite() async throws {
        let (report, removed) = try await run { _ throws(RepositoryError) in throw .storeUnavailable(.cannotLock) }
        #expect(removed.isEmpty && report.failures.map(\.reason) == [.notStored(.storeUnavailable(.cannotLock))])
    }

    @Test("a CV that is already stored is not touched, and its source goes: the store holds it")
    func existingCopy() async throws {
        let (report, removed) = try await run { _ throws(RepositoryError) in .existing }
        #expect(report.alreadyStored == [idA] && removed == ["cv_x.json"])
    }

    @Test("a source that cannot be removed is reported, and the run goes on")
    func removalFails() async throws {
        struct Stubborn: LegacyStore {
            func records() async throws(RepositoryError) -> [LegacyRecord] { [oneRecord(), oneRecord()] }
            func remove(_ key: LegacyRecord.Key) async throws(RepositoryError) { throw .unreadable(file: key.name) }
        }
        let target = FakeTarget { cv throws(RepositoryError) in .stored(cv.adoptedAsRevisionOne) }
        let report = try await ImportLegacyStore(source: Stubborn(), target: target).run()
        #expect(report.failures.count == 2 && report.removedSources.isEmpty)
    }

    @Test("a source that cannot be listed fails the run before anything is touched")
    func listingFails() async {
        struct Broken: LegacyStore {
            func records() async throws(RepositoryError) -> [LegacyRecord] { throw .storeUnavailable(.cannotList) }
            func remove(_ key: LegacyRecord.Key) async throws(RepositoryError) {}
        }
        let target = FakeTarget { _ throws(RepositoryError) in .existing }
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) { try await ImportLegacyStore(source: Broken(), target: target).run() }
    }
}
