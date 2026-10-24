import Testing
import Foundation
@testable import PrestoCV

/// The changes to the stored CVs go one at a time for each CV, and a CV's editor waits for the ones on their way.
@MainActor
@Suite("StoredCVChangeQueue - one line of changes for each CV")
struct StoredCVChangeQueueTests {

    private let cv = UUID()
    private let otherCV = UUID()

    /// What the changes did, in order
    @MainActor
    final class Journal {
        var entries: [String] = []
    }

    @Test("A change starts when the ones queued before it for the same CV have ended")
    func changesOfOneCVRunInOrder() async {
        let queue = StoredCVChangeQueue()
        let journal = Journal()
        let gate = Gate()

        queue.enqueue(cv) { journal.entries.append("first starts"); await gate.wait(); journal.entries.append("first ends") }
        let second = queue.enqueue(cv) { journal.entries.append("second") }
        await gate.waitUntilSomeoneWaits()
        #expect(journal.entries == ["first starts"], "The second waits for the first")

        gate.open()
        await second.value

        #expect(journal.entries == ["first starts", "first ends", "second"])
    }

    @Test("A change of one CV does not wait for the changes of another")
    func differentCVsDoNotWaitForEachOther() async {
        let queue = StoredCVChangeQueue()
        let journal = Journal()
        let gate = Gate()

        queue.enqueue(cv) { await gate.wait() }
        let other = queue.enqueue(otherCV) { journal.entries.append("other CV") }
        await other.value

        #expect(journal.entries == ["other CV"])
        gate.open()
        await queue.settled(cv)
    }

    @Test("A CV with nothing queued is settled at once")
    func nothingQueuedIsSettled() async {
        let queue = StoredCVChangeQueue()

        let id = cv
        #expect(await finishes { await queue.settled(id) })
    }

    @Test("A CV is not settled while a change is queued for it, though the change has not started: it counts from the moment it is queued")
    func settledWaitsForAChangeThatHasNotStarted() async {
        let queue = StoredCVChangeQueue()
        let journal = Journal()

        queue.enqueue(cv) { journal.entries.append("change") }
        await queue.settled(cv)

        #expect(journal.entries == ["change"], "Settled came after the change, which had not started when it was queued")
    }

    @Test("A CV is settled only when every change queued for it has ended, those queued while it waits included")
    func settledWaitsForTheWholeLine() async {
        let queue = StoredCVChangeQueue()
        let journal = Journal()
        let firstGate = Gate()
        let secondGate = Gate()

        queue.enqueue(cv) { await firstGate.wait(); journal.entries.append("first") }
        let settled = Task { await queue.settled(self.cv); journal.entries.append("settled") }
        await firstGate.waitUntilSomeoneWaits()
        queue.enqueue(cv) { await secondGate.wait(); journal.entries.append("second") }

        firstGate.open()
        await secondGate.waitUntilSomeoneWaits()
        #expect(journal.entries == ["first"], "Still not settled: a second change was queued meanwhile")

        secondGate.open()
        await settled.value

        #expect(journal.entries == ["first", "second", "settled"])
    }

    @Test("A CV is settled again once its line has emptied, and a change queued then starts at once")
    func lineEmptiesAndFillsAgain() async {
        let queue = StoredCVChangeQueue()
        let journal = Journal()

        queue.enqueue(cv) { journal.entries.append("one") }
        await queue.settled(cv)
        let again = queue.enqueue(cv) { journal.entries.append("two") }
        await again.value
        await queue.settled(cv)

        #expect(journal.entries == ["one", "two"])
    }
}
