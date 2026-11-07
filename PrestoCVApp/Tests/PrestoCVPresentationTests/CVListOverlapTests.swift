import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// A value published after an await from an intent that is no longer the latest must not replace what a newer intent
/// published. Each test suspends a port, makes the second intent, releases the first and asserts.
@MainActor
@Suite("List: overlapping intents")
struct CVListOverlapTests {

    @Test("an older change that fails does not mark the row after a newer change worked")
    func olderRowFailureDoesNotOverwriteNewerSuccess() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let row = world.reference(cv)
        await world.editing.gate.close()

        let older = Task { await list.setDocumentLanguage(row, to: "it") }
        await waitUntil("the first change to start") { await world.editing.gate.waiting == 1 }
        let newer = Task { await list.setDocumentLanguage(row, to: "de") }
        await waitUntil("the second change to start") { await world.editing.gate.waiting == 2 }
        await world.editing.gate.releaseNewest()
        await newer.value
        #expect(list.rowStatuses[row] == nil)
        await world.editing.gate.open()
        await older.value

        #expect(list.rowStatuses[row] == nil)
        #expect(list.rows.first?.language == "de")
    }
}
