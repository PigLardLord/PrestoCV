import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// A value published after an await from an intent that is no longer the latest must not replace what a newer intent
/// published. Each test suspends a port, makes the second intent, releases the first and asserts.
@MainActor
@Suite("First run: overlapping intents")
struct FirstRunOverlapTests {

    @Test("an older read of the store does not replace the answer of a newer one")
    func olderFirstRunReadDoesNotRegress() async throws {
        let world = Browsing()
        let firstRun = world.firstRun()
        await world.browsing.onboardingGate.close()

        let older = Task { await firstRun.load() }
        await waitUntil("the first read to answer") { await world.browsing.onboardingGate.waiting == 1 }
        _ = try await world.stored(title: "Backend")
        let newer = Task { await firstRun.load() }
        await waitUntil("the second read to answer") { await world.browsing.onboardingGate.waiting == 2 }
        await world.browsing.onboardingGate.releaseNewest()
        await newer.value
        #expect(firstRun.state == .returning)
        await world.browsing.onboardingGate.open()
        await older.value

        #expect(firstRun.state == .returning)
    }
}
