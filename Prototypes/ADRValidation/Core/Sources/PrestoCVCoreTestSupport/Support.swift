import Foundation
import Synchronization
import PrestoCVDomain
import PrestoCVApplication

public actor InMemoryCVRepository: CVRepository {
    var store: [CVID: CV] = [:]
    let clock: any TimeSource
    public init(clock: any TimeSource = SteppingClock()) { self.clock = clock }
    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        guard store[cv.id] == nil else { throw .alreadyExists(cv.id) }
        let s = cv.stored(revision: 1, at: clock.now()); store[cv.id] = s; return s
    }
    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        guard let existing = store[cv.id] else { throw .notFound(cv.id) }
        guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
        let s = cv.stored(revision: cv.revision + 1, at: clock.now()); store[cv.id] = s; return s
    }
    public func load(_ id: CVID) async throws(RepositoryError) -> CV { guard let cv = store[id] else { throw .notFound(id) }; return cv }
    public func list() async throws(RepositoryError) -> CVListing {
        CVListing(cvs: store.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: [])
    }
    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        guard let existing = store[id] else { throw .notFound(id) }
        guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
        store[id] = nil
    }
}

/// Each call returns a later instant: deterministic ordering without the wall clock.
public final class SteppingClock: TimeSource {
    private let tick = Mutex(0)
    public init() {}
    public func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000 + Double(tick.withLock { $0 += 1; return $0 })) }
}

public final class SequentialIDGenerator: IDGenerator {
    private let n = Mutex(0)
    public init() {}
    public func next() -> CVID {
        let value = String(n.withLock { $0 += 1; return $0 })
        let hex = String(repeating: "0", count: max(0, 12 - value.count)) + value
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-" + hex) else { preconditionFailure("more than 10^12 ids in a test") }
        return CVID(uuid)
    }
}

public enum CVRepositoryContract {
    public struct Failure: Error, CustomStringConvertible { public let description: String }

    static func expect(_ error: RepositoryError, _ body: () async throws -> Void, _ what: String) async throws {
        do { try await body() } catch let e as RepositoryError {
            guard e == error else { throw Failure(description: "\(what): got \(e)") }
            return
        }
        throw Failure(description: "\(what): expected \(error)")
    }

    /// Every CVRepository adapter must pass this (R10).
    public static func verify(_ repo: some CVRepository) async throws {
        let id = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let v1 = try await repo.create(CV(id: id, fullName: "Ada"))
        guard v1.revision == 1, v1.createdAt != nil, v1.createdAt == v1.updatedAt, try await repo.load(id) == v1 else {
            throw Failure(description: "create/load round trip with timestamps")
        }
        try await expect(.alreadyExists(id), { _ = try await repo.create(CV(id: id, fullName: "Ada")) }, "create twice")

        var edit = v1; edit.rename("Updated")
        let v2 = try await repo.update(edit)
        guard v2.revision == 2, v2.createdAt == v1.createdAt, let u1 = v1.updatedAt, let u2 = v2.updatedAt, u2 > u1,
              try await repo.list().cvs == [v2] else { throw Failure(description: "update must bump revision and updatedAt, keep createdAt, not duplicate") }

        var stale = v1; stale.rename("Stale window")
        try await expect(.conflict(id, storedRevision: 2), { _ = try await repo.update(stale) }, "stale update")
        guard try await repo.load(id).title == "Updated" else { throw Failure(description: "stale update overwrote") }

        // Concurrency on one instance: N updates from the same revision leave exactly one success.
        let successes = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<50 {
                group.addTask { var c = v2; c.rename("Racer \(n)"); return (try? await repo.update(c)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        guard successes == 1 else { throw Failure(description: "\(successes) concurrent updates from one revision succeeded") }
        let v3 = try await repo.load(id)

        try await expect(.conflict(id, storedRevision: 3), { try await repo.delete(id, revision: 1) }, "stale delete")
        try await repo.delete(id, revision: v3.revision)
        try await expect(.notFound(id), { _ = try await repo.update(v3) }, "update after delete must not resurrect")
        guard try await repo.list().cvs.isEmpty else { throw Failure(description: "deleted CV came back") }
        try await expect(.notFound(id), { try await repo.delete(id, revision: 3) }, "delete missing")

        // Listing order: most recently changed first.
        let a = try await repo.create(CV(id: CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!), fullName: "A"))
        let b = try await repo.create(CV(id: CVID(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!), fullName: "B"))
        var a2 = a; a2.rename("touched"); let a3 = try await repo.update(a2)
        guard try await repo.list().cvs.map(\.id) == [a3.id, b.id] else { throw Failure(description: "list must be sorted by last change") }
    }
}
