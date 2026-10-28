import CVGeneratorAI
import DiagnosticLogging
import Testing
@testable import PrestoCV

@MainActor
@Suite("LanguageDataPreparation - the wait for the language data ends with the system's answer, or at its bound", .timeLimit(.minutes(1)))
struct LanguageDataPreparationTests {
    private let system = LanguageDataSpy()
    private let sleeps = HeldSleeps()
    private let log = LogSpy()
    private let clock = ManualClock()

    private func makePreparation() -> LanguageDataPreparation {
        let sleeps = sleeps
        return LanguageDataPreparation(requester: system, sleep: { try await sleeps.sleep(for: $0) }, logger: log, clock: clock)
    }

    /// The entry a wait writes when it ends (ADR 0030): the outcome and the time on the clock, never the language.
    private func waitEntry(_ level: LogLevel, outcome: StaticString, elapsed: Duration) -> LogEntry {
        LogEntry(
            level: level, category: .draft, event: "draft.languageData",
            fields: [.token("outcome", outcome), .duration("elapsed", elapsed)]
        )
    }

    @Test("The system's answer ends the wait", arguments: [LanguageDataOutcome.available, .notAvailable])
    func answerEndsTheWait(outcome: LanguageDataOutcome) async {
        system.outcome = outcome

        #expect(await makePreparation().prepare(language: "de") == outcome)
        #expect(system.requests == ["de"])
    }

    @Test("An answer that comes while the bound runs ends the wait with it")
    func answerBeforeTheBound() async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        system.answerHeld(.available)

        #expect(await wait.value == .available)
    }

    @Test("The bound is 60 seconds, and ends the wait with notAvailable when the system never answers, though it ignores the cancel")
    func boundEndsTheWait() async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        #expect(await sleeps.durations == [LanguageDataPreparation.bound])
        #expect(LanguageDataPreparation.bound == .seconds(60))
        await sleeps.endAll()

        #expect(await wait.value == .notAvailable)
        #expect(system.requests == ["en"])
        system.answerHeld(.notAvailable)  // Lets go of the request that was held; the test needs no answer from it
    }

    @Test("An answer that comes after the bound is harmless: it does not resume the ended wait a second time")
    func lateAnswerIsHarmless() async {
        system.outcome = nil
        let preparation = makePreparation()
        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        await sleeps.endAll()
        #expect(await wait.value == .notAvailable)

        system.answerHeld(.available)

        // The preparation is as usable as before: the next wait is answered by its own request
        system.outcome = .available
        #expect(await preparation.prepare(language: "en") == .available)
        #expect(system.requests == ["en", "en"])
    }

    @Test("The bound is given to the preparation, which waits that long")
    func boundIsGiven() async {
        system.outcome = nil
        let sleeps = sleeps
        let preparation = LanguageDataPreparation(
            requester: system, bound: .seconds(5), sleep: { try await sleeps.sleep(for: $0) }, logger: log, clock: clock
        )

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        #expect(await sleeps.durations == [.seconds(5)])
        await sleeps.endAll()

        #expect(await wait.value == .notAvailable)
        system.answerHeld(.notAvailable)
    }

    @Test("A cancelled wait ends at once with notAvailable, without the system's answer")
    func cancelledWaitEndsAtOnce() async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        wait.cancel()

        #expect(await wait.value == .notAvailable)
        system.answerHeld(.available)
    }

    // MARK: - The log of the wait

    @Test("The system's answer is logged with the time it took: info when the data came, notice when it did not", arguments: [
        (LanguageDataOutcome.available, LogLevel.info, "available" as StaticString),
        (LanguageDataOutcome.notAvailable, LogLevel.notice, "notAvailable" as StaticString),
    ])
    func answerIsLogged(outcome: LanguageDataOutcome, level: LogLevel, name: StaticString) async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "pt-BR") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        clock.advance(by: .seconds(3))
        system.answerHeld(outcome)

        #expect(await wait.value == outcome)
        #expect(log.entries == [waitEntry(level, outcome: name, elapsed: .seconds(3))])
        #expect(!log.lines.joined().contains("pt-BR"), "The log names no language")
    }

    @Test("A wait the bound ended is logged as notAvailable, after the bound")
    func boundIsLogged() async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        clock.advance(by: LanguageDataPreparation.bound)
        await sleeps.endAll()

        #expect(await wait.value == .notAvailable)
        #expect(log.entries == [waitEntry(.notice, outcome: "notAvailable", elapsed: .seconds(60))])
        system.answerHeld(.notAvailable)
    }

    @Test("A cancelled wait is logged as cancelled, not as data the system refused")
    func cancelIsLogged() async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        clock.advance(by: .seconds(1))
        wait.cancel()

        #expect(await wait.value == .notAvailable)
        #expect(log.entries == [waitEntry(.notice, outcome: "cancelled", elapsed: .seconds(1))])
        system.answerHeld(.notAvailable)
    }
}
