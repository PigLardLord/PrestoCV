import Foundation

/// A clock that moves forward one second every time it is read, so each reading is distinct and in reading order
final class TickingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var next: Date
    
    init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        next = start
    }
    
    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        defer { next = next.addingTimeInterval(1) }
        return next
    }
}
