import Foundation
import Synchronization
import PrestoCVDomain
import PrestoCVApplication

/// Holds tasks until `open()`, so that a race starts when the test says and no sleep is needed.
public actor Gate {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    public init() {}
    public func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    public func open() {
        isOpen = true
        let all = waiting; waiting = []
        for continuation in all { continuation.resume() }
    }
}

/// A clock that says one instant.
public struct FixedTimeSource: TimeSource {
    public let instant: Date
    public init(_ instant: Date) { self.instant = instant }
    public func now() -> Date { instant }
}

/// What a store needs to give the maintenance contract: new instances over the same store, and the files that only the store
/// itself knows how to make (R10: one suite, every adapter).
public struct MaintenanceHarness: Sendable {
    public typealias Store = CVRepository & CVStoreMaintenance
    /// A new instance over the same store: the process restarted, or another process.
    public let open: @Sendable () -> any Store
    /// A stored file that does not decode, so that the next listing sets it aside.
    public let plantCorrupt: @Sendable (CVID) async throws -> Void
    /// A file in the quarantine entered at `enteredAt`: the CV (restorable) or, with nil, bytes that do not decode. Returns its name.
    public let plantQuarantined: @Sendable (CVID, CV?, Date) async throws -> String
    /// The importer's adoption of a legacy CV into the store, which records the CV in the import ledger.
    public let adopt: @Sendable (CV) async throws -> Adoption
    public init(open: @escaping @Sendable () -> any Store,
                plantCorrupt: @escaping @Sendable (CVID) async throws -> Void,
                plantQuarantined: @escaping @Sendable (CVID, CV?, Date) async throws -> String,
                adopt: @escaping @Sendable (CV) async throws -> Adoption) {
        self.open = open; self.plantCorrupt = plantCorrupt; self.plantQuarantined = plantQuarantined; self.adopt = adopt
    }
}

/// Every `CVStoreMaintenance` adapter must pass these (R10). Each check is one behaviour; the suites call them one by one.
public enum CVStoreMaintenanceContract {
    public struct Failure: Error, CustomStringConvertible { public let description: String }

    static func id(_ n: Int) -> CVID { CVID(UUID(uuidString: String(format: "%08X-0000-4000-8000-000000000001", n))!) }
    static let epoch = Date(timeIntervalSince1970: 1_800_000_000)
    static func cv(_ id: CVID) -> CV { CV(id: id, personal: PersonalDetails(fullName: "Ada")).stored(revision: 1, at: epoch) }
    static func name(_ id: CVID) -> String { id.raw.uuidString + ".cv.json" }

    static func check(_ ok: Bool, _ what: @autoclosure () -> String) throws { if !ok { throw Failure(description: what()) } }

    static func expect(_ error: RepositoryError, _ what: String, _ body: () async throws -> Void) async throws {
        do { try await body() } catch let e as RepositoryError {
            try check(e == error, "\(what): got \(e), expected \(error)")
            return
        }
        throw Failure(description: "\(what): expected \(error)")
    }

    // MARK: Quarantine

    /// A corrupt file listed once is still in `quarantined()` on a new instance.
    public static func corruptFileStaysQuarantinedAcrossInstances(_ h: MaintenanceHarness) async throws {
        let a = id(1)
        try await h.plantCorrupt(a)
        let first = h.open()
        let issues = try await first.list().issues
        try check(issues.count == 1, "the listing reports the corrupt file once: \(issues)")
        let listed = try await first.quarantined()
        try check(listed.map(\.id) == [a] && listed.map(\.name) == [name(a)] && listed.map(\.reason) == [.corrupt], "quarantined(): \(listed)")
        try check(try await h.open().quarantined() == listed, "a new instance lists the same file")
        try check(try await h.open().list().issues.isEmpty, "the file is not reported again")
    }

    /// `restore` returns the CV and removes the quarantined copy; a second restore finds the CV already back.
    public static func restoreMovesTheCVBack(_ h: MaintenanceHarness) async throws {
        let a = id(2), store = h.open()
        let entered = try await h.plantQuarantined(a, cv(a), epoch)
        let restored = try await store.restore(quarantined: entered)
        try check(restored.id == a, "restore returns the CV")
        try check(try await store.quarantined().isEmpty, "the quarantined copy is gone")
        try check(try await store.list().cvs.map(\.id) == [a], "the CV is listed")
        try await expect(.alreadyExists(a), "second restore") { _ = try await store.restore(quarantined: entered) }
    }

