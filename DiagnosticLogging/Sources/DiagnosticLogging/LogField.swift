import Foundation

/// A value of a log entry, of a closed set of kinds that cannot carry CV content (ADR 0030). A new kind is reviewed for
/// what it can carry, and added to the ADR's list.
public struct LogField: Sendable, Equatable {
    public enum Value: Sendable, Equatable {
        /// An integer, such as the sections read.
        case count(Int)
        case duration(Duration)
        case flag(Bool)
        /// A word chosen in code, such as a case name the caller spells out.
        case token(String)
        /// A UUID, which says nothing about the person.
        case identifier(UUID)
        /// The type of an error, and its code when it is a `LoggableError`; never its description.
        case error(type: String, code: String?)
    }

    public let key: String
    public let value: Value

    private init(_ key: StaticString, _ value: Value) {
        self.key = key.description
        self.value = value
    }

    public static func count(_ key: StaticString, _ value: Int) -> LogField { LogField(key, .count(value)) }
    public static func duration(_ key: StaticString, _ value: Duration) -> LogField { LogField(key, .duration(value)) }
    public static func flag(_ key: StaticString, _ value: Bool) -> LogField { LogField(key, .flag(value)) }
    public static func token(_ key: StaticString, _ value: StaticString) -> LogField { LogField(key, .token(value.description)) }
    public static func identifier(_ key: StaticString, _ value: UUID) -> LogField { LogField(key, .identifier(value)) }

    /// An error under the key `error`.
    public static func error(_ error: any Error) -> LogField { .error("error", error) }

    /// An error by its type, and its code when it is a `LoggableError`. Its description can hold the text that failed, so
    /// it is never read.
    public static func error(_ key: StaticString, _ error: any Error) -> LogField {
        LogField(key, .error(type: String(describing: type(of: error)), code: (error as? any LoggableError)?.logCode.description))
    }
}

/// An error that says which of its cases it is, with a word chosen in code, for the logs.
public protocol LoggableError: Error {
    var logCode: StaticString { get }
}

// MARK: - Text

extension LogField.Value {
    /// The value as a log line writes it.
    var text: String {
        switch self {
        case .count(let count): String(count)
        case .duration(let duration): Self.milliseconds(duration)
        case .flag(let flag): flag ? "true" : "false"
        case .token(let token): token
        case .identifier(let id): id.uuidString
        case .error(let type, let code): code.map { "\(type).\($0)" } ?? type
        }
    }

    /// Milliseconds with one decimal, rounded half away from zero: `41.7ms`.
    private static func milliseconds(_ duration: Duration) -> String {
        guard duration >= .zero else { return "-" + milliseconds(.zero - duration) }
        let (seconds, attoseconds) = duration.components
        let (wholeTenths, overflow) = seconds.multipliedReportingOverflow(by: 10_000)
        guard !overflow else { return "\(seconds)s" }
        let tenths = wholeTenths + (attoseconds + 50_000_000_000_000) / 100_000_000_000_000
        return "\(tenths / 10).\(tenths % 10)ms"
    }
}
