import Foundation
import Synchronization

/// A clock, in seconds, that moves only when a test moves it: a measured duration is exactly what the work advanced.
final class ManualClock: Sendable {
    private let seconds = Mutex<TimeInterval>(1_000)

    func now() -> TimeInterval {
        seconds.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        seconds.withLock { $0 += interval }
    }
}
