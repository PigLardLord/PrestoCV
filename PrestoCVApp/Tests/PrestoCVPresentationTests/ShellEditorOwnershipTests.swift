import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The shell owns the open CV's editor: leaving it never waits for the store, and never loses a change the store can
/// take. The editor left is stored after it is closed, and lives until its write ended; an editor whose text no write can
/// store as it is keeps the person in it, and the verdict says why (#402).
@MainActor
@Suite("Shell editor ownership")
struct ShellEditorOwnershipTests {

    @Test("opening another CV stores the change the one left had not stored yet, with no pause to wait for")
    func openingAnotherFlushesTheOldOne() async throws {
        let world = Editing()
        let first = try await world.storedCV()
        let second = try await world.editing.stored(title: "Teaching roles", fullName: "Tobias Renn", language: "en")
        let shell = world.shell()
        shell.open(.stored(CVReference(id: first.id)))
        let left = try #require(shell.editor)
        await left.load()
        left.type(\.fullName, "Mara Ellison-Reyes")
        #expect(world.editing.writeCount == 0, "the pause has not passed, and its clock never moves here")

        let verdict = shell.open(.stored(CVReference(id: second.id)))

        #expect(verdict == .left)
        #expect(shell.selection == CVReference(id: second.id))
        #expect(shell.editor !== left, "the second CV has an editor of its own")
        await waitUntil("the left editor's change is stored") {
            await world.storedName(of: first) == "Mara Ellison-Reyes"
        }
    }

    @Test("while another window's save conflicts with the open CV, neither opening another nor going back leaves it")
    func stayedWhileConflict() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let other = try await world.editing.stored(title: "Teaching roles", fullName: "Tobias Renn", language: "en")
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        #expect(shell.open(.stored(CVReference(id: other.id))) == .stayed(.conflict))
        #expect(shell.open(.blank) == .stayed(.conflict))
        #expect(shell.deselect() == .stayed(.conflict))
        shell.columnChanged(to: .sidebar, isCollapsed: true)

