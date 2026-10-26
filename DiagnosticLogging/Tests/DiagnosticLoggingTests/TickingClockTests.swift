import DiagnosticLoggingTestSupport
import Testing

@Suite("The ticking clock of the tests")
struct TickingClockTests {
    @Test("Each reading moves the clock on by one step")
    func eachReadingTicks() {
        let clock = TickingClock(step: .milliseconds(5))
        let start = clock.now
        let end = clock.now

        #expect(start.duration(to: end) == .milliseconds(5))
        #expect(start.duration(to: clock.now) == .milliseconds(10))
    }

    @Test("A sleep moves the clock to its deadline at once")
    func sleepMovesToTheDeadline() async throws {
        let clock = TickingClock(step: .milliseconds(1))
        let start = clock.now

        try await clock.sleep(until: start.advanced(by: .seconds(30)), tolerance: nil)

        #expect(start.duration(to: clock.now) == .seconds(30) + .milliseconds(1))
    }
}
