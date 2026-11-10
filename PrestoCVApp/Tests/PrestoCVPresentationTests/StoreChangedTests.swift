import Testing
import PrestoCVDomain
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// The editor tells whoever made it each time the store changed: when the store took its text, and when it learnt that
/// another save or a deletion changed its CV, so that the list shows the CVs as stored (R17: the callback comes through
/// the initialiser).
@MainActor
@Suite("Store changed")
struct StoreChangedTests {

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

    @Test("a copy the store took is told, so that the list shows it before the person types again")
    func calledAfterACopyIsStored() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)
        #expect(world.storesTold.count == 1, "the conflict is told")

        await editor.saveAsCopy()

        #expect(editor.saveStatus == .saved)
        #expect(world.storesTold.count == 2, "then the copy")
    }

    @Test("a conflict a write finds is told once, so that the list shows the CV as the other save left it")
    func calledOnceWhenAWriteFindsAConflict() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")

        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)
        #expect(world.storesTold.count == 1)

        editor.type(\.fullName, "Mara Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)
        #expect(world.storesTold.count == 1, "the store did not change again")
    }

    @Test("a deletion a write finds is told, so that the list no longer shows the CV")
    func calledWhenAWriteFindsTheCVDeleted() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.delete(cv)

        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()

        #expect(editor.saveStatus == .deletedElsewhere)
        #expect(world.storesTold.count == 1)
    }

    @Test("a reload that finds the CV deleted since the conflict is told again")
    func calledWhenAReloadFindsTheCVDeleted() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(world.storesTold.count == 1)
        try await world.editing.delete(world.editing.inStore(cv.id))

        await editor.reload()

        #expect(editor.saveStatus == .deletedElsewhere)
        #expect(world.storesTold.count == 2)
    }

    @Test("a copy the store refused is not told")
    func notCalledForAFailedCopy() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        world.editing.duplicateErrors.withLock { $0 = [EditFailure.unavailable] }

        await editor.saveAsCopy()

        #expect(editor.saveStatus == .failed)
        #expect(world.storesTold.count == 1, "only the conflict was told")
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

    @Test("a conflict found again after the failure cleared is told again")
    func calledAgainForAConflictFoundAgain() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)
        #expect(world.storesTold.count == 1)

        editor.type(\.fullName, "Mara Ellison")
        #expect(editor.saveStatus == .saved, "back to the text the editor stood on: the failure cleared")

        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)
        #expect(world.storesTold.count == 2, "the editor learned it again, so the list reads the store again")
    }
}
