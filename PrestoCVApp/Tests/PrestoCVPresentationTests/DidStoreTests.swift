import Testing
import PrestoCVDomain
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// The editor tells whoever made it each time the store took its text, so that the list shows the CV as stored (R17: the
/// callback comes through the initialiser).
@MainActor
@Suite("Did store")
struct DidStoreTests {

    @Test("each write the store took is told once, after the store holds it, never while the write is at the door")
    func calledAfterEachSuccessfulWrite() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara Ellison-Reyes")
        await world.passThePause(thenWrites: 1)
        #expect(world.storesTold.count == 0, "the write is still at the store's door")
        await world.editing.gate.open()
        await waitUntil("the first store is told") { world.storesTold.count == 1 }
        #expect(await world.storedName(of: cv) == "Mara Ellison-Reyes")

        editor.type(\.fullName, "Mara Reyes")
        await editor.saveNow()
        #expect(world.storesTold.count == 2, "one call per write")
        #expect(await world.storedName(of: cv) == "Mara Reyes")
    }

    @Test("a write the store refused is not told: the list keeps what the store holds")
    func notCalledForAFailedWrite() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }

        editor.type(\.fullName, "Mara Reyes")
        await editor.saveNow()

        #expect(world.editing.writeCount == 1, "the write reached the store's door and failed there")
        #expect(editor.saveStatus == .failed)
        #expect(world.storesTold.count == 0)
    }

    @Test("a blank CV nobody typed in is never written, so nothing is told")
    func notCalledForABlankUntouchedCV() async {
        let world = Editing()
        let editor = world.editor(.blank)
        await editor.load()

        await editor.saveNow()
        await editor.saveWhatItShows()

        #expect(world.editing.writeCount == 0)
        #expect(world.storesTold.count == 0)
    }
}
