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

        await editor.saveNow()
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
}
