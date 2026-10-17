import Foundation
@testable import PrestoCVCore

/// Unsaved edits kept in memory, one set per editing, as the file store keeps them. A test can wait for the writes
/// it expects, and make the next ones fail.
actor InMemoryUnsavedEditsRepository: UnsavedEditsRepositoryProtocol {
    private(set) var kept: [UUID: UnsavedEdits] = [:]
    private(set) var writeCount = 0
    private var failure: Error?
    private var keepFailure: Error?
    private var discardFailure: Error?
    private var writeWaiters = CountWaiters()

    func fail(with error: Error?) {
        failure = error
    }

    /// Makes the next keeps fail, while removing still works.
    func failKeeping(with error: Error?) {
        keepFailure = error
    }

    /// Makes the next removals fail, while keeping still works.
    func failDiscarding(with error: Error?) {
        discardFailure = error
    }

    func keep(_ edits: UnsavedEdits) async throws {
        if let failure = failure ?? keepFailure { throw failure }
        kept[edits.id] = edits
        wrote()
    }

    func allKept() async throws -> [UnsavedEdits] {
        if let failure { throw failure }
        return Array(kept.values)
    }

    func kept(editing id: UUID) async throws -> UnsavedEdits? {
        if let failure { throw failure }
        return kept[id]
    }

    func discard(editing id: UUID) async throws {
        if let failure = failure ?? discardFailure { throw failure }
        kept[id] = nil
        wrote()
    }

    /// Returns once `count` writes, keeps or discards, have gone through since the repository was made, or when the
    /// task that waits is cancelled.
    func waitForWrites(_ count: Int) async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                writeWaiters.add(id, waitingFor: count, continuation, reached: writeCount)
            }
        } onCancel: {
            Task { await self.stopWaiting(id) }
        }
    }

    private func stopWaiting(_ id: UUID) {
        writeWaiters.cancel(id)
    }

    private func wrote() {
        writeCount += 1
        writeWaiters.reach(writeCount)
    }
}
