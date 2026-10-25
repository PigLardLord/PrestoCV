import Testing
@testable import PrestoCV

@MainActor
@Suite("LanguageDataPreparation - the wait for the language data ends with the system's answer, or at its bound", .timeLimit(.minutes(1)))
struct LanguageDataPreparationTests {
    private let system = LanguageDataSpy()
    private let sleeps = HeldSleeps()

    private func makePreparation() -> LanguageDataPreparation {
        let sleeps = sleeps
        return LanguageDataPreparation(requester: system, sleep: { try await sleeps.sleep(for: $0) })
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

    @Test("The bound is 60 seconds, and holds when the system never answers and ignores the cancel; the late answer is dropped")
    func boundEndsTheWait() async {
        system.outcome = nil
        let preparation = makePreparation()

        let wait = Task { await preparation.prepare(language: "en") }
        await system.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        #expect(await sleeps.durations == [.seconds(60)])
        #expect(LanguageDataPreparation.bound == .seconds(60))
        await sleeps.endAll()

        #expect(await wait.value == .notAvailable)
        system.answerHeld(.available)
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
}
