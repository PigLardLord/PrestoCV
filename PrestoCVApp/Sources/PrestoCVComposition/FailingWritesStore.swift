#if DEBUG
import Foundation
import PrestoCVApplication
import PrestoCVDomain
import Synchronization

/// The store for the UI tests of a save that fails (#408): the first `count` writes (a creation, a replacement or a
/// deletion) fail with `RepositoryError.writeFailed`, and nothing is stored; every write after them, and every read, goes
/// to the store it wraps. A count that never runs out never succeeds. It exists in Debug builds only
/// (`ReleaseHygieneTests`) and is chosen by the composition from a launch argument (`LaunchFixtures`).
final class FailingWritesStore: CVRepository {
    private let inner: any CVRepository
    /// The writes that still fail
    private let remaining: Mutex<Int>

    init(inner: any CVRepository, count: Int) {
        self.inner = inner
        remaining = Mutex(count)
    }

    func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try failIfDue(cv.id)
        return try await inner.create(cv)
    }

    func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try failIfDue(cv.id)
        return try await inner.update(cv)
    }

    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        try failIfDue(id)
        try await inner.delete(id, revision: revision)
    }

    func load(_ id: CVID) async throws(RepositoryError) -> CV { try await inner.load(id) }
    func list() async throws(RepositoryError) -> CVListing { try await inner.list() }

    /// Spends one of the failing writes, if any is left.
    private func failIfDue(_ id: CVID) throws(RepositoryError) {
        let fails = remaining.withLock { left in
            guard left > 0 else { return false }
            left -= 1
            return true
        }
        // `EIO`, the error of a device that cannot write
        if fails { throw .writeFailed(file: "\(id.raw.uuidString).cv.json", cause: FailureCause(domain: .posix, code: 5)) }
    }
}
#endif
