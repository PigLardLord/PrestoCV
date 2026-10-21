import Foundation

/// Writes what an editor shows to the store by itself, so that nobody has to save.
///
/// - **When:** a pause after the last change, and at once when the editor asks, as when it is left or the app goes to
///   the background.
/// - **When not:** content that equals what the store holds is never written, so its edit time stays. A CV the store
///   does not hold yet is written only once it is worth storing: a blank one left untouched leaves nothing behind.
/// - **After a write:** the content is compared with the store again. A change made while the write ran, or one that
///   undid it, is written next: by the pause that follows, or by the flush that was waiting.
/// - **If a write fails:** the content stays in memory, the status says so, the cause goes to the diagnostic boundary,
///   and the next change or `flush()` tries again. The failure goes when the content returns to what the store holds,
///   because nothing is left to retry.
/// - **If a write is cancelled:** that is no failure. The content stays to be written, a pause starts so that it is
///   written without another change, and `flush()` passes the cancellation on.
///
/// The rule is the timing. The write is a port the editor gives, and so is the clock, so that tests move time by hand.
@MainActor
public final class Autosave<Content: Equatable & Sendable> {

    /// Where the content stands with the store.
    public enum Status: Equatable, Sendable {
        /// The store holds the content, or there is nothing worth storing yet.
        case upToDate
        /// A change waits for the pause to end, or for a write to be asked for again after one was cancelled.
        case pending
        /// The content is being written.
        case writing
        /// The last write failed, and none has succeeded since: the content is only in memory.
        case failed
    }

    /// How long after the last change the content is written.
    public static var pause: Duration { .seconds(1) }

    /// Called with the status each time it changes.
    public var onStatusChange: @MainActor (Status) -> Void = { _ in }

    public private(set) var status: Status = .upToDate {
        didSet {
            if status != oldValue { onStatusChange(status) }
        }
    }

    /// Whether the store holds a version of the content: it did when the editing began, or a write has succeeded.
    public private(set) var isStored: Bool

    /// The write that waits for the pause to end, if one does.
    public private(set) var scheduledWrite: Task<Void, Never>?

    private var content: Content
    /// What counts as unchanged: what the store holds, or what a new editing started from; nil when even that is new.
    private var written: Content?
    private let isWorthStoring: @MainActor (Content) -> Bool
    private let write: @MainActor (Content, _ isStored: Bool) async throws -> Void
    private let onWriteFailure: @MainActor (any Error) -> Void
    /// Fixes the end of a pause starting now, and gives the wait for it.
    private let pauseFromNow: () -> () async throws -> Void
    private var running: Task<WriteOutcome, Never>?
    private var lastWriteFailed = false
    /// The flushes in progress: each one writes what is left, so a write that ends needs no pause of its own after it.
    private var flushes = 0

    private enum WriteOutcome {
        case nothingToWrite
        case written
        case failed
        case cancelled
    }

    /// - Parameters:
    ///   - content: What the editor shows when its editing begins.
    ///   - unchangedFrom: What counts as unchanged: the stored CV, or the template a new one starts from. Nil makes the
    ///     content itself the change, as for a draft someone made that is not stored yet.
    ///   - isStored: Whether the store holds the CV already.
    ///   - isWorthStoring: Whether content the store does not hold yet should be stored.
    ///   - clock: The clock the pause is measured on.
    ///   - onWriteFailure: Told the cause of each write that fails, which the status does not carry: a full disk, a
    ///     permission and an encoding error all read as `failed`.
    ///   - write: Stores the content. It is told whether the store holds the CV already, so that it creates the CV the
    ///     first time and updates it afterwards, and needs nothing of the editor that made it: a write that ends after
    ///     the editor is gone still stores what it was given.
    public init(
        content: Content,
        unchangedFrom written: Content?,
        isStored: Bool,
        pause: Duration = Autosave.pause,
        isWorthStoring: @escaping @MainActor (Content) -> Bool,
        clock: any Clock<Duration>,
        onWriteFailure: @escaping @MainActor (any Error) -> Void,
        write: @escaping @MainActor (Content, _ isStored: Bool) async throws -> Void
    ) {
        self.content = content
        self.written = written
        self.isStored = isStored
        self.isWorthStoring = isWorthStoring
        self.write = write
        self.onWriteFailure = onWriteFailure
        self.pauseFromNow = Self.pause(pause, on: clock)
    }