    /// A name that leaves the quarantine, or is not in the pattern, is refused and nothing changes.
    public static func restoreRefusesBadNames(_ h: MaintenanceHarness) async throws {
        let a = id(3), store = h.open()
        let entered = try await h.plantQuarantined(a, cv(a), epoch)
        let hostile = ["../x.cv.json", "a/b.cv.json", "x.cv.json", "\(a.raw.uuidString).cv.json\n", "1~../../\(name(a))", "", "~\(name(a))",
                       "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.cv.json", "\(name(a))/", "../\(name(a))"]
        for bad in hostile {
            try await expect(.invalidName(bad), "restore of \(bad.debugDescription)") { _ = try await store.restore(quarantined: bad) }
        }
        try check(try await store.quarantined().map(\.name) == [entered], "the quarantine is unchanged")
        try check(try await store.list().cvs.isEmpty, "the store is unchanged")
    }

    /// Restoring a CV whose id is stored fails and keeps both.
    public static func restoreRefusesAStoredID(_ h: MaintenanceHarness) async throws {
        let a = id(4), store = h.open()
        let stored = try await store.create(CV(id: a, personal: PersonalDetails(fullName: "Stored")))
        let entered = try await h.plantQuarantined(a, cv(a), epoch)
        try await expect(.alreadyExists(a), "restore over a stored CV") { _ = try await store.restore(quarantined: entered) }
        try check(try await store.load(a) == stored, "the stored CV is untouched")
        try check(try await store.quarantined().map(\.name) == [entered], "the quarantined copy stays")
    }

    // MARK: Retention

    /// 29 days kept, 31 removed; the cutoff comes from the injected clock.
    public static func purgeCountsFromTheClock(_ h: MaintenanceHarness) async throws {
        let day: TimeInterval = 86_400, now = epoch.addingTimeInterval(1_000 * day), store = h.open()
        let young = try await h.plantQuarantined(id(5), nil, now.addingTimeInterval(-29 * day))
        _ = try await h.plantQuarantined(id(6), nil, now.addingTimeInterval(-31 * day))
        let purge = PurgeExpiredQuarantine(maintenance: store, time: FixedTimeSource(now))
        try check(try await purge() == 1, "one file is past the retention")
        try check(try await store.quarantined().map(\.name) == [young], "the 29-day file stays")
        try check(try await PurgeExpiredQuarantine(maintenance: store, time: FixedTimeSource(now.addingTimeInterval(-10 * day)))() == 0, "an earlier clock removes nothing")
        try check(try await PurgeExpiredQuarantine(maintenance: store, time: FixedTimeSource(now.addingTimeInterval(2 * day)))() == 1, "a later clock removes the rest")
    }

    // MARK: Concurrency (a gate releases every task together; no sleeps)

    /// Restore, purge, list and erase race on two instances: a CV is stored once, or quarantined once, or nowhere; never both.
    public static func raceKeepsEveryCVOnce(_ h: MaintenanceHarness) async throws {
        let rounds = 8, a = h.open(), b = h.open(), gate = Gate()
        let bystander = id(100)
        _ = try await a.create(CV(id: bystander, personal: PersonalDetails(fullName: "Bystander")))
        var names: [(id: CVID, name: String)] = []
        for n in 0..<rounds { names.append((id(10 + n), try await h.plantQuarantined(id(10 + n), cv(id(10 + n)), epoch))) }
        let tolerated: [RepositoryError] = []
        let unexpected = await withTaskGroup(of: String?.self) { group in
            for (round, (cvID, entered)) in names.enumerated() {
                // Two restores of one name (and in every other round an erase), a purge of everything, a listing.
                group.addTask { await attempt(gate, tolerating: [.unreadable(file: entered), .alreadyExists(cvID)]) { _ = try await a.restore(quarantined: entered) } }
                group.addTask { await attempt(gate, tolerating: [.unreadable(file: entered), .alreadyExists(cvID)]) { _ = try await b.restore(quarantined: entered) } }
                if round % 2 == 0 {
                    group.addTask { await attempt(gate, tolerating: tolerated) { try await b.erase(cvID) } }
                }
            }
            group.addTask { await attempt(gate, tolerating: tolerated) { _ = try await a.purgeQuarantine(olderThan: .distantFuture) } }
            group.addTask { await attempt(gate, tolerating: tolerated) { _ = try await b.list() } }
            await gate.open()
            var bad: [String] = []
            for await outcome in group { if let outcome { bad.append(outcome) } }
            return bad
        }
        try check(unexpected.isEmpty, "unexpected errors: \(unexpected)")
        let live = try await a.list().cvs.map(\.id), held = try await a.quarantined().map(\.id)
        for cvID in names.map(\.id) {
            let places = live.filter { $0 == cvID }.count + held.filter { $0 == cvID }.count
            try check(places <= 1, "\(cvID.raw) is in \(places) places")
        }
        try check(live.filter { $0 == bystander }.count == 1, "the bystander CV is stored once")
    }

