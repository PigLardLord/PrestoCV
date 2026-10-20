import Foundation

/// Writes what an editor shows to the store by itself, so that nobody has to save.
///
/// - **When:** a pause after the last change, and at once when the editor asks, as when it is left or the app goes to
///   the background.
/// - **When not:** content that equals what the store holds is never written, so its edit time stays. A CV the store
///   does not hold yet is written only once it is worth storing: a blank one left untouched leaves nothing behind.
/// - **If a write fails:** the content stays in memory, the status says so, and the next change or `flush()` tries
///   again.
///
/// The rule is the timing. The write is a port the editor gives, and so is the clock, so that tests move time by hand.
@MainActor
public final class Autosave<Content: Equatable & Sendable> {

    /// Where the content stands with the store.
    public enum Status: Equatable, Sendable {
        /// The store holds the content, or there is nothing worth storing yet.
        case upToDate
        /// A change waits for the pause to end.
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

    private var content: Content
    /// What counts as unchanged: what the store holds, or what a new editing started from; nil when even that is new.
    private var written: Content?
    private let isWorthStoring: @MainActor (Content) -> Bool
    private let write: @MainActor (Content) async throws -> Void
    /// Fixes the end of a pause starting now, and gives the wait for it.
    private let pauseFromNow: () -> () async throws -> Void
    private var timer: Task<Void, Never>?
    private var running: Task<Void, Never>?
    private var lastWriteFailed = false

    /// - Parameters:
    ///   - content: What the editor shows when its editing begins.
    ///   - unchangedFrom: What counts as unchanged: the stored CV, or the template a new one starts from. Nil makes the
    ///     content itself the change, as for a draft someone made that is not stored yet.
    ///   - isStored: Whether the store holds the CV already.
    ///   - isWorthStoring: Whether content the store does not hold yet should be stored.
    ///   - clock: The clock the pause is measured on.
    ///   - write: Stores the content, creating it the first time.
    public init(
        content: Content,
        unchangedFrom written: Content?,
        isStored: Bool,
        pause: Duration = Autosave.pause,
        isWorthStoring: @escaping @MainActor (Content) -> Bool,
        clock: any Clock<Duration>,
        write: @escaping @MainActor (Content) async throws -> Void
    ) {
        self.content = content
        self.written = written
        self.isStored = isStored
        self.isWorthStoring = isWorthStoring
        self.write = write
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
        timer?.cancel()
        timer = nil
        guard hasChangesToWrite else {
            updateStatus()
            return nil
        }
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
        timer = scheduled
        updateStatus()
        return scheduled
    }

    /// Writes the content at once, if it has changed, after any write that is running. Nothing waits for the pause.
    public func flush() async {
        timer?.cancel()
        timer = nil
        await writeIfChanged()
    }

    // MARK: - Private Methods

    private func writeAfterThePause() async {
        guard !Task.isCancelled else { return }
        timer = nil
        await writeIfChanged()
    }

    /// One write at a time: a write asked for while one runs follows it, with the content of that moment.
    private func writeIfChanged() async {
        while let running {
            await running.value
        }
        guard hasChangesToWrite else {
            updateStatus()
            return
        }
        let snapshot = content
        let writing = Task { [write] in
            do {
                try await write(snapshot)
                self.written = snapshot
                self.isStored = true
                self.lastWriteFailed = false
            } catch {
                self.lastWriteFailed = true
            }
            // Cleared before the task ends, so a write waiting for this one finds the way free
            self.running = nil
            self.updateStatus()
        }
        running = writing
        updateStatus()
        await writing.value
    }

    private func updateStatus() {
        if running != nil {
            status = .writing
        } else if lastWriteFailed {
            status = .failed
        } else if timer != nil {
            status = .pending
        } else {
            status = .upToDate
        }
    }
}
