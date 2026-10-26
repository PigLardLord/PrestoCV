/// Sends each entry to several loggers, in order: for example the native log and a crash-reporting service at once.
public struct FanOutLogger: DiagnosticLogger {
    private let loggers: [any DiagnosticLogger]

    public init(_ loggers: [any DiagnosticLogger]) {
        self.loggers = loggers
    }

    public func log(_ entry: LogEntry) {
        for logger in loggers {
            logger.log(entry)
        }
    }
}

/// Drops the entries below a level, and passes the others on: for example to keep debug entries out of a remote service.
public struct MinimumLevelLogger: DiagnosticLogger {
    private let minimum: LogLevel
    private let next: any DiagnosticLogger

    public init(minimum: LogLevel, next: any DiagnosticLogger) {
        self.minimum = minimum
        self.next = next
    }

    public func log(_ entry: LogEntry) {
        guard entry.level >= minimum else { return }
        next.log(entry)
    }
}

/// Discards every entry: for previews, and wherever nothing should be logged.
public struct SilentLogger: DiagnosticLogger {
    public init() {}

    public func log(_ entry: LogEntry) {}
}
