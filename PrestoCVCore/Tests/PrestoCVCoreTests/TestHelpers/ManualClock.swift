import Foundation

/// A clock that only moves when a test moves it
final class ManualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = start
    }
    
    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
    
    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }
}
