import Foundation

/// The notice of the CV an editor shows, kept with the CV once the store holds it, until the person dismisses it
/// (ADR 0027). Only a notice that is kept (`EditorNotice.isKept`, the import's) is written.
///
/// Its writes run one after the other, in the order they were asked for: a dismissal is never undone by a keep asked for
/// before it, whatever the priority of the tasks that ask. The autosave's write tells it the CV is stored, and needs
/// nothing of the editor for it, so that a write that ends after the editor is gone still keeps the notice.
///
/// A keep that fails is reported to the autosave's write, so the editor shows the save as failed, as for the CV itself; the
/// keep stays pending, and the next write of the CV writes it again, unless the person has dismissed the notice meanwhile.
@MainActor
final class EditorNoticeKeeper {

    private let store: any EditorNoticeStore
    /// The notice to keep with the CV, while the person has not dismissed it.
    private var notice: EditorNotice?
    /// The id the store holds the CV under, once it does.
    private var storedCVId: UUID?
    /// The store holds the CV, and the notice is still to be written with it: its keep has not succeeded yet.
    private var keepIsPending = false
    /// The last write asked for: the next one starts when it has ended.
    private var lastWrite: Task<Void, any Error>?

    /// - Parameter notice: The notice a new CV opens with; nil for a stored CV, whose notice is read.
    init(store: any EditorNoticeStore, notice: EditorNotice?) {
        self.store = store
        self.notice = notice
    }

    /// Reads the notice kept with a stored CV, and keeps it from then on under that CV's id.
    func read(cvWithId id: UUID) async -> EditorNotice? {
        storedCVId = id
        let kept = await store.notice(ofCVWithId: id)
        notice = kept
        return kept
    }

    /// Whether the store holds the CV with this id: a write that failed after the CV was stored updates it, and never
    /// stores it a second time.
    func storesCV(withId id: UUID) -> Bool {
        storedCVId == id
    }

    /// The store holds the CV now: its notice is kept with it, if the person has not dismissed it and it is not kept
    /// already. Throws when the notice could not be written; the keep then stays pending, for the next write of the CV.
    func cvIsStored(withId id: UUID) async throws {
        if storedCVId == nil {
            storedCVId = id
            keepIsPending = notice?.isKept == true
        }
        guard keepIsPending, let notice else { return }
        do {
            try await write { store in try await store.keep(notice, forCVWithId: id) }
            keepIsPending = false
        } catch {
            // A notice dismissed while it was written is not to be kept: its forgetting runs after this keep.
            guard keepIsPending else { return }
            throw error
        }
    }

    /// The person dismissed the notice: it is no longer kept with the CV, and a keep that failed is not tried again.
    func dismiss() async {
        guard let dismissed = notice else { return }
        notice = nil
        keepIsPending = false
        guard dismissed.isKept, let storedCVId else { return }
        // Forgetting cannot fail: the store logs a file it cannot remove.
        _ = await queued { store in await store.forget(cvWithId: storedCVId) }.result
    }

    /// Runs `change` once the write asked for before it has ended, and reports how it ended.
    private func write(_ change: @escaping @Sendable (any EditorNoticeStore) async throws -> Void) async throws {
        try await queued(change).value
    }

    /// Starts `change` behind the write asked for before it, whatever that one's outcome.
    private func queued(_ change: @escaping @Sendable (any EditorNoticeStore) async throws -> Void) -> Task<Void, any Error> {
        let previous = lastWrite
        let store = self.store
        let task = Task {
            // The write before this one has ended, whatever its outcome: its own caller hears how.
            _ = await previous?.result
            try await change(store)
        }
        lastWrite = task
        return task
    }
}
