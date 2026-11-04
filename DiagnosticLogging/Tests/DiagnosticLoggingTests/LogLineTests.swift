import DiagnosticLogging
import Foundation
import Testing

private extension LogCategory {
    static let sample = LogCategory("sample")
}

/// An error whose description holds the text that failed, as an error of the import can.
private struct ReadingFailure: Error, CustomStringConvertible, LocalizedError {
    var description: String { "could not read Lena Hartmann" }
    var errorDescription: String? { description }
}

/// The same failure, with a code chosen in code.
private enum ParsingFailure: LoggableError, CustomStringConvertible {
    case unreadableLine(String)

    var logCode: StaticString {
        switch self {
        case .unreadableLine: "unreadableLine"
        }
    }

    var description: String {
        switch self {
        case .unreadableLine(let line): "unreadable line: \(line)"
        }
    }
}

@Suite("The text of a log line")
struct LogLineTests {
    private func line(_ fields: LogField...) -> String {
        LogEntry(level: .info, category: .sample, event: "sample.event", fields: fields).line
    }

    @Test("A line without fields is the event alone")
    func eventAlone() {
        #expect(line() == "sample.event")
    }

    @Test("A count is the integer")
    func count() {
        #expect(line(.count("sections", 6), .count("delta", -2)) == "sample.event sections=6 delta=-2")
    }

    @Test("A duration is in milliseconds, with one decimal, rounded", arguments: [
        (Duration.zero, "0.0ms"),
        (.microseconds(40), "0.0ms"),
        (.microseconds(50), "0.1ms"),
        (.milliseconds(41) + .microseconds(660), "41.7ms"),
        (.seconds(12), "12000.0ms"),
        (.seconds(-1) - .microseconds(250), "-1000.3ms"),
    ])
    func duration(duration: Duration, text: String) {
        #expect(line(.duration("elapsed", duration)) == "sample.event elapsed=\(text)")
    }

    @Test("A flag is true or false")
    func flag() {
        #expect(line(.flag("cached", true), .flag("partial", false)) == "sample.event cached=true partial=false")
    }

    @Test("A token is the word chosen in code")
    func token() {
        #expect(line(.token("kind", "pdf")) == "sample.event kind=pdf")
    }

    @Test("An identifier is the UUID")
    func identifier() throws {
        let id = try #require(UUID(uuidString: "6F1C2A3B-4D5E-4F60-8A9B-0C1D2E3F4A5B"))
        #expect(line(.identifier("cv", id)) == "sample.event cv=6F1C2A3B-4D5E-4F60-8A9B-0C1D2E3F4A5B")
    }

    @Test("An error is its type, never its description")
    func errorByType() {
        let text = line(.error(ReadingFailure()))

        #expect(text == "sample.event error=ReadingFailure")
        #expect(!text.contains("Lena"))
    }

    @Test("A loggable error is its type and its code, never its description")
    func loggableError() {
        let text = line(.error("cause", ParsingFailure.unreadableLine("Lena Hartmann")))

        #expect(text == "sample.event cause=ParsingFailure.unreadableLine")
        #expect(!text.contains("Lena"))
    }

    @Test("An error field keeps the type and the code apart")
    func errorFieldValue() {
        #expect(LogField.error(ParsingFailure.unreadableLine("x")).value == .error(type: "ParsingFailure", code: "unreadableLine"))
        #expect(LogField.error(ReadingFailure()).value == .error(type: "ReadingFailure", code: nil))
        #expect(LogField.error(ReadingFailure()).key == "error")
    }

    @Test("The fields follow the event in the order they were given")
    func order() {
        #expect(line(.token("kind", "text"), .count("pages", 2), .flag("limited", true))
            == "sample.event kind=text pages=2 limited=true")
    }
}
