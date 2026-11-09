#if DEBUG
import Foundation
import PrestoCVDomain
import PrestoCVWorkflowPorts
import Synchronization

/// The list's editing for the UI test of two failures pending at once: a rename waits until a second rename arrives, and
/// then both fail with `.unavailable`. Every other call goes to the editing it wraps. The second rename fails first, then
/// the first one, so the order in which the person is told depends on the list only. It exists in Debug builds only
/// (`ReleaseHygieneTests`) and is chosen by the composition from a launch argument (`LaunchFixtures`).
final class PairedRenameFailures: CVEditing {
    private let inner: any CVEditing
    /// The rename that waits for its pair
    private let waiting = Mutex<CheckedContinuation<Void, Never>?>(nil)

    init(inner: any CVEditing) {
        self.inner = inner
    }

    func rename(_ cv: CV, to title: String) async throws(EditFailure) -> CV {
        await withCheckedContinuation { (arriving: CheckedContinuation<Void, Never>) in
            let first = waiting.withLock { held -> CheckedContinuation<Void, Never>? in
                defer { held = held == nil ? arriving : nil }
                return held
            }
            if let first {
                first.resume()
                arriving.resume()
            }
        }
        throw .unavailable
    }

    func new() -> CV { inner.new() }
    func load(_ id: CVID) async throws(EditFailure) -> CV { try await inner.load(id) }
    func save(_ cv: CV) async throws(EditFailure) -> CV { try await inner.save(cv) }
    func duplicate(_ cv: CV, title: String) async throws(EditFailure) -> CV { try await inner.duplicate(cv, title: title) }
    func delete(_ cv: CV) async throws(EditFailure) { try await inner.delete(cv) }
    func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting { inner.autosaveWriter(startingFrom: stored) }
}
#endif
