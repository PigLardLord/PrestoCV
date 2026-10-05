import Foundation
import Synchronization
import PrestoCVApplication

/// A clock that always says the same time and counts how often it was read, to test when a store reads its clock.
public final class CountingClock: TimeSource {
    private let reads = Mutex(0)
    private let time: Date

    /// - Parameter time: The time every read returns.
    public init(time: Date = Date(timeIntervalSince1970: 1_700_000_000)) { self.time = time }

    /// How many times `now()` was called.
    public var readCount: Int { reads.withLock { $0 } }

    /// The time given at creation. The read is counted.
    public func now() -> Date {
        reads.withLock { $0 += 1 }
        return time
    }
}
