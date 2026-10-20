import Foundation
import PrestoCVCore
import Synchronization
import os

private let keeperLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "unsaved-edits")

/// Keeps on the device what an editor has not saved, so that it outlives the app when iOS ends it: a few seconds
/// after a change, and at once when asked, as when the app leaves the foreground. What is kept always follows the
/// editor: its edits while it has some, nothing once they are saved or discarded.
///
/// The writes run one after another, each with the state of the editor at the moment it was asked for, so the
/// last write is always the latest state.
///
/// The keeper holds the claim on its editing: only it changes the kept edits, and no window offers them, while it
/// lives. A new editing is claimed at its first write; restored edits come with the claim of the window that took them.
/// When the keeper goes away, it lets go of them, so edits it did not remove are offered again.
@MainActor
final class UnsavedEditsKeeper {
    /// What the editor has not saved: the CV as it shows it, and the stored CV the edits were made on, or what a save
    /// that has started is storing; nil when nothing was stored yet.
    struct Edits: Equatable {
        let cv: CVModel
        let base: CVModel?
    }

    /// How long after a change its edits are kept at the latest.
    nonisolated static let delay = Duration.seconds(2)

    /// The editing the edits belong to.
    let editing: UUID
    private let useCase: UnsavedEditsUseCaseProtocol
    private let delay: Duration
    private let wait: (Duration) async throws -> Void
    private var scheduledWrite: Task<Void, Never>?
    private var lastWrite: Task<Bool, Never>?
    /// What the last write that went through left in the store: `.some(nil)` when it removed the edits, and `.none`
    /// before any write went through, when the store may still hold what an earlier run kept.
    private(set) var written: Edits??
    /// The editor was left: its edits were saved or discarded, and nothing more is kept for it.
    private var isClosed = false
    /// The claim this keeper holds on its editing; nil while it holds none. Read when the keeper goes away.
    private let heldClaim: Mutex<UnsavedEditsClaim?>
    /// A new editing claims its id at its first write. Restored edits do not: once their claim is let go, another
    /// window may hold them, and only an explicit new claim takes them back.
    private let claimsAtFirstWrite: Bool

    /// - Parameters:
    ///   - editing: The editing the edits belong to: a new one, or the one whose edits the editor restores.
    ///   - claim: The claim on restored edits, which the keeper now holds; nil for a new editing.
    ///   - wait: How the keeper waits `delay` after a change.
    init(
        editing: UUID,
        claim: UnsavedEditsClaim? = nil,
        useCase: UnsavedEditsUseCaseProtocol,
        delay: Duration = UnsavedEditsKeeper.delay,
        wait: @escaping (Duration) async throws -> Void
    ) {
        self.editing = editing
        self.heldClaim = Mutex(claim)
        self.claimsAtFirstWrite = claim == nil
        self.useCase = useCase
        self.delay = delay
        self.wait = wait
    }

    deinit {
        guard let claim = heldClaim.withLock({ $0 }) else { return }
        let useCase = useCase
        Task { await useCase.release(claim) }
    }

    /// Whether the keeper holds its editing now.
    var holdsEditing: Bool {
        heldClaim.withLock { $0 != nil }
    }

    /// Lets go of the editing, as when the editor could not show the restored edits: they are offered again.
    func release() async {
        guard let claim = heldClaim.withLock({ held in
            defer { held = nil }
            return held
        }) else { return }
        await useCase.release(claim)
    }

    /// Takes restored edits back after `release()`, unless another window holds them or they changed meanwhile.
    /// - Returns: Whether the keeper holds them now
    func reclaim(_ edits: UnsavedEdits) async -> Bool {
        guard !holdsEditing else { return true }
        do {
            guard let claim = try await useCase.claim(edits) else { return false }
            heldClaim.withLock { $0 = claim }
            return true
        } catch {
            keeperLogger.error("Unsaved edits could not be claimed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The editor changed: what `edits` returns once `delay` has passed is kept. Changes made meanwhile are kept by
    /// the same write.
    func keepSoon(_ edits: @escaping @MainActor () -> Edits?) {
        guard !isClosed, scheduledWrite == nil else { return }
        scheduledWrite = Task {
            do {
                try await wait(delay)
            } catch {
                return
            }
            // A write asked for meanwhile, or the editor being left, has taken the place of this one
            guard !Task.isCancelled else { return }
            scheduledWrite = nil
            await keepNow(edits())
        }
    }

    /// Keeps `edits` now, after any write that is running; nil removes what was kept.
    /// - Returns: Whether the store holds `edits` now. A failure is logged; a caller that relies on the store being
    ///   right acts on it.
    @discardableResult
    func keepNow(_ edits: Edits?) async -> Bool {
        guard !isClosed else { return false }
        scheduledWrite?.cancel()
        scheduledWrite = nil
        return await enqueue(edits)
    }

    /// The editor is left with nothing unsaved, or its edits were discarded: what was kept goes, and nothing more is.
    func close() async {
        guard !isClosed else { return }
        isClosed = true
        scheduledWrite?.cancel()
        scheduledWrite = nil
        await enqueue(nil)
    }

    // MARK: - Private Methods

    @discardableResult
    private func enqueue(_ edits: Edits?) async -> Bool {
        let previous = lastWrite
        let next = Task {
            _ = await previous?.value
            return await store(edits)
        }
        lastWrite = next
        return await next.value
    }

    private func store(_ edits: Edits?) async -> Bool {
        guard written != .some(edits) else { return true }
        guard let claim = await claimForWriting() else {
            keeperLogger.error("Unsaved edits were not kept: the editing is not held")
            return false
        }
        do {
            if let edits {
                try await useCase.keep(edits.cv, over: edits.base, as: claim)
            } else {
                try await useCase.discard(as: claim)
            }
            written = .some(edits)
            return true
        } catch {
            keeperLogger.error("Unsaved edits were not kept: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The claim to write with: the one held, or, for a new editing, one taken at its first write.
    private func claimForWriting() async -> UnsavedEditsClaim? {
        if let claim = heldClaim.withLock({ $0 }) {
            return claim
        }
        guard claimsAtFirstWrite, let claim = await useCase.claimEditing(editing) else {
            return nil
        }
        heldClaim.withLock { $0 = claim }
        return claim
    }
}
