import Synchronization

/// A clock that moves forward by a fixed step every time it is read, so the time a step takes is the same in every run:
/// code that reads it at the start and at the end measures one step. A sleep moves it to the deadline, and waits on nothing.
public final class TickingClock: Clock {
    public struct Instant: InstantProtocol {
        /// The time since the clock started.
        public let offset: Duration

        public init(offset: Duration) { self.offset = offset }
        public func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        public func duration(to other: Instant) -> Duration { other.offset - offset }
        public static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private let step: Duration
    private let current = Mutex(Instant(offset: .zero))

    public init(step: Duration) {
        self.step = step
    }

    public var now: Instant {
        current.withLock { now in
            now = now.advanced(by: step)
            return now
        }
    }

    public var minimumResolution: Duration { .zero }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
        current.withLock { now in now = max(now, deadline) }
    }
}
