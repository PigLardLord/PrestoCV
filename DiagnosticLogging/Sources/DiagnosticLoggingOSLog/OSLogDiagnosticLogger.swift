#if canImport(os)
import DiagnosticLogging
import os

/// Writes each entry to the unified log of Apple platforms (ADR 0030): one `os.Logger` per category of the subsystem, the
/// levels mapped one to one, and the line of the entry as public text, since nothing private can reach it. Only the
/// composition root makes one (R4).
public final class OSLogDiagnosticLogger: DiagnosticLogger {
    private let subsystem: String
    private let loggers = OSAllocatedUnfairLock<[LogCategory: Logger]>(initialState: [:])

    public init(subsystem: String) {
        self.subsystem = subsystem
    }

    public func log(_ entry: LogEntry) {
        let line = entry.line
        logger(for: entry.category).log(level: Self.type(of: entry.level), "\(line, privacy: .public)")
    }

    /// The type of the unified log that a level is written with.
    public static func type(of level: LogLevel) -> OSLogType {
        switch level {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .error: .error
        case .fault: .fault
        }
    }

    private func logger(for category: LogCategory) -> Logger {
        loggers.withLock { [subsystem] loggers in
            if let logger = loggers[category] { return logger }
            let logger = Logger(subsystem: subsystem, category: category.name)
            loggers[category] = logger
            return logger
        }
    }
}
#endif