    /// `eraseAll` and writes race: no write succeeds after the erase returned, and every file is either erased or left once.
    public static func eraseAllOrdersWithWrites(_ h: MaintenanceHarness) async throws {
        let a = h.open(), b = h.open(), gate = Gate(), seeded = id(200)
        let stored = try await a.create(CV(id: seeded, personal: PersonalDetails(fullName: "Seeded")))
        // Each task answers what it achieved: the files an erase removed, or the CV a create stored.
        let outcomes = await withTaskGroup(of: (erased: Int, created: CVID?).self) { group in
            group.addTask {
                await gate.wait()
                return (erased: (try? await a.eraseAll(keepingLedger: false))?.erased ?? 0, created: nil)
            }
            for n in 0..<10 {
                group.addTask {
                    await gate.wait()
                    var edit = stored; edit.rename("Racer \(n)")
                    _ = try? await b.update(edit)
                    return (erased: 0, created: nil)
                }
                group.addTask {
                    await gate.wait()
                    let new = id(300 + n)
                    let made = (try? await b.create(CV(id: new, personal: PersonalDetails(fullName: "New")))) != nil
                    return (erased: 0, created: made ? new : nil)
                }
            }
            await gate.open()
            return await group.reduce(into: []) { $0.append($1) }
        }
        let erasedCount = outcomes.reduce(0) { $0 + $1.erased }, made = outcomes.compactMap(\.created)
        let live = try await a.list().cvs.map(\.id)
        try check(!live.contains(seeded), "the CV that existed before the erase is gone")
        try check(Set(live).isSubset(of: Set(made)), "only a CV created during the race can remain: \(live)")
        try check(erasedCount + live.count == 1 + made.count, "every file is erased once or still there: erased \(erasedCount), left \(live.count), made \(made.count)")
        var late = stored; late.rename("Late")
        try await expect(.notFound(seeded), "an update after the erase") { _ = try await b.update(late) }
        try check(try await b.eraseAll(keepingLedger: false).erased == live.count, "a second erase removes what the race left")
        try check(try await b.eraseAll(keepingLedger: false) == EraseAllReport(erased: 0), "and a third nothing")
    }

    // MARK: Erase all

    /// Valid, corrupt and quarantined files all go; a second call finds nothing.
    public static func eraseAllRemovesEveryKind(_ h: MaintenanceHarness) async throws {
        let store = h.open()
        try check(try await store.eraseAll(keepingLedger: false) == EraseAllReport(erased: 0), "an empty store has nothing to erase")
        _ = try await store.create(CV(id: id(400), personal: PersonalDetails(fullName: "Valid")))
        try await h.plantCorrupt(id(401))
        _ = try await h.plantQuarantined(id(402), cv(id(402)), epoch)
        _ = try await h.plantQuarantined(id(403), nil, epoch)
        let report = try await store.eraseAll(keepingLedger: false)
        try check(report == EraseAllReport(erased: 4), "erase all: \(report)")
        let listing = try await store.list(), held = try await store.quarantined()
        try check(listing.cvs.isEmpty && listing.issues.isEmpty && held.isEmpty, "nothing is left")
        try check(try await store.eraseAll(keepingLedger: false) == EraseAllReport(erased: 0), "a second erase removes nothing")
    }

    /// The import ledger outlives an erase that keeps it: the CV is gone, and a second adoption of it stores nothing. An
    /// erase that does not keep it removes the ledger, and the CV can be adopted again.
    public static func eraseAllKeepsTheLedgerOnRequest(_ h: MaintenanceHarness) async throws {
        let store = h.open(), legacy = cv(id(410))
        guard case .stored = try await h.adopt(legacy) else { throw Failure(description: "the first adoption stores the CV") }
        let kept = try await store.eraseAll(keepingLedger: true)
        try check(kept.remaining.map(\.kind) == [.ledger], "the kept ledger is named: \(kept)")
        try check(try await store.list().cvs.isEmpty, "the CV is erased")
        try check(try await h.adopt(legacy) == .existing, "a second adoption of the erased CV is existing")
        try check(try await store.list().cvs.isEmpty, "and stores nothing")
        let again = try await store.eraseAll(keepingLedger: true)
        try check(again.erased == 0 && again.remaining.map(\.kind) == [.ledger], "a repeat keeps it and removes nothing: \(again)")
        let gone = try await store.eraseAll(keepingLedger: false)
        try check(gone.remaining.isEmpty && gone.erased == 1, "without keeping it, the ledger goes: \(gone)")
        guard case .stored = try await h.adopt(legacy) else { throw Failure(description: "with the ledger gone the CV is adopted again") }
    }
}

/// Waits at the gate, runs `body`, and answers what went wrong that the caller did not expect.
private func attempt(_ gate: Gate, tolerating: [RepositoryError], _ body: () async throws -> Void) async -> String? {
    await gate.wait()
    do { try await body(); return nil } catch let e as RepositoryError { return tolerating.contains(e) ? nil : "\(e)" } catch { return "\(error)" }
}