        #expect(shell.editor === editor, "the person's text stays where they can still keep it")
        #expect(shell.selection == CVReference(id: cv.id))
        #expect(shell.preferredColumn == .detail)
        #expect(!shell.canLeave, "the way back is not offered while leaving would stay")
    }

    @Test("while the store refuses the open CV's text the person stays; once a write took it, they can go")
    func stayedWhileFailed() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Mara Reyes")
        await editor.saveNow()
        #expect(editor.saveStatus == .failed)

        #expect(shell.deselect() == .stayed(.failed))
        #expect(shell.editor === editor)
        #expect(!shell.canLeave)

        await editor.saveNow()
        #expect(shell.canLeave, "a write took the text, so the way back is offered again")
        #expect(shell.deselect() == .left)
        #expect(shell.editor == nil)
        #expect(await world.storedName(of: cv) == "Mara Reyes")
    }

    @Test("a text above its limit is stored by no write, so the person stays until it is shorter, and leaving then stores it")
    func stayedWhileTextTooLong() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()

        editor.type(\.summary, String(repeating: "a", count: CVLimits.maxTextCharacters + 1))
        #expect(shell.deselect() == .stayed(.textTooLong(.summary)))
        editor.type(\.summary, "Designs public services.")
        #expect(shell.deselect() == .left)
        await shell.flushAll()

        #expect(try await world.editing.inStore(cv.id).personal.summary == "Designs public services.")
    }

    @Test("a blank CV with nothing to keep yet is left at once, and nothing is written")
    func leftWhileNotEnoughContent() async throws {
        let world = Editing()
        let shell = world.shell()
        shell.open(.blank)
        let editor = try #require(shell.editor)
        await editor.load()
        #expect(editor.saveStatus == .notEnoughContent)

        #expect(shell.deselect() == .left)
        await shell.flushAll()

        #expect(shell.editor == nil)
        #expect(shell.keptEditors.isEmpty, "nothing typed, so nothing to keep")
        #expect(world.editing.writeCount == 0)
    }

    @Test("back to the list closes the CV at once; its editor, dropped by all else, lives until stored, and the list shows it")
    func deselectKeepsTheEditorUntilItStored() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        var editor = shell.editor
        await editor?.load()
        editor?.type(\.title, "Teaching roles")
        await world.editing.gate.close()

        #expect(shell.deselect() == .left)
        weak var left = editor
        editor = nil

        #expect(shell.editor == nil)
        #expect(shell.preferredColumn == .sidebar)
        await waitUntil("the left editor's write reaches the store's door") { await world.editing.gate.waiting == 1 }
        #expect(left != nil, "the navigation keeps the editor while its write runs")
        #expect(try await world.editing.inStore(cv.id).title == "Design roles")
        await world.editing.gate.open()
        await waitUntil("the editor goes once its write ended") { left == nil }
        #expect(shell.keptEditors.isEmpty, "a stored editor is not kept")
        let list = await Browsing(editing: world.editing).loadedList()
        #expect(list.rows.map(\.label) == ["Teaching roles"])
    }

    @Test("the scene going to the background stores the open CV and waits for the ones left before it, and keeps it open")
    func flushAllStoresTheOpenEditor() async throws {
        let world = Editing()
        let first = try await world.storedCV()
        let second = try await world.editing.stored(title: "Teaching roles", fullName: "Tobias Renn", language: "en")
        let shell = world.shell()
        shell.open(.stored(CVReference(id: first.id)))
        await shell.editor?.load()
        shell.editor?.type(\.fullName, "Mara Ellison-Reyes")
        await world.editing.gate.close()
        shell.open(.stored(CVReference(id: second.id)))
        let open = try #require(shell.editor)
        await open.load()
        open.type(\.fullName, "Tobias Renn-Okafor")
        await waitUntil("the first CV's write is held at the door") { await world.editing.gate.waiting == 1 }

        let returned = Returned()
        let flushing = Task { await shell.flushAll(); returned.value = true }
        await settle()
        #expect(!returned.value, "the writes are held at the store's door")
        await world.editing.gate.open()
        await flushing.value

        #expect(await world.storedName(of: first) == "Mara Ellison-Reyes")
        #expect(await world.storedName(of: second) == "Tobias Renn-Okafor")
        #expect(shell.editor === open, "the CV stays open")
    }

    @Test("a draft is in no list, so reconciling with the list keeps its editor and writes nothing")
    func reconcileKeepsADraft() async throws {
        let world = Editing()
        let shell = world.shell()
        shell.open(.blank)
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Tobias Renn")

        shell.reconcile(with: [])
        await settle()

        #expect(shell.editor === editor)
        #expect(world.editing.writeCount == 0)
    }

    @Test("a CV gone from the list stays open while its text is not stored, so the person can still keep it as a copy")
    func reconcileKeepsTextNoWriteStored() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()

        shell.reconcile(with: [])

        #expect(shell.editor === editor)
        #expect(shell.selection == CVReference(id: cv.id))
    }

    // MARK: Leaving the foreground

    @Test("leaving the foreground stores the open CV under background time, asked for before the write and given back after")
    func leavingTheForegroundHoldsTimeForTheWrite() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let time = BackgroundTimeSpy()
        time.probe = { [storesTold = world.storesTold] in storesTold.count }
        let shell = world.shell(time: time)
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison-Reyes")
        await world.editing.gate.close()

        shell.sceneChanged(isActive: false)

        #expect(time.begun == [0], "the time is asked for at once, before any write")
        await waitUntil("the write is held at the store's door") { await world.editing.gate.waiting == 1 }
        #expect(time.ended.isEmpty, "the time is kept while the write is held")
        await world.editing.gate.open()
        await waitUntil("the time is given back") { !time.ended.isEmpty }
        #expect(time.ended == [1], "given back once, after the store took the write")
        #expect(await world.storedName(of: cv) == "Mara Ellison-Reyes")
        #expect(shell.editor === editor, "the CV stays open")
    }

    @Test("a scene that is no longer active, as on its way to the background, stores the open CV at once; becoming active stores nothing")
    func inactiveStoresTheOpenCV() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let time = BackgroundTimeSpy()
        let shell = world.shell(time: time)
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison-Reyes")

        shell.sceneChanged(isActive: true)
        await settle()
        #expect(world.editing.writeCount == 0, "becoming active is no reason to store, and the pause has not passed")
        #expect(time.begun.isEmpty)

        shell.sceneChanged(isActive: false)

        await waitUntil("the open CV is stored with no pause") { await world.storedName(of: cv) == "Mara Ellison-Reyes" }
        #expect(time.begun.count == 1)
    }

    // MARK: Reopening

    @Test("reopening a CV whose write is still held gets its editor back, so the next edit follows that write with no conflict")
    func reopeningWhileItStoresReattaches() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let left = try #require(shell.editor)
        await left.load()
        left.type(\.fullName, "Mara Ellison-Reyes")
        await world.editing.gate.close()
        shell.deselect()
        await waitUntil("the left editor's write is held at the store's door") { await world.editing.gate.waiting == 1 }

        shell.open(.stored(CVReference(id: cv.id)))
        let reopened = try #require(shell.editor)
        await reopened.load()
        reopened.type(\.fullName, "Mara Reyes")
        await world.editing.gate.open()
        await reopened.saveNow()

        #expect(reopened === left, "the editor that still stores the CV is the one that opens")
        #expect(reopened.saveStatus == .saved, "no conflict with a write of the same app")
        #expect(shell.selection == CVReference(id: cv.id))
        #expect(await world.storedName(of: cv) == "Mara Reyes")
    }

    @Test("a draft is matched by the CV it stored: opening that CV while the draft's write is held gets the draft's editor back")
    func reopeningAStoredDraftReattaches() async throws {
        let world = Editing()
        let shell = world.shell()
        shell.open(.blank)
        let draft = try #require(shell.editor)
        await draft.load()
        draft.type(\.fullName, "Tobias Renn")
        await draft.saveNow()
        let id = try #require(world.editing.writes.withLock { $0.last?.id })
        draft.type(\.fullName, "Tobias Renn-Okafor")
        await world.editing.gate.close()
        shell.deselect()
        await waitUntil("the draft's write is held at the store's door") { await world.editing.gate.waiting == 1 }

        shell.open(.stored(CVReference(id: id)))
        let reopened = try #require(shell.editor)
        await reopened.load()
        reopened.type(\.professionalTitle, "Teacher")
        await world.editing.gate.open()
        await reopened.saveNow()

        #expect(reopened === draft, "the draft's editor is the one that opens its CV")
        #expect(reopened.saveStatus == .saved, "no conflict with a write of the same app")
        let stored = try await world.editing.inStore(id)
        #expect(stored.personal.fullName == "Tobias Renn-Okafor")
        #expect(stored.personal.professionalTitle == "Teacher")
    }

    // MARK: Kept after leaving

    @Test("a write that fails after the person left keeps the editor, and opening the CV again gets it back with the text")
    func failedLeaveWriteKeepsTheEditor() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let reference = CVReference(id: cv.id)
        let shell = world.shell()
        shell.open(.stored(reference))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison-Reyes")
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }

        #expect(shell.deselect() == .left, "leaving never waits for the store")
        await waitUntil("the failed editor is kept") { shell.keptEditors.count == 1 }

        let kept = try #require(shell.keptEditors.first)
        #expect(kept.reference == reference)
        #expect(kept.status == .failed)
        #expect(kept.canRetry)
        #expect(shell.open(.stored(reference)) == .left)
        #expect(shell.editor === editor, "the kept editor opens, with nothing typed dropped")
        #expect(editor.content.fullName == "Mara Ellison-Reyes")
        #expect(shell.keptEditors.isEmpty, "an editor open again is no longer kept")
    }

    @Test("the scene going to the background tries the kept editors again, and an editor stored then is no longer kept")
    func flushAllRetriesTheKeptEditors() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison-Reyes")
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        shell.deselect()
        await waitUntil("the failed editor is kept") { shell.keptEditors.count == 1 }

        await shell.flushAll()

        #expect(await world.storedName(of: cv) == "Mara Ellison-Reyes")
        #expect(shell.keptEditors.isEmpty)
    }

    @Test("Retry on a kept editor stores its text, and the editor is no longer kept")
    func retryKeptStoresTheText() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison-Reyes")
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        shell.deselect()
        await waitUntil("the failed editor is kept") { shell.keptEditors.count == 1 }
        let kept = try #require(shell.keptEditors.first)

        await shell.retryKept(kept.id)

        #expect(await world.storedName(of: cv) == "Mara Ellison-Reyes")
        #expect(shell.keptEditors.isEmpty)
        #expect(shell.editor == nil, "Retry stores the text without opening the CV")
    }

    @Test("a field that cannot be read keeps the editor once left, because its text exists only there; the notice names the field")
    func unreadableFieldKeepsTheEditor() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let reference = CVReference(id: cv.id)
        let shell = world.shell()
        shell.open(.stored(reference))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.email, "mara at example")

        #expect(shell.deselect() == .left)
        await waitUntil("the editor with the unreadable field is kept") { shell.keptEditors.count == 1 }

        let kept = try #require(shell.keptEditors.first)
        #expect(kept.reference == reference)
        #expect(kept.status == .unreadable(.email))
        #expect(!kept.canRetry, "no write stores a field that cannot be read: the person corrects it in the editor")
        shell.open(.stored(reference))
        #expect(shell.editor === editor)
        #expect(editor.content.email == "mara at example")
    }

    @Test("a draft whose first write failed is kept with no row, and opening it brings the draft back as it was")
    func openKeptDraft() async throws {
        let world = Editing()
        let shell = world.shell()
        shell.open(.blank)
        let draft = try #require(shell.editor)
        await draft.load()
        draft.type(\.fullName, "Tobias Renn")
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }

        shell.deselect()
        await waitUntil("the failed draft is kept") { shell.keptEditors.count == 1 }

        let kept = try #require(shell.keptEditors.first)
        #expect(kept.reference == nil, "the draft stored no CV")
        #expect(shell.openKept(kept.id) == .left)
        #expect(shell.editor === draft)
        if case .blank? = shell.detail {} else { Issue.record("the detail shows the draft again, not \(String(describing: shell.detail))") }
        #expect(shell.selection == nil)
        #expect(shell.keptEditors.isEmpty)
    }

    @Test("on a first run, a draft whose first write failed shows the split view, where its notice and Open and Retry are")
    func keptFirstRunDraftShowsTheSplit() async throws {
        let world = Editing()
        let shell = world.shell()
        shell.open(.blank)
        let draft = try #require(shell.editor)
        await draft.load()
        draft.type(\.fullName, "Tobias Renn")
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }

        shell.deselect()
        await waitUntil("the failed draft is kept") { shell.keptEditors.count == 1 }

        #expect(shell.detail == nil, "the draft is closed")
        #expect(shell.screen(for: .firstRun) == .split, "the welcome has no notice: the draft would look lost")
        #expect(shell.screen(for: .loading) == .split, "a reload of the first run does not hide the notice either")
    }

    @Test("opening a kept editor while the open one cannot be left stays, and keeps both")
    func openKeptStaysWhileBlocked() async throws {
        let world = Editing()
        let first = try await world.storedCV()
        let second = try await world.editing.stored(title: "Teaching roles", fullName: "Tobias Renn", language: "en")
        let shell = world.shell()
        shell.open(.stored(CVReference(id: first.id)))
        let left = try #require(shell.editor)
        await left.load()
        left.type(\.email, "mara at example")
        shell.open(.stored(CVReference(id: second.id)))
        await waitUntil("the first editor is kept") { shell.keptEditors.count == 1 }
        let open = try #require(shell.editor)
        await open.load()
        open.type(\.summary, String(repeating: "a", count: CVLimits.maxTextCharacters + 1))
        let kept = try #require(shell.keptEditors.first)

        #expect(shell.openKept(kept.id) == .stayed(.textTooLong(.summary)))
        #expect(shell.editor === open)
        #expect(shell.keptEditors.map(\.id) == [kept.id])
    }

    // MARK: Discarding

    @Test("a CV deleted elsewhere is discarded on the person's word: the detail shows nothing, and nothing is written")
    func discardAfterDeletedElsewhereClearsTheEditor() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        try await world.editing.store.delete(cv.id, revision: cv.revision)
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .deletedElsewhere)
        let writes = world.editing.writeCount

        shell.discardEditor()
        await shell.flushAll()

        #expect(shell.editor == nil)
        #expect(shell.detail == nil)
        #expect(shell.preferredColumn == .sidebar)
        #expect(shell.canLeave)
        #expect(world.editing.writeCount == writes, "nothing the person discarded is written")
        #expect(await world.storedName(of: cv) == nil, "the CV stays deleted")
    }

    @Test("Discard is refused while a copy runs: the editor stays, and its copy is stored once")
    func discardWhileACopyRunsIsRefused() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        try await world.editing.store.delete(cv.id, revision: cv.revision)
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .deletedElsewhere)
        await world.editing.duplicateGate.close()
        let copying = Task { await editor.saveAsCopy() }
        await waitUntil("the copy is held at the store's door") { await world.editing.duplicateGate.waiting == 1 }
        #expect(editor.isReplacing)

        shell.discardEditor()

        #expect(shell.editor === editor, "the editor whose copy runs stays")
        #expect(shell.detail != nil)
        await world.editing.duplicateGate.open()
        await copying.value
        #expect(editor.saveStatus == .saved)
        #expect(!editor.isReplacing)
        #expect(world.editing.copies.withLock { $0.count } == 1)
    }

    @Test("Discard does nothing unless the CV was deleted elsewhere: the editor and its text stay", arguments: LeaveVerdictTests.Case.allCases.filter { $0 != .deletedElsewhere })
    func discardIsRefusedUnlessDeletedElsewhere(_ given: LeaveVerdictTests.Case) async throws {
        let world = Editing()
        let shell = world.shell()
        let editor = try await given.reach(in: world, shell)
        #expect(editor.saveStatus == given.status)

        shell.discardEditor()

        #expect(shell.editor === editor, "only a CV deleted elsewhere, or one that could not be opened, is discarded")
        #expect(shell.detail != nil)
        await world.editing.gate.open()
    }

    @Test("a CV that is gone, or could not be opened, is closed on the person's word: the detail shows nothing")
    func discardClosesAnOpeningThatFailed() async throws {
        let world = Editing()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: world.editing.ids.next())))
        let missing = try #require(shell.editor)
        await missing.load()
        #expect(missing.opening == .missing)
        shell.discardEditor()
        #expect(shell.editor == nil)
        #expect(shell.detail == nil)

        let cv = try await world.storedCV()
        world.editing.loadErrors.withLock { $0 = [.unavailable] }
        shell.open(.stored(CVReference(id: cv.id)))
        let failed = try #require(shell.editor)
        await failed.load()
        #expect(failed.opening == .failed)
        shell.discardEditor()
        #expect(shell.editor == nil)
        #expect(shell.detail == nil)
        #expect(world.editing.writeCount == 0)
    }

    // MARK: Saving as a copy

    @Test("after a copy of a CV deleted elsewhere, the shell holds the copy: the list's reload keeps it open and selected")
    func copyOfADeletedCVStaysOpen() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        try await world.editing.store.delete(cv.id, revision: cv.revision)
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .deletedElsewhere)

        await editor.saveAsCopy()
        let copy = try #require(editor.storedReference)
        let list = await Browsing(editing: world.editing).loadedList()
        shell.reconcile(with: list.rows)

        #expect(copy != CVReference(id: cv.id))
        #expect(list.rows.map(\.reference) == [copy])
        #expect(shell.editor === editor, "the copy stays open")
        #expect(shell.selection == copy)
        #expect(shell.selectedRow(in: list.rows)?.reference == copy)
        #expect(shell.canLeave)
    }

    @Test("after a copy of a CV changed elsewhere, the copy is selected, and opening the CV it was copied from opens that CV")
    func copyOfAConflictingCVIsSelected() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let shell = world.shell()
        let original = CVReference(id: cv.id)
        shell.open(.stored(original))
        let editor = try #require(shell.editor)
        await editor.load()
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.saveAsCopy()
        let copy = try #require(editor.storedReference)

        #expect(shell.selection == copy)
        #expect(shell.open(.stored(copy)) == .left)
        #expect(shell.editor === editor, "opening the copy that is open changes nothing")
        #expect(shell.open(.stored(original)) == .left)
        #expect(shell.editor !== editor, "the CV copied from opens in an editor of its own")
        #expect(shell.selection == original)
    }
}
