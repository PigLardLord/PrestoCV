import Foundation

/// The changes made to stored CVs from outside their editor, one CV at a time: a language or a look chosen in the list's
/// export sheet, a rename, a copy, a deletion. Each is a read of the stored CV followed by a write, so two of them on one
/// CV at once lose a field, and a change that is still running when the CV's editor opens writes under it. The queue gives
/// each CV one line: a change starts when the ones queued before it for that CV have ended, and the editor of a CV opens
/// once the CV's line is empty (`settled`).
///
/// A change counts as queued from the moment it is handed over, not from the moment it starts, so there is no gap in which
/// a CV has a change on its way and its line looks empty.
@MainActor
final class StoredCVChangeQueue {
    private var queued: [UUID: Int] = [:]
    private var tails: [UUID: Task<Void, Never>] = [:]

    nonisolated init() {}

    /// Queues `change` behind the changes already queued for the CV, and returns at once.
    /// - Returns: The task that runs the change, for a caller that wants to wait for it.
    @discardableResult
    func enqueue(_ id: UUID, _ change: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let before = tails[id]
        queued[id, default: 0] += 1
        let task = Task { [self] in
            await before?.value
            await change()
            finish(id)
        }
        tails[id] = task
        return task
    }

    /// Returns once every change queued for the CV so far has ended, and so has any queued while this waited.
    func settled(_ id: UUID) async {
        while let last = tails[id] {
            await last.value
        }
    }

    private func finish(_ id: UUID) {
        queued[id, default: 1] -= 1
        guard queued[id] == 0 else { return }
        queued[id] = nil
        tails[id] = nil
    }
}
