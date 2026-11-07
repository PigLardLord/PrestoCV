import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What the save status says, and the two ways out of a conflict or a deletion elsewhere.
@MainActor
@Suite("Editor saves: statuses, conflicts and failures")
struct EditorSaveStatusTests {

    struct NotAnEditFailure: Error {}

    /// An editor on a stored CV whose next write meets the other window's save.
    func inConflict(_ world: Editing) async throws -> (EditorViewModel, CV) {
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        return (editor, cv)
    }

    @Test("a stale write is a conflict; the other window's CV stays and so does the person's text")
    func conflictKeepsTheOtherWindowsData() async throws {
        let world = Editing()
        let (editor, cv) = try await inConflict(world)

        #expect(editor.saveStatus == .conflict)
        #expect(await world.storedName(of: cv) == "Tobias Renn")
        #expect(editor.content.fullName == "Mara Ellison-Renn")
        #expect(!editor.isSavedOnThisDevice)
    }

    @Test("reload after a conflict takes the stored version, and a later edit saves")
    func reloadTakesStoredAndNextSaveWorks() async throws {
        let world = Editing()
        let (editor, cv) = try await inConflict(world)

        await editor.reload()
        #expect(editor.content.fullName == "Tobias Renn")
        #expect(editor.saveStatus == .saved)

        editor.type(\.fullName, "Tobias Renn-Ellison")
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: cv) == "Tobias Renn-Ellison")
    }

    @Test("reload waits for the write the old writer still runs, and the CV it loads is the other window's")
    func reloadWaitsForARunningWrite() async throws {
        let world = Editing()
        let (editor, cv) = try await inConflict(world)
        await world.editing.gate.close()
        editor.type(\.fullName, "Mara Ellison-Renn 2")
        await world.passThePause(thenWrites: 2)
        #expect(editor.saveStatus == .conflict)
        let loadsBefore = world.editing.loads.withLock { $0 }

        let reloading = Task { await editor.reload() }
        await settle()
        #expect(world.editing.loads.withLock { $0 } == loadsBefore)

        await world.editing.gate.open()
        await reloading.value

        #expect(editor.content.fullName == "Tobias Renn")
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: cv) == "Tobias Renn")
        editor.type(\.fullName, "Tobias Renn-Ellison")
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: cv) == "Tobias Renn-Ellison")
    }

    @Test("an autosave that was replaced by a reload writes nothing more")
    func replacedAutosaveWritesNothingMore() async throws {
        let world = Editing()
        let (editor, cv) = try await inConflict(world)
        editor.type(\.fullName, "Mara Ellison-Renn 2")

        await editor.reload()
        let writesBefore = world.editing.writeCount
        world.clock.advance(by: .seconds(5))
        await settle()

        #expect(world.editing.writeCount == writesBefore)
        #expect(editor.content.fullName == "Tobias Renn")
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: cv) == "Tobias Renn")
    }

    @Test("reload outside a conflict does nothing: the text and the status stay")
    func reloadOutsideAConflictDoesNothing() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")

        await editor.reload()
        #expect(world.editing.loads.withLock { $0 } == 1)
        #expect(editor.content.fullName == "Mara Ellison")
        #expect(editor.saveStatus == .saved)

        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.reload()
        #expect(world.editing.loads.withLock { $0 } == 1)
        #expect(editor.content.fullName == "Mara Ellison-Renn")
        #expect(editor.saveStatus == .pending)
    }

    @Test("text typed while reload reads the store stays: the editor keeps its writer and the conflict")
    func reloadKeepsTextTypedDuringTheRead() async throws {
        let world = Editing()
        let (editor, cv) = try await inConflict(world)
        await world.editing.loadGate.close()

        let reloading = Task { await editor.reload() }
        await waitUntil("the read to start") { await world.editing.loadGate.waiting == 1 }
        editor.type(\.fullName, "Mara Ellison-Renn 2")
        await world.editing.loadGate.open()
        await reloading.value

        #expect(editor.content.fullName == "Mara Ellison-Renn 2")
        #expect(editor.saveStatus == .conflict)
        #expect(await world.storedName(of: cv) == "Tobias Renn")

        await editor.reload()
        #expect(editor.content.fullName == "Tobias Renn")
        #expect(editor.saveStatus == .saved)
    }

    @Test("save as copy after a conflict stores the text as a new CV, and the original stays as the other window left it")
    func saveAsCopyAfterConflictStoresNewCV() async throws {
        let world = Editing()
        let (editor, cv) = try await inConflict(world)

        await editor.saveAsCopy()

        let copies = world.editing.copies.withLock { $0 }
        #expect(copies.count == 1)
        let copy = try #require(copies.first)
        #expect(copy.id != cv.id)
        #expect(copy.revision == 0)
        #expect(copy.title == "Copy of Design roles")
        #expect(editor.content.title == "Copy of Design roles")
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: copy) == "Mara Ellison-Renn")
        #expect(await world.storedName(of: cv) == "Tobias Renn")

        editor.type(\.summary, "Designs forms.")
        await editor.saveNow()
        #expect(try await world.editing.inStore(copy.id).personal.summary == "Designs forms.")
        #expect(try await world.editing.inStore(cv.id).personal.summary == "")
    }

    @Test("a CV deleted elsewhere says so, and save as copy keeps the text as a new CV")
    func deletedElsewhereOffersSaveAsCopy() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.delete(cv)

        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .deletedElsewhere)

        await editor.saveAsCopy()
        let stored = try await world.editing.store.list().cvs
        #expect(stored.map(\.personal.fullName) == ["Mara Ellison-Renn"])
        #expect(stored.map(\.id) != [cv.id])
        #expect(editor.saveStatus == .saved)
    }

    @Test("a failed write is retried by the next change, and by saveNow")
    func failedWriteRetriesOnNextChange() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }

        editor.type(\.fullName, "Mara A")
        await editor.saveNow()
        #expect(editor.saveStatus == .failed)
        #expect(editor.content.fullName == "Mara A")

        editor.type(\.fullName, "Mara B")
        await world.passThePause(thenWrites: 2)
        await waitUntil("the retry to store") { editor.saveStatus == .saved }
        #expect(await world.storedName(of: cv) == "Mara B")

        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Mara C")
        await editor.saveNow()
        #expect(editor.saveStatus == .failed)
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: cv) == "Mara C")
    }

    @Test("a failure stays shown, while the next change waits and while its write runs, until a write succeeds")
    func failureStaysUntilAWriteSucceeds() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable, EditFailure.unavailable] }

        editor.type(\.fullName, "Mara A")
        await editor.saveNow()
        await world.editing.gate.close()
        editor.type(\.fullName, "Mara B")
        #expect(editor.saveStatus == .failed)
        await world.passThePause(thenWrites: 2)
        #expect(editor.saveStatus == .failed)
        await world.editing.gate.open()
        await waitUntil("the second write to fail") { world.editing.writeErrors.withLock { $0.isEmpty } }
        await settle()
        #expect(editor.saveStatus == .failed)
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(world.editing.writeCount == 3)
    }

    @Test("an error that is no EditFailure reads as failed")
    func unknownWriteErrorIsFailed() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        world.editing.writeErrors.withLock { $0 = [NotAnEditFailure()] }

        editor.type(\.fullName, "Mara A")
        await editor.saveNow()

        #expect(editor.saveStatus == .failed)
    }

    @Test("too large, not enough content and the limits each have their own status, and none is retried in a loop")
    func tooLargeNotEnoughContentAndLimitsHaveTheirOwnStatus() async throws {
        let world = Editing()
        let blank = world.editor(.blank)
        await blank.load()
        #expect(blank.saveStatus == .notEnoughContent)

        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.type(\.fullName, "")
        #expect(editor.saveStatus == .notEnoughContent)
        await editor.saveNow()
        #expect(editor.saveStatus == .notEnoughContent)
        world.clock.advance(by: .seconds(10))
        await settle()
        #expect(world.editing.writeCount == 1)
        #expect(await world.storedName(of: cv) == "Mara Ellison")

        world.editing.writeErrors.withLock { $0 = [EditFailure.tooLarge] }
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .tooLarge)

        world.editing.writeErrors.withLock { $0 = [EditFailure.cvTooLarge] }
        editor.type(\.fullName, "Mara Ellison R")
        await editor.saveNow()
        #expect(editor.saveStatus == .tooLarge)
        world.clock.advance(by: .seconds(10))
        await settle()
        #expect(world.editing.writeCount == 3)

        let statuses: Set<SaveStatus> = [.notEnoughContent, .tooLarge, .textTooLong(.summary), .tooManyEntries(.skills), .failed]
        #expect(statuses.count == 5)
    }

    @Test("a text above its limit names its field, and is not written")
    func textTooLongNamesTheField() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)

        editor.type(\.summary, String(repeating: "a", count: CVLimits.maxTextCharacters + 1))
        #expect(editor.saveStatus == .textTooLong(.summary))
        await editor.saveNow()

        #expect(editor.saveStatus == .textTooLong(.summary))
        #expect(try await world.editing.inStore(cv.id).personal.summary == "")
        #expect(editor.content.summary.count == CVLimits.maxTextCharacters + 1)
    }

    @Test("a section above its limit names the section, and nothing is stored")
    func tooManyEntriesNamesTheSection() async throws {
        let world = Editing()
        let skills = (0...CVLimits.maxEntriesPerSection).map { Skill(name: "Skill \($0)") }
        let draft = CV(id: world.editing.ids.next(), personal: PersonalDetails(fullName: "Tobias Renn"),
                       sections: CVSections(skills: skills))
        let editor = world.editor(.draft(CVDraft(cv: draft)))
        await editor.load()

        #expect(editor.saveStatus == .tooManyEntries(.skills))
        await editor.saveNow()
        #expect(editor.saveStatus == .tooManyEntries(.skills))
        #expect(world.editing.writeCount == 0)
    }

    @Test("a cancelled write is no failure: the content waits to be written")
    func cancelledWriteIsNoFailure() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        world.editing.writeErrors.withLock { $0 = [CancellationError()] }

        editor.type(\.fullName, "Mara A")
        await editor.saveNow()
        #expect(editor.saveStatus == .pending)

        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(await world.storedName(of: cv) == "Mara A")
    }
}
