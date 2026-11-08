import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// When the editor writes: a pause after the last change, one write at a time, and at once when it is left.
@MainActor
@Suite("Editor saves: coalescing and flush")
struct EditorSaveCoalescingTests {

    @Test("many edits within one pause cause one write")
    func manyEditsOneWrite() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)

        for name in ["Mara E", "Mara El", "Mara Ell", "Mara Elli", "Mara Ellis"] {
            editor.type(\.fullName, name)
            world.clock.advance(by: .milliseconds(500))
        }
        await world.passThePause(thenWrites: 1)
        await settle()

        #expect(world.editing.writeCount == 1)
    }

    @Test("the last content of a pause is the one written")
    func lastContentWins() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)

        editor.type(\.fullName, "Tobias")
        editor.type(\.fullName, "Tobias Renn")
        await world.passThePause(thenWrites: 1)
        await waitUntil("the write to end") { editor.saveStatus == .saved }

        #expect(await world.storedName(of: cv) == "Tobias Renn")
    }

    @Test("a save in flight and an edit give one create, then one update with the latest content")
    func saveInFlightPlusEditGivesCreateThenUpdate() async throws {
        let world = Editing()
        let editor = world.editor(.blank)
        await editor.load()
        await world.editing.gate.close()

        editor.type(\.fullName, "Tobias")
        await world.passThePause(thenWrites: 1)
        editor.type(\.fullName, "Tobias Renn")
        await world.editing.gate.open()
        await editor.saveNow()

        let writes = world.editing.writes.withLock { $0 }
        #expect(writes.map(\.revision) == [0, 1])
        #expect(Set(writes.map(\.id)).count == 1)
        let stored = try await world.editing.store.list().cvs
        #expect(stored.map(\.personal.fullName) == ["Tobias Renn"])
    }

    @Test("what is typed while a write runs is written after it, by the pause")
    func editDuringSaveIsNotLost() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara")
        await world.passThePause(thenWrites: 1)
        editor.type(\.fullName, "Mara Ellison-Renn")
        editor.type(\.summary, "Designs forms.")
        #expect(editor.saveStatus == .saving)
        await world.editing.gate.open()
        await waitUntil("the first write to end") { editor.saveStatus == .pending }
        await world.passThePause(thenWrites: 2)
        await waitUntil("the second write to end") { editor.saveStatus == .saved }

        let stored = try await world.editing.inStore(cv.id)
        #expect(stored.personal.fullName == "Mara Ellison-Renn")
        #expect(stored.personal.summary == "Designs forms.")
        #expect(editor.content.fullName == "Mara Ellison-Renn")
    }

    @Test("two writes never run at the same time")
    func noTwoWritesRunTogether() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara")
        await world.passThePause(thenWrites: 1)
        editor.type(\.fullName, "Mara E")
        let leaving = Task { await editor.saveNow() }
        editor.type(\.fullName, "Mara Ellison")
        await settle()
        #expect(await world.editing.gate.waiting == 1)
        #expect(world.editing.writeCount == 1)

        await world.editing.gate.open()
        await leaving.value

        #expect(world.editing.mostWritesAtOnce.withLock { $0 } == 1)
        #expect(await world.storedName(of: cv) == "Mara Ellison")
    }

    @Test("a save asked for just as the write loop ends is stored before saveNow returns")
    func saveRequestedAtLoopHandoffIsStoredBeforeReturn() async throws {
        for delay in 0..<100 {
            let world = Editing()
            let cv = try await world.storedCV()
            let editor = await world.editor(on: cv)
            await world.editing.gate.close()
            editor.type(\.fullName, "Mara")
            await world.passThePause(thenWrites: 1)
            await waitUntil("the first write at the gate") { await world.editing.gate.waiting == 1 }

            await world.editing.gate.open()
            for _ in 0..<delay { await Task.yield() }
            editor.type(\.fullName, "Mara \(delay)")
            await editor.saveNow()

            #expect(await world.storedName(of: cv) == "Mara \(delay)", "request after \(delay) yields")
            #expect(editor.saveStatus == .saved, "request after \(delay) yields")
        }
    }

    @Test("every caller of saveNow returns only once its own edits are stored")
    func everyCallerWaitsForItsOwnEdits() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara A")
        let first = Task { await editor.saveNow(); return await world.storedName(of: cv) }
        await waitUntil("the first write at the gate") { await world.editing.gate.waiting == 1 }
        editor.type(\.fullName, "Mara B")
        let second = Task { await editor.saveNow(); return await world.storedName(of: cv) }
        await settle()
        await world.editing.gate.open()

        let seenByFirst = await first.value
        let seenBySecond = await second.value
        #expect(seenByFirst == "Mara A" || seenByFirst == "Mara B")
        #expect(seenBySecond == "Mara B")
        #expect(world.editing.writeCount == 2)
    }

    @Test("leaving with a save in flight waits for it and for the edits made meanwhile")
    func closingWithSaveInFlightWaitsForIt() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await world.editing.gate.close()

        editor.type(\.fullName, "Mara")
        await world.passThePause(thenWrites: 1)
        editor.type(\.fullName, "Mara Ellison-Renn")
        let returned = Returned()
        let leaving = Task { await editor.saveNow(); returned.value = true }
        await settle()
        #expect(!returned.value)

        await world.editing.gate.open()
        await leaving.value

        #expect(world.editing.writeCount == 2)
        #expect(await world.storedName(of: cv) == "Mara Ellison-Renn")
    }

    @Test("a write in flight ends and stores its content after the view model is gone")
    func writeEndsAfterViewModelIsGone() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        var editor: EditorViewModel? = await world.editor(on: cv)
        weak let gone = editor
        await world.editing.gate.close()

        editor?.type(\.fullName, "Mara Ellison-Renn")
        await world.passThePause(thenWrites: 1)
        editor = nil
        #expect(gone == nil)

        await world.editing.gate.open()
        await waitUntil("the write to store") { await world.storedName(of: cv) == "Mara Ellison-Renn" }
    }

    @Test("a blank new CV left alone writes nothing; the first write creates it, the next ones update it")
    func blankNewCVWritesNothing() async throws {
        let world = Editing()
        let editor = world.editor(.blank)
        await editor.load()

        await editor.saveNow()
        world.clock.advance(by: .seconds(5))
        await settle()
        #expect(world.editing.writeCount == 0)
        #expect(try await world.editing.store.list().cvs.isEmpty)
        #expect(editor.saveStatus == .notEnoughContent)

        editor.type(\.fullName, "Tobias Renn")
        await editor.saveNow()
        editor.type(\.professionalTitle, "Joiner")
        await editor.saveNow()

        let writes = world.editing.writes.withLock { $0 }
        #expect(writes.map(\.revision) == [0, 1])
        let stored = try await world.editing.store.list().cvs
        #expect(stored.count == 1)
        #expect(stored.first?.personal.professionalTitle == "Joiner")
        #expect(editor.saveStatus == .saved)
    }
}
