import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// The real directory store, paused once its records are read: the import holds them while the test erases everything.
private struct PausingAfterReading: LegacyStore {
    let inner: DirectoryLegacyStore, read: Gate, release: Gate
    func records() async throws(RepositoryError) -> [LegacyRecord] {
        let records = try await inner.records()
        await read.open()
        await release.wait()
        return records
    }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        try await inner.remove(key, ifUnchanged: version)
    }
}

@Suite("Erasing everything while an import is under way")
struct EraseDuringImportTests {
    /// Starts an import on one repository instance, pauses it after it read the legacy records, erases everything through a
    /// second instance, then lets the import finish.
    private func importAcrossAnErase(store: URL) async throws -> LegacyImportReport {
        let legacy = try legacyDir([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10()])
        let read = Gate(), release = Gate()
        let pausing = PausingAfterReading(inner: DirectoryLegacyStore(directory: legacy, clock: SteppingClock()), read: read, release: release)
        let importing = Task { try await ImportLegacyStore(source: pausing, target: repo(store), removingVerifiedSources: true).run() }
        await read.wait()
        let outcome = try await EraseEverything(maintenance: repo(store), legacy: DirectoryLegacyStore(directory: legacy, clock: SteppingClock()))()
        guard case .erased = outcome else { Issue.record("the erase did not finish: \(outcome)"); return LegacyImportReport() }
        await release.open()
        return try await importing.value
    }

    private func expectNothingCameBack(in store: URL, _ report: LegacyImportReport) async throws {
        #expect(try await repo(store).list().cvs.isEmpty, "a CV came back after the erase")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: store.path)) ?? []
        #expect(!names.contains(FileCVRepository.legacyLedgerName), "the ledger came back after the erase")
        #expect(!names.contains { $0.hasSuffix(FileCVRepository.stagedSuffix) || $0.hasSuffix(FileCVRepository.suffix) }, "files came back: \(names)")
        #expect(report.storeErased && report.imported.isEmpty && report.removedSources.isEmpty && report.failures.isEmpty, "\(report)")
    }

    @Test("an import paused before it stores anything stores nothing once the store is erased")
    func storePresent() async throws {
        let store = tempDir()
        _ = try await repo(store).create(named("Kept", id: id2))   // the store exists before the import
        let report = try await importAcrossAnErase(store: store)
        try await expectNothingCameBack(in: store, report)
    }

    @Test("an import that started before the store existed stores nothing once the store is erased")
    func storeAbsent() async throws {
        let store = tempDir()
        let report = try await importAcrossAnErase(store: store)
        try await expectNothingCameBack(in: store, report)
    }
}
