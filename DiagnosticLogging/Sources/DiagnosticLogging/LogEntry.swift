/// How much an entry matters, from detail for a live session to a state that should be impossible.
public enum LogLevel: Int, Sendable, Comparable, CaseIterable {
    case debug, info, notice, error, fault

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// The part of the app an entry comes from. Each module declares its own once, as a constant:
/// `extension LogCategory { static let importing = LogCategory("import") }`.
public struct LogCategory: Sendable, Hashable {
    public let name: String

    public init(_ name: StaticString) {
        self.name = name.description
    }
}

/// One thing that happened: an event named in code, and fields of a closed set of kinds, so that no CV content can reach
/// a log line (ADR 0030).
public struct LogEntry: Sendable, Equatable {
    public let level: LogLevel
    public let category: LogCategory
    /// The event, such as `import.finished`. It is a `StaticString`, so interpolating a value into it does not compile.
    public let event: StaticString
    public let fields: [LogField]

    public init(level: LogLevel, category: LogCategory, event: StaticString, fields: [LogField]) {
        self.level = level
        self.category = category
        self.event = event
        self.fields = fields
    }

    /// The text of the entry: the event, then each field as `key=value`, in order. An adapter writes it as it is.
    public var line: String {
        ([event.description] + fields.map { "\($0.key)=\($0.value.text)" }).joined(separator: " ")
    }

    public static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.level == rhs.level && lhs.category == rhs.category && lhs.event.description == rhs.event.description
            && lhs.fields == rhs.fields
    }
}
