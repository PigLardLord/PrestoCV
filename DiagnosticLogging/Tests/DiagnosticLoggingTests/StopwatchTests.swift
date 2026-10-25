import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Testing

@Suite("The stopwatch of a logged step")
struct StopwatchTests {
    @Test("It measures from the moment it starts, on the clock it is given")
    func measuresOnTheGivenClock() {
        let stopwatch = Stopwatch(started: TickingClock(step: .milliseconds(7)))

        #expect(stopwatch.elapsed == .milliseconds(7))
        #expect(stopwatch.elapsed == .milliseconds(14))
    }

    @Test("A clock behind an existential measures the same")
    func measuresBehindAnExistential() {
        let clock: any Clock<Duration> = TickingClock(step: .seconds(2))
        let stopwatch = Stopwatch(started: clock)

        #expect(stopwatch.elapsed == .seconds(2))
    }

    @Test("A real clock never measures a negative time")
    func realClock() {
        #expect(Stopwatch(started: ContinuousClock()).elapsed >= .zero)
    }
}
