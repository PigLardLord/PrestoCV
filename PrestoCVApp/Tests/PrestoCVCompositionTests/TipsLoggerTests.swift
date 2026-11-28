import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Testing
@testable import PrestoCVComposition

/// Where the tips listener's entries go: the plain log until a launch's trace exists, then that trace's logger.
@Suite("The logger of the tips listener")
struct TipsLoggerTests {
    private static let category = LogCategory("tips")

    private static func nothing() -> Task<Void, Never> { Task {} }

    @Test("an entry made before any trace exists reaches only the plain log")
    func beforeTheTrace() {
        let settlement = TraceSettlement()
        let plain = RecordingLogger()
        let traced = RecordingLogger()

        let logger = settlement.tipsLogger(fallback: plain)
        logger.info(Self.category, "tips.before")
        settlement.record(Self.nothing(), logger: traced)

        #expect(plain.events == ["tips.before"])
        #expect(traced.events.isEmpty, "the trace did not exist yet")
    }

    @Test("an entry made after the trace is made reaches the trace logger, not the plain log")
    func afterTheTrace() {
        let settlement = TraceSettlement()
        let plain = RecordingLogger()
        let traced = RecordingLogger()
        let logger = settlement.tipsLogger(fallback: plain)

        settlement.record(Self.nothing(), logger: traced)
        logger.info(Self.category, "tips.after")

        #expect(traced.events == ["tips.after"])
        #expect(plain.events.isEmpty, "the trace logger passes it on to the log itself")
    }

    @Test("the trace of a later launch takes over")
    func laterLaunch() {
        let settlement = TraceSettlement()
        let plain = RecordingLogger()
        let first = RecordingLogger()
        let second = RecordingLogger()
        let logger = settlement.tipsLogger(fallback: plain)

        settlement.record(Self.nothing(), logger: first)
        logger.info(Self.category, "tips.one")
        settlement.record(Self.nothing(), logger: second)
        logger.info(Self.category, "tips.two")

        #expect(first.events == ["tips.one"])
        #expect(second.events == ["tips.two"])
    }
}
