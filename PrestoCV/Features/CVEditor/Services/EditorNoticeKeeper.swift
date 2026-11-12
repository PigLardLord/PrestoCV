import Foundation

/// The notice of the CV an editor shows, kept with the CV once the store holds it, until the person dismisses it
/// (ADR 0027). Only a notice that is kept (`EditorNotice.isKept`, the import's) is written.
///
/// Its writes run one after the other, in the order they were asked for: a dismissal is never undone by a keep asked for
/// before it, whatever the priority of the tasks that ask. The autosave's write tells it the CV is stored, and needs
/// nothing of the editor for it, so that a write that ends after the editor is gone still keeps the notice.
@MainActor
final class EditorNoticeKeeper {

    private let store: any EditorNoticeStore
    /// The notice to keep with the CV, while the person has not dismissed it.
    private var notice: EditorNotice?
    /// The id the store holds the CV under, once it does.
    private var storedCVId: UUID?
    /// The last write asked for: the next one starts when it has ended.
    private var lastWrite: Task<Void, Never>?

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

    /// The store holds the new CV now: its notice is kept with it, if the person has not dismissed it.
    func cvIsStored(withId id: UUID) async {
        guard storedCVId == nil else { return }
        storedCVId = id
        guard let notice, notice.isKept else { return }
        await write { store in await store.keep(notice, forCVWithId: id) }
    }

    /// The person dismissed the notice: it is no longer kept with the CV.
    func dismiss() async {
        guard let dismissed = notice else { return }
        notice = nil
        guard dismissed.isKept, let storedCVId else { return }
        await write { store in await store.forget(cvWithId: storedCVId) }
    }

    private func write(_ change: @escaping @Sendable (any EditorNoticeStore) async -> Void) async {
        let previous = lastWrite
        let store = self.store
        let task = Task {
            await previous?.value
            await change(store)
        }
        lastWrite = task
        await task.value
    }
}
