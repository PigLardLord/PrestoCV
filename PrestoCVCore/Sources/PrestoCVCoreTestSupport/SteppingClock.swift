import Foundation
import Synchronization
import PrestoCVApplication

/// A clock whose every read is a later instant than the one before, so ordering is deterministic without the wall clock.
public final class SteppingClock: TimeSource {
    private let reads = Mutex(0)

    public init() {}

    /// A time one second after the previous read, starting just after 1_700_000_000 seconds since 1970.
    public func now() -> Date {
        let read = reads.withLock { count -> Int in
            count += 1
            return count
        }
        return Date(timeIntervalSince1970: 1_700_000_000 + Double(read))
    }
}
