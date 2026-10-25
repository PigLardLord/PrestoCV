/// Where the code writes what happened, without knowing where it goes (ADR 0030).
///
/// A type that logs takes one in its initialiser, with no default; only the composition root makes the adapters and
/// assembles the chain. `log` is synchronous, never throws and never waits on I/O: an adapter that writes somewhere slow
/// buffers the entries itself.
public protocol DiagnosticLogger: Sendable {
    func log(_ entry: LogEntry)
}

// MARK: - Shorthands

extension DiagnosticLogger {
    /// Detail for a live session; the system does not keep it.
    public func debug(_ category: LogCategory, _ event: StaticString, _ fields: LogField...) {
        log(LogEntry(level: .debug, category: category, event: event, fields: fields))
    }

    /// A step finished, with counts and time.
    public func info(_ category: LogCategory, _ event: StaticString, _ fields: LogField...) {
        log(LogEntry(level: .info, category: category, event: event, fields: fields))
    }

    /// A decision the user would notice, such as a section not recognised or the model unavailable.
    public func notice(_ category: LogCategory, _ event: StaticString, _ fields: LogField...) {
        log(LogEntry(level: .notice, category: category, event: event, fields: fields))
    }

    /// A failure the user sees.
    public func error(_ category: LogCategory, _ event: StaticString, _ fields: LogField...) {
        log(LogEntry(level: .error, category: category, event: event, fields: fields))
    }

    /// A state that should be impossible.
    public func fault(_ category: LogCategory, _ event: StaticString, _ fields: LogField...) {
        log(LogEntry(level: .fault, category: category, event: event, fields: fields))
    }
}
