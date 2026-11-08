import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// A store that answers every call with one error, or with the values it was given.
private struct Failing: CVRepository, CVStoreMaintenance {
    let error: RepositoryError
    func create(_ cv: CV) async throws(RepositoryError) -> CV { throw error }
    func update(_ cv: CV) async throws(RepositoryError) -> CV { throw error }
    func load(_ id: CVID) async throws(RepositoryError) -> CV { throw error }
    func list() async throws(RepositoryError) -> CVListing { throw error }
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) { throw error }
    func quarantined() async throws(RepositoryError) -> [QuarantinedFile] { throw error }
    func restore(quarantined name: String) async throws(RepositoryError) -> CV { throw error }
    func erase(_ id: CVID) async throws(RepositoryError) { throw error }
    func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int { throw error }
    func eraseAll(keepingLedger: Bool) async throws(RepositoryError) -> EraseAllReport { throw error }
}

private let someID = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
private let cause = FailureCause(domain: .posix, code: 13)

@Suite("Maintenance use cases")
struct MaintenanceUseCaseTests {
    static let table: [(RepositoryError, MaintenanceError)] = [
        (.invalidName("x"), .invalidName),
        (.alreadyExists(someID), .alreadyExists),
        (.corrupt(file: "x"), .corrupt),
        (.upgradeRequired(file: "x", version: 3), .upgradeRequired),
        (.unreadable(file: "x"), .unreadable),
        (.tooLarge(file: "x"), .tooLarge),
        (.storeUnavailable(.cannotList), .unavailable),
        (.storeUnavailable(.notADirectory), .unavailable),
        (.storeUnavailable(.cannotLock), .unavailable),
        (.writeFailed(file: "x", cause: cause), .failed),
        (.wouldNotReadBack(file: "x"), .failed),
        (.notFound(someID), .failed),
        (.conflict(someID, storedRevision: 2), .failed),
    ]

    @Test("every use case maps each RepositoryError to one MaintenanceError", arguments: table)
    func mapping(repositoryError: RepositoryError, expected: MaintenanceError) async throws {
        let store = Failing(error: repositoryError)
        await #expect(throws: expected) { _ = try await ReviewStoreIssues(repository: store, maintenance: store)() }
        await #expect(throws: expected) { _ = try await RestoreQuarantinedCV(maintenance: store)(quarantined: "x") }
        await #expect(throws: expected) { try await EraseCV(maintenance: store)(someID) }
        await #expect(throws: expected) { _ = try await PurgeExpiredQuarantine(maintenance: store, time: FixedTimeSource(Date()))() }
        await #expect(throws: expected) { _ = try await EraseEverything(maintenance: store, legacy: NoLegacy())() }
    }

    @Test("the review lists the issues and the quarantine in one value, listing first")
    func review() async throws {
        let store = InMemoryCVRepository()
        await store.plantCorrupt(someID)
        let review = try await ReviewStoreIssues(repository: store, maintenance: store)()
        #expect(review.issues == [.corrupt(file: "\(someID.raw.uuidString).cv.json", reason: "does not decode")])
        #expect(review.quarantined.map(\.id) == [someID])
    }

    @Test("the retention is 30 days")
    func retention() { #expect(QuarantineRetention.days == 30 && QuarantineRetention.seconds == 2_592_000) }

    @Test("erase everything with nothing left says erased(0)")
    func nothing() async throws {
        #expect(try await EraseEverything(maintenance: InMemoryCVRepository(), legacy: NoLegacy())() == .erased(0))
    }
}

private struct NoLegacy: LegacyStore {
    func records() async throws(RepositoryError) -> [LegacyRecord] { [] }
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval { .alreadyGone }
}
