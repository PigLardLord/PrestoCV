/// Measures the time a step takes, on the clock it is given, so that a logged duration is the same in every test run
/// (ADR 0030): the composition root passes the real clock, a test a clock that it moves.
public struct Stopwatch: Sendable {
    private let reading: @Sendable () -> Duration

    /// Starts measuring now.
    public init<C: Clock<Duration>>(started clock: C) {
        let start = clock.now
        reading = { start.duration(to: clock.now) }
    }

    /// The time since the stopwatch started.
    public var elapsed: Duration { reading() }
}
