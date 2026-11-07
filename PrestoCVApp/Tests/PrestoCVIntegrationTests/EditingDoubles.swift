import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// The in-memory repository, with what the editing tests need besides: how many writes reached it, the issues a listing
/// reports, and a failure every call can be told to fail with.
actor RepositorySpy: CVRepository {
    private let inner = InMemoryCVRepository()
    private(set) var creates = 0, updates = 0, deletes = 0
    var issues: [StoreIssue] = []
    var failure: RepositoryError?

    func fail(with error: RepositoryError?) { failure = error }
    func report(_ issues: [StoreIssue]) { self.issues = issues }

    func create(_ cv: CV) async throws(RepositoryError) -> CV {
        creates += 1
        if let failure { throw failure }
        return try await inner.create(cv)
    }

    func update(_ cv: CV) async throws(RepositoryError) -> CV {
        updates += 1
        if let failure { throw failure }
        return try await inner.update(cv)
    }

    func load(_ id: CVID) async throws(RepositoryError) -> CV {
        if let failure { throw failure }
        return try await inner.load(id)
    }

    func list() async throws(RepositoryError) -> CVListing {
        if let failure { throw failure }
        let listing = try await inner.list()
        return CVListing(cvs: listing.cvs, issues: issues)
    }

    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        deletes += 1
        if let failure { throw failure }
        try await inner.delete(id, revision: revision)
    }

    /// Writes that reached the store, whatever came of them.
    var writes: Int { creates + updates + deletes }
}

enum Invented {
    static func cv(_ name: String, id: CVID) -> CV {
        CV(id: id, personal: PersonalDetails(fullName: name))
    }

    static func design(_ design: String, palette: String? = nil, fonts: String? = nil) -> DesignChoice {
        guard let choice = DesignChoice(design: design, palette: palette, fonts: fonts) else { preconditionFailure("design choice") }
        return choice
    }
}

/// A repository whose next write can be held inside the store until the test releases it, and told to commit or to fail
/// then. It counts the writes inside the store at the same time, so a test can see two overlap. No sleeps, no clock.
actor GatedRepository: CVRepository {
    private let inner = InMemoryCVRepository()
    private var holdNext = false
    private var gate: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    private var failWhenReleased = false
    private var active = 0
    private(set) var peak = 0, entries = 0

    func holdNextWrite() { holdNext = true }

    /// Returns when a write is held in the store.
    func untilHeld() async {
        if gate != nil { return }
        await withCheckedContinuation { entered = $0 }
    }

    /// Lets the held write go on: it commits, or it fails with the store unavailable.
    func release(failing: Bool) {
        failWhenReleased = failing
        gate?.resume()
        gate = nil
    }

    private func enter() async throws(RepositoryError) {
        active += 1; entries += 1; peak = max(peak, active)
        if holdNext {
            holdNext = false
            await withCheckedContinuation { continuation in
                gate = continuation
                entered?.resume()
                entered = nil
            }
            if failWhenReleased { failWhenReleased = false; active -= 1; throw .storeUnavailable(.cannotLock) }
        }
    }

    func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try await enter()
        defer { active -= 1 }
        return try await inner.create(cv)
    }

    func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try await enter()
        defer { active -= 1 }
        return try await inner.update(cv)
    }

    func load(_ id: CVID) async throws(RepositoryError) -> CV { try await inner.load(id) }
    func list() async throws(RepositoryError) -> CVListing { try await inner.list() }
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) { try await inner.delete(id, revision: revision) }
}
