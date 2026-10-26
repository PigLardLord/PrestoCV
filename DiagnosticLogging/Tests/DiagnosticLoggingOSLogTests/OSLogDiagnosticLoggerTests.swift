#if canImport(os)
import DiagnosticLogging
import DiagnosticLoggingOSLog
import os
import Testing

@Suite("The unified log adapter")
struct OSLogDiagnosticLoggerTests {
    @Test("The levels map one to one to the types of the unified log")
    func levels() {
        #expect(LogLevel.allCases.map(OSLogDiagnosticLogger.type(of:)) == [.debug, .info, .default, .error, .fault])
    }

    @Test("Writing every level to every category does not stop, and needs nothing but the subsystem")
    func writes() {
        let logger = OSLogDiagnosticLogger(subsystem: "com.PigLardLord.prestocv.tests")

        for category in [LogCategory("import"), LogCategory("draft"), LogCategory("import")] {
            for level in LogLevel.allCases {
                logger.log(LogEntry(level: level, category: category, event: "tests.written", fields: [.count("lines", 1)]))
            }
        }
    }
}
#endif