    /// The end of a pause is fixed when the pause starts, on the clock's own instants.
    private static func pause<C: Clock<Duration>>(_ pause: Duration, on clock: C) -> () -> () async throws -> Void {
        {
            let deadline = clock.now.advanced(by: pause)
            return { try await clock.sleep(until: deadline, tolerance: nil) }
        }
    }

    /// Whether the content differs from what the store holds, and is worth writing.
    public var hasChangesToWrite: Bool {
        content != written && (isStored || isWorthStoring(content))
    }

    // MARK: - Changes

    /// The editor shows `content` now: it is written once the pause has passed with no other change.
    /// - Returns: The wait for the pause and the write after it, or nil when there is nothing to write.
    @discardableResult
    public func changed(to content: Content) -> Task<Void, Never>? {
        self.content = content
        cancelThePause()
        guard hasChangesToWrite else {
            updateStatus()
            return nil
        }
        let scheduled = startThePause()
        updateStatus()
        return scheduled
    }

    /// Writes the content at once, if it has changed, after any write that is running, and goes on until the store
    /// holds what the form shows: a change made while a write ran is written too. Nothing waits for the pause.
    ///
    /// A write that fails ends the flush: the content stays to be written, and the status says `failed`.
    /// - Throws: `CancellationError` when the store cancelled the write. It is no failure: the content stays to be
    ///   written, and the status does not say `failed`.
    public func flush() async throws(CancellationError) {
        flushes += 1
        var wasCancelled = false
        loop: while true {
            cancelThePause()
            switch await writeOnce() {
            case .written:
                continue
            case .nothingToWrite, .failed:
                break loop
            case .cancelled:
                wasCancelled = true
                break loop
            }
        }
        flushes -= 1
        if wasCancelled {
            // Nobody has asked for another write: the pause does, so that the content is not left in memory for ever, once no
            // other flush or write is going on
            writeAgainIfTheContentIsNotStored()
            updateStatus()
            throw CancellationError()
        }
    }

    // MARK: - Private Methods

    private func startThePause() -> Task<Void, Never> {
        let waitForThePause = pauseFromNow()
        let scheduled = Task { [weak self] in
            do {
                try await waitForThePause()
            } catch {
                // A later change, or a flush, has taken the place of this write
                return
            }
            await self?.writeAfterThePause()
        }
        scheduledWrite = scheduled
        return scheduled
    }

    private func cancelThePause() {
        scheduledWrite?.cancel()
        scheduledWrite = nil
    }

    private func writeAfterThePause() async {
        guard !Task.isCancelled else { return }
        scheduledWrite = nil
        _ = await writeOnce()
    }

    /// One write at a time: a write asked for while one runs follows it, with the content of that moment.
    private func writeOnce() async -> WriteOutcome {
        while let running {
            _ = await running.value
        }
        guard hasChangesToWrite else {
            updateStatus()
            return .nothingToWrite
        }
        let snapshot = content
        let writing = Task {
            let outcome = await self.attempt(snapshot)
            // Cleared before the task ends, so a write waiting for this one finds the way free
            self.running = nil
            if outcome == .written || outcome == .cancelled {
                self.writeAgainIfTheContentIsNotStored()
            }
            self.updateStatus()
            return outcome
        }
        running = writing
        updateStatus()
        return await writing.value
    }

    private func attempt(_ snapshot: Content) async -> WriteOutcome {
        do {
            try await write(snapshot, isStored)
            written = snapshot
            isStored = true
            lastWriteFailed = false
            return .written
        } catch is CancellationError {
            return .cancelled
        } catch {
            lastWriteFailed = true
            onWriteFailure(error)
            return .failed
        }
    }

    /// The store may not hold what the form shows after a write: a change made while it ran, or one that undid it, or a
    /// write that was cancelled. When nothing else is going on (no flush, which writes by itself, and no other write), no
    /// pause is waiting and no failure is shown, one starts now, so that the content is written without another change or
    /// flush. A failure waits for the next change, or for Try Again, instead.
    private func writeAgainIfTheContentIsNotStored() {
        guard flushes == 0, running == nil, scheduledWrite == nil, !lastWriteFailed, hasChangesToWrite else { return }
        _ = startThePause()
    }

    private func updateStatus() {
        // A failure is about the content that could not be written. Once the store holds what the form shows, there is
        // nothing left to retry, and the failure would only stay for ever
        if running == nil, !hasChangesToWrite {
            lastWriteFailed = false
        }
        if running != nil {
            status = .writing
        } else if lastWriteFailed {
            status = .failed
        } else if scheduledWrite != nil || hasChangesToWrite {
            status = .pending
        } else {
            status = .upToDate
        }
    }
}
