import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// A `CVRepository` that keeps its CVs in memory, for the use cases and the contract tests. A store in memory has no files,
/// so it has no corrupt file and no quarantine: those are tested on the file repository.
public actor InMemoryCVRepository: CVRepository {
    private var storedCVs: [CVID: CV] = [:]
    private let clock: any TimeSource

    /// - Parameter clock: Where the timestamps come from. By default each call gives a later instant.
    public init(clock: any TimeSource = SteppingClock()) { self.clock = clock }

    /// Stores a never-saved CV as revision 1. Fails with `alreadyExists` when a CV of that identity is stored.
    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        guard storedCVs[cv.id] == nil else { throw .alreadyExists(cv.id) }
        return keep(cv.stored(revision: 1, at: clock.now()))
    }

    /// Replaces the stored CV if it is at `cv.revision`. Fails with `notFound` or `conflict`.
    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        guard let existing = storedCVs[cv.id] else { throw .notFound(cv.id) }
        guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
        return keep(cv.stored(revision: cv.revision + 1, at: clock.now()))
    }

    /// Loads the stored CV. Fails with `notFound`.
    public func load(_ id: CVID) async throws(RepositoryError) -> CV {
        guard let cv = storedCVs[id] else { throw .notFound(id) }
        return cv
    }

    /// The stored CVs, most recently changed first, with no issue.
    public func list() async throws(RepositoryError) -> CVListing {
        CVListing(cvs: storedCVs.values.mostRecentlyChangedFirst(), issues: [])
    }

    /// Deletes the stored CV if it is at `revision`. Fails with `notFound` or `conflict`.
    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        guard let existing = storedCVs[id] else { throw .notFound(id) }
        guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
        storedCVs[id] = nil
    }

    private func keep(_ cv: CV) -> CV {
        storedCVs[cv.id] = cv
        return cv
    }
}
