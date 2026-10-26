import DiagnosticLogging
import Synchronization

/// A logger that keeps every entry, for tests to read what was logged.
public final class RecordingLogger: DiagnosticLogger {
    private let recorded = Mutex<[LogEntry]>([])

    public init() {}

    public func log(_ entry: LogEntry) {
        recorded.withLock { $0.append(entry) }
    }

    /// Every entry, in the order it was logged.
    public var entries: [LogEntry] { recorded.withLock { $0 } }

    /// The event of every entry, in order.
    public var events: [String] { entries.map(\.event.description) }

    /// The entries of one event.
    public func entries(_ event: StaticString) -> [LogEntry] {
        entries.filter { $0.event.description == event.description }
    }

    /// The single entry of an event, or nil when there is none or more than one.
    public func entry(_ event: StaticString) -> LogEntry? {
        let found = entries(event)
        return found.count == 1 ? found[0] : nil
    }
}

extension LogEntry {
    /// The value of the field with this key, or nil.
    public func value(_ key: String) -> LogField.Value? {
        fields.first { $0.key == key }?.value
    }
}
