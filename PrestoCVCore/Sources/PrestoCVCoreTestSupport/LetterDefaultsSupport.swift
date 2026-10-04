import Foundation
import PrestoCVDomain
import PrestoCVApplication

public actor InMemoryLetterDefaultsStore: LetterDefaultsStore {
    var stored = StoredLetterDefaults.unsaved
    let clock: any TimeSource
    public init(clock: any TimeSource = SteppingClock()) { self.clock = clock }

    public func load() async throws(LetterDefaultsError) -> StoredLetterDefaults { stored }

    public func save(_ defaults: LetterDefaults, expectedRevision: Int) async throws(LetterDefaultsError) -> StoredLetterDefaults {
        guard stored.revision == expectedRevision else { throw .conflict(storedRevision: stored.revision) }
        stored = StoredLetterDefaults(defaults: defaults, revision: expectedRevision + 1, updatedAt: clock.now())
        return stored
    }

    public func erase() async throws(LetterDefaultsError) { stored = .unsaved }
}

/// A store whose every operation fails with one error, to test how a use case translates it.
public struct FailingLetterDefaultsStore: LetterDefaultsStore {
    let error: LetterDefaultsError
    public init(_ error: LetterDefaultsError) { self.error = error }
    public func load() async throws(LetterDefaultsError) -> StoredLetterDefaults { throw error }
    public func save(_ defaults: LetterDefaults, expectedRevision: Int) async throws(LetterDefaultsError) -> StoredLetterDefaults { throw error }
    public func erase() async throws(LetterDefaultsError) { throw error }
}

public enum LetterDefaultsStoreContract {
    public typealias Failure = ContractFailure

    private static func defaults(salary: String = "", start: String = "", note: String = "") -> LetterDefaults {
        do { return try LetterDefaults(salaryExpectation: salary, startDate: start, note: note) }
        catch { preconditionFailure("the contract's defaults are valid: \(error)") }
    }

    /// Every LetterDefaultsStore adapter must pass this (R10).
    public static func verify(_ store: some LetterDefaultsStore) async throws {
        guard try await store.load() == .unsaved else { throw Failure(description: "defaults never saved are empty, at revision 0") }
        try await expect(.conflict(storedRevision: 0), { _ = try await store.save(defaults(salary: "55k"), expectedRevision: 3) }, "a save over a revision that is not stored")
        guard try await store.load() == .unsaved else { throw Failure(description: "a refused save stored something") }

        let v1 = try await store.save(defaults(salary: "55k", start: "April", note: "Remote"), expectedRevision: 0)
        guard v1.revision == 1, v1.updatedAt != nil, v1.defaults == defaults(salary: "55k", start: "April", note: "Remote"), try await store.load() == v1 else {
            throw Failure(description: "the first save expects no file, and round-trips with its time")
        }
        try await expect(.conflict(storedRevision: 1), { _ = try await store.save(defaults(salary: "70k"), expectedRevision: 0) }, "a first save over a file")

        let v2 = try await store.save(defaults(salary: "60k", start: "April", note: "Remote"), expectedRevision: 1)
        guard v2.revision == 2, let t1 = v1.updatedAt, let t2 = v2.updatedAt, t2 > t1, try await store.load() == v2 else {
            throw Failure(description: "a save must bump the revision and the time")
        }
        try await expect(.conflict(storedRevision: 2), { _ = try await store.save(defaults(salary: "stale"), expectedRevision: 1) }, "stale save")
        guard try await store.load().defaults.salaryExpectation == "60k" else { throw Failure(description: "a stale save overwrote") }

        // A cleared default is saved as cleared, and the others stay.
        let cleared = try await store.save(defaults(salary: "60k", start: "April"), expectedRevision: 2)
        guard cleared.defaults.note.isEmpty, cleared.defaults.startDate == "April", try await store.load() == cleared else {
            throw Failure(description: "a cleared default must stay cleared")
        }

        // Concurrency on one instance: N saves from the same revision leave exactly one success.
        let successes = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<50 { group.addTask { (try? await store.save(defaults(note: "Racer \(n)"), expectedRevision: 3)) != nil } }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        guard successes == 1 else { throw Failure(description: "\(successes) concurrent saves from one revision succeeded") }

        try await store.erase()
        guard try await store.load() == .unsaved else { throw Failure(description: "erased defaults must read as never saved") }
        try await expect(.conflict(storedRevision: 0), { _ = try await store.save(defaults(salary: "x"), expectedRevision: 4) }, "a save over erased defaults must not resurrect")
        try await store.erase()
        guard try await store.save(defaults(salary: "again"), expectedRevision: 0).revision == 1 else { throw Failure(description: "defaults can be saved again after an erase") }
    }
}
