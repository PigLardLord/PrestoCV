import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Testing

private extension LogCategory {
    static let sample = LogCategory("sample")
}

@Suite("The logger's shorthands, decorators and composites")
struct DiagnosticLoggerTests {
    // MARK: Shorthands

    @Test("Each shorthand logs one entry at its own level, with the category, the event and the fields")
    func shorthands() {
        let logger = RecordingLogger()

        logger.debug(.sample, "sample.debug", .count("lines", 3))
        logger.info(.sample, "sample.info", .flag("cached", true))
        logger.notice(.sample, "sample.notice", .token("reason", "modelNotReady"))
        logger.error(.sample, "sample.error", .count("pages", 0))
        logger.fault(.sample, "sample.fault")

        #expect(logger.entries == [
            LogEntry(level: .debug, category: .sample, event: "sample.debug", fields: [.count("lines", 3)]),
            LogEntry(level: .info, category: .sample, event: "sample.info", fields: [.flag("cached", true)]),
            LogEntry(level: .notice, category: .sample, event: "sample.notice", fields: [.token("reason", "modelNotReady")]),
            LogEntry(level: .error, category: .sample, event: "sample.error", fields: [.count("pages", 0)]),
            LogEntry(level: .fault, category: .sample, event: "sample.fault", fields: []),
        ])
    }

    @Test("The levels are ordered from debug to fault")
    func levelsAreOrdered() {
        #expect(LogLevel.allCases == [.debug, .info, .notice, .error, .fault])
        #expect(LogLevel.allCases.sorted() == LogLevel.allCases)
    }

    @Test("Entries differ by level, category, event and fields")
    func entriesCompareEveryPart() {
        let entry = LogEntry(level: .info, category: .sample, event: "sample.done", fields: [.count("lines", 1)])

        #expect(entry != LogEntry(level: .notice, category: .sample, event: "sample.done", fields: [.count("lines", 1)]))
        #expect(entry != LogEntry(level: .info, category: LogCategory("other"), event: "sample.done", fields: [.count("lines", 1)]))
        #expect(entry != LogEntry(level: .info, category: .sample, event: "sample.started", fields: [.count("lines", 1)]))
        #expect(entry != LogEntry(level: .info, category: .sample, event: "sample.done", fields: [.count("lines", 2)]))
    }

    // MARK: Decorators and composites

    @Test("A fan-out sends each entry to every logger, in order")
    func fanOutReachesEveryLogger() {
        let first = RecordingLogger(), second = RecordingLogger(), third = RecordingLogger()
        let logger = FanOutLogger([first, second, third])

        logger.info(.sample, "sample.one")
        logger.error(.sample, "sample.two")

        for recorder in [first, second, third] {
            #expect(recorder.events == ["sample.one", "sample.two"])
        }
    }

    @Test("A minimum level drops the entries below it, and passes the others on", arguments: LogLevel.allCases)
    func minimumLevel(minimum: LogLevel) {
        let next = RecordingLogger()
        let logger = MinimumLevelLogger(minimum: minimum, next: next)

        for level in LogLevel.allCases {
            logger.log(LogEntry(level: level, category: .sample, event: "sample.event", fields: []))
        }

        #expect(next.entries.map(\.level) == LogLevel.allCases.filter { $0 >= minimum })
    }

    @Test("A silent logger accepts every entry and passes none on")
    func silentLogger() {
        let silent: any DiagnosticLogger = SilentLogger()
        let recorder = RecordingLogger()
        let logger = FanOutLogger([silent, MinimumLevelLogger(minimum: .fault, next: recorder)])

        for level in LogLevel.allCases {
            logger.log(LogEntry(level: level, category: .sample, event: "sample.event", fields: []))
        }

        #expect(recorder.entries.map(\.level) == [.fault])
    }
}
