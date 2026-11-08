import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

private let idA = CVID(UUID(uuidString: LegacyFixtures.idA)!)

/// The real directory store, with the one call the test breaks.
private struct Faulty: LegacyStore {
    enum Fault: Sendable { case none, removalThrows, removalChanged, listingThrows }
    let inner: DirectoryLegacyStore, fault: Fault
    func records() async throws(RepositoryError) -> [LegacyRecord] {
        if fault == .listingThrows { throw .storeUnavailable(.cannotList) }
        return try await inner.records()
    }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        switch fault {
        case .removalThrows: throw .unreadable(file: key.name)
        case .removalChanged: return .changed
        default: return try await inner.remove(key, ifUnchanged: version)
        }
    }
}

private struct World {
    let legacy: URL, store: URL, repository: FileCVRepository
    var directoryStore: DirectoryLegacyStore { DirectoryLegacyStore(directory: legacy, clock: SteppingClock()) }
    var ledger: URL { store.appendingPathComponent(FileCVRepository.legacyLedgerName) }
    var sourceName: String { LegacyFixtures.fileName(LegacyFixtures.idA) }
    var sourceExists: Bool { FileManager.default.fileExists(atPath: legacy.appendingPathComponent(sourceName).path) }

    /// Imports the one source and keeps it (the run that leaves a source behind).
    func importKeepingSource() async throws {
        let report = try await ImportLegacyStore(source: directoryStore, target: repository, removingVerifiedSources: false).run()
        #expect(report.imported == [idA])
    }
    func erase(_ fault: Faulty.Fault) async throws(MaintenanceError) -> EraseEverythingOutcome {
        try await EraseEverything(maintenance: repository, legacy: Faulty(inner: directoryStore, fault: fault))()
    }
    func importAgain() async throws -> LegacyImportReport {
        try await ImportLegacyStore(source: directoryStore, target: repository).run()
    }
}

private func world() throws -> World {
    let legacy = try legacyDir([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10()]), store = tempDir()
    return World(legacy: legacy, store: store, repository: repo(store))
}

@Suite("Erasing everything while legacy sources remain")
struct EraseEverythingLegacyTests {
    @Test("a source that cannot be removed keeps the ledger, and the erased CV is not imported again")
    func removalThrows() async throws {
        let w = try world(); try await w.importKeepingSource()
        let outcome = try await w.erase(.removalThrows)
        guard case .partial(_, let remaining) = outcome else { Issue.record("expected partial, got \(outcome)"); return }
        #expect(Set(remaining) == [RemainingItem(kind: .legacySource, name: w.sourceName),
                                   RemainingItem(kind: .ledger, name: FileCVRepository.legacyLedgerName)])
        #expect(w.sourceExists)
        let report = try await w.importAgain()
        #expect(report.imported.isEmpty && report.alreadyStored == [idA])
        #expect(try await w.repository.list().cvs.isEmpty)
    }

    @Test("a source that changed keeps the ledger, and the erased CV is not imported again")
    func removalChanged() async throws {
        let w = try world(); try await w.importKeepingSource()
        let outcome = try await w.erase(.removalChanged)
        guard case .partial(_, let remaining) = outcome else { Issue.record("expected partial, got \(outcome)"); return }
        #expect(remaining.contains(RemainingItem(kind: .ledger, name: FileCVRepository.legacyLedgerName)))
        _ = try await w.importAgain()
        #expect(try await w.repository.list().cvs.isEmpty)
    }

    @Test("a listing that throws still erases the store, keeps the ledger and throws; a later import does not bring the CV back")
    func listingThrows() async throws {
        let w = try world(); try await w.importKeepingSource()
        await #expect(throws: MaintenanceError.unavailable) { _ = try await w.erase(.listingThrows) }
        #expect(!FileManager.default.fileExists(atPath: w.store.appendingPathComponent(fileNameOf(idA)).path))
        #expect(FileManager.default.fileExists(atPath: w.ledger.path))
        _ = try await w.importAgain()
        #expect(try await w.repository.list().cvs.isEmpty)
    }

    @Test("when every source is gone the ledger goes too, and the outcome is erased")
    func happyPath() async throws {
        let w = try world(); try await w.importKeepingSource()
        let outcome = try await w.erase(.none)
        guard case .erased = outcome else { Issue.record("expected erased, got \(outcome)"); return }
        #expect(!w.sourceExists)
        #expect(!FileManager.default.fileExists(atPath: w.ledger.path))
        #expect(try await w.repository.list().cvs.isEmpty)
    }
}

private func fileNameOf(_ id: CVID) -> String { fileName(id) }
