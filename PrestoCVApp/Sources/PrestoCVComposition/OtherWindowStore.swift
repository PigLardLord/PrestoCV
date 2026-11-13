#if DEBUG
import Foundation
import PrestoCVApplication
import PrestoCVDomain
import Synchronization

/// The store for the UI tests of what another window did to the open CV (#402): just before the first write of a stored
/// CV, another window saves that CV or deletes it, once. The write then meets the conflict or the deletion as it would on
/// a device with two windows. Every other call goes to the store it wraps, and so does each write after the first. It
/// exists in Debug builds only (`ReleaseHygieneTests`) and is chosen by the composition from a launch argument
/// (`LaunchFixtures`).
final class OtherWindowStore: CVRepository {
    private let inner: any CVRepository
    private let change: LaunchFixtures.OtherWindow
    /// Whether the other window already changed a CV
    private let changed = Mutex(false)

    init(inner: any CVRepository, change: LaunchFixtures.OtherWindow) {
        self.inner = inner
        self.change = change
    }

    func update(_ cv: CV) async throws(RepositoryError) -> CV {
        let first = changed.withLock { done in
            defer { done = true }
            return !done
        }
        if first {
            let other = try await inner.load(cv.id)
            switch change {
            case .conflict: _ = try await inner.update(other)
            case .deleted: try await inner.delete(cv.id, revision: other.revision)
            }
        }
        return try await inner.update(cv)
    }

    func create(_ cv: CV) async throws(RepositoryError) -> CV { try await inner.create(cv) }
    func load(_ id: CVID) async throws(RepositoryError) -> CV { try await inner.load(id) }
    func list() async throws(RepositoryError) -> CVListing { try await inner.list() }
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) { try await inner.delete(id, revision: revision) }
}
#endif
