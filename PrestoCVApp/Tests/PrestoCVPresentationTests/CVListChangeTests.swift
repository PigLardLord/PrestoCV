import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

@MainActor
@Suite("CV list changes")
struct CVListChangeTests {

    @Test("rename trims to one line, saves, and the row shows the stored title")
    func renameTrimsAndShowsStoredTitle() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()

        await list.rename(world.reference(cv), to: "  Backend\nlead  ")

        #expect(try await world.editing.inStore(cv.id).title == "Backend lead")
        #expect(list.rows.map(\.title) == [.text("Backend lead")])
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("a rename over another window's save is a row status, the list reloads, and the next rename works")
    func renameConflictReloads() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")

        await list.rename(world.reference(cv), to: "Renamed")

        #expect(list.rowStatuses[world.reference(cv)] == .conflict)
        #expect(try await world.editing.inStore(cv.id).title == "Backend")
        #expect(world.browsing.listCalls.withLock { $0 } == 2)

        await list.rename(world.reference(cv), to: "Renamed")
        #expect(try await world.editing.inStore(cv.id).title == "Renamed")
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("a duplicate adds a row with the title the view supplied")
    func duplicateAddsARowWithTheSuppliedTitle() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()

        await list.duplicate(world.reference(cv), title: "Backend (copy)")

        #expect(list.rows.count == 2)
        #expect(Set(list.rows.map(\.title)) == [.text("Backend"), .text("Backend (copy)")])
        #expect(list.rows.first?.title == .text("Backend (copy)"))
    }

    @Test("a delete removes the row at the revision the row holds")
    func deleteAtSeenRevision() async throws {
        let world = Browsing()
        let kept = try await world.stored(title: "Kept")
        let removed = try await world.stored(title: "Removed")
        let list = await world.loadedList()

        await list.delete(world.reference(removed))

        #expect(list.rows.map(\.reference) == [world.reference(kept)])
        await #expect(throws: (any Error).self) { try await world.editing.inStore(removed.id) }
    }

    @Test("a delete of a row another window saved since is a conflict code, and the row stays")
    func staleDeleteIsConflictAndRowStays() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")

        await list.delete(world.reference(cv))

        #expect(list.rowStatuses[world.reference(cv)] == .conflict)
        #expect(list.rows.map(\.reference) == [world.reference(cv)])
        #expect(try await world.editing.inStore(cv.id).personal.fullName == "Someone Else")
    }

    @Test("a row already gone is reloaded away")
    func deleteGoneReloads() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.delete(try await world.editing.inStore(cv.id))

        await list.delete(world.reference(cv))

        #expect(list.rows.isEmpty)
        #expect(world.browsing.listCalls.withLock { $0 } == 2)
    }

    @Test("the document language of a row is stored, cleared, and a tag that names none changes nothing")
    func documentLanguageChangeIsStoredOrCleared() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()

        await list.setDocumentLanguage(world.reference(cv), to: "de")
        #expect(try await world.editing.inStore(cv.id).language?.tag == "de")
        #expect(list.rows.first?.language == "de")

        await list.setDocumentLanguage(world.reference(cv), to: "not a tag!")
        #expect(world.editing.languages.withLock { $0.count } == 1)

        await list.setDocumentLanguage(world.reference(cv), to: nil)
        #expect(try await world.editing.inStore(cv.id).language == nil)
        #expect(list.rows.first?.language == nil)
    }

    @Test("a cancelled task is no failure: no row status, no failed list")
    func cancelledChangeIsNoFailure() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")

        let deleting = Task { await list.delete(world.reference(cv)) }
        deleting.cancel()
        await deleting.value
        #expect(list.rowStatuses.isEmpty)

        world.browsing.listError.withLock { $0 = .unavailable }
        let loading = Task { await list.load() }
        loading.cancel()
        await loading.value
        #expect(list.status != .failed)
    }
}
