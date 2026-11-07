import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// The in-memory double runs the same contract as the file store (R10).
private func harness(_ store: InMemoryCVRepository) -> MaintenanceHarness {
    MaintenanceHarness(
        open: { store },
        plantCorrupt: { id in await store.plantCorrupt(id) },
        plantQuarantined: { id, cv, enteredAt in await store.plantQuarantined(id, cv: cv, enteredAt: enteredAt) })
}

@Suite("The in-memory store's maintenance, under the contract")
struct InMemoryMaintenanceContractTests {
    @Test("a corrupt file listed once is still in quarantined() on a new instance")
    func survivesRestart() async throws {
        try await CVStoreMaintenanceContract.corruptFileStaysQuarantinedAcrossInstances(harness(InMemoryCVRepository()))
    }

    @Test("restore returns the CV and removes the quarantined copy; a second restore finds nothing")
    func restores() async throws { try await CVStoreMaintenanceContract.restoreMovesTheCVBack(harness(InMemoryCVRepository())) }

    @Test("restore refuses ../x.cv.json, a name with a slash and a name not in the pattern")
    func refusesNames() async throws { try await CVStoreMaintenanceContract.restoreRefusesBadNames(harness(InMemoryCVRepository())) }

    @Test("restore of a CV whose id is stored fails with alreadyExists and keeps both")
    func refusesStoredID() async throws { try await CVStoreMaintenanceContract.restoreRefusesAStoredID(harness(InMemoryCVRepository())) }

    @Test("purge: 29 days kept, 31 days removed, the cutoff computed from the injected clock")
    func purges() async throws { try await CVStoreMaintenanceContract.purgeCountsFromTheClock(harness(InMemoryCVRepository())) }

    @Test("restore, purge, list and erase race without a lost or duplicated CV")
    func races() async throws { try await CVStoreMaintenanceContract.raceKeepsEveryCVOnce(harness(InMemoryCVRepository())) }

    @Test("eraseAll racing 10 updates and 10 creates: no write succeeds after the erase, and the count adds up")
    func eraseAllRaces() async throws { try await CVStoreMaintenanceContract.eraseAllOrdersWithWrites(harness(InMemoryCVRepository())) }

    @Test("eraseAll removes valid, corrupt and quarantined files, and a second call nothing")
    func erasesAll() async throws { try await CVStoreMaintenanceContract.eraseAllRemovesEveryKind(harness(InMemoryCVRepository())) }
}
