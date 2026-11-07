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

/// A read that started before a local change of the list must not publish over it, and `.loading` lasts only while a
/// read runs.
@MainActor
@Suite("List: reads in flight")
struct CVListReadsInFlightTests {

    enum Change: CaseIterable, CustomStringConvertible {
        case rename, duplicate, delete

        var description: String {
            switch self {
            case .rename: "rename"
            case .duplicate: "duplicate"
            case .delete: "delete"
            }
        }

        func apply(to list: CVListViewModel, _ row: CVReference) async {
            switch self {
            case .rename: await list.rename(row, to: "Platform")
            case .duplicate: await list.duplicate(row, title: "Backend copy")
            case .delete: await list.delete(row)
            }
        }

        var labels: [String] {
            switch self {
            case .rename: ["Platform"]
            case .duplicate: ["Backend copy", "Backend"]
            case .delete: []
            }
        }
    }

    @Test("an older read returning during a change's editor wait does not undo the change", arguments: Change.allCases)
    func olderReadDoesNotUndoChange(change: Change) async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let row = world.reference(cv)
        await world.browsing.listGate.close()
        let older = Task { await list.load() }
        await waitUntil("the older read to hold its listing") { await world.browsing.listGate.waiting == 1 }

        await world.storedGate.close()
        let changing = Task { await change.apply(to: list, row) }
        await waitUntil("the follow-up read to wait for the editors") { await world.storedGate.waiting == 1 }
        await world.browsing.listGate.open()
        await older.value
        #expect(list.rows.map(\.label) == change.labels)

        world.browsing.listError.withLock { $0 = .unavailable }
        await world.storedGate.open()
        await changing.value
        #expect(list.rows.map(\.label) == change.labels)
        #expect(list.isStale)
        #expect(list.status == .failed)
    }

    @Test("a cancelled failed reload of a loaded empty list leaves it loaded")
    func cancelledFailedReloadKeepsEmptyListLoaded() async {
        let world = Browsing()
        let list = await world.loadedList()
        #expect(list.status == .loaded)
        await world.browsing.listGate.close()
        let reload = Task { await list.load() }
        await waitUntil("the reload to read the store") { await world.browsing.listGate.waiting == 1 }
        #expect(list.status == .loading)

        world.browsing.listError.withLock { $0 = .unavailable }
        reload.cancel()
        await world.browsing.listGate.open()
        await reload.value

        #expect(list.status == .loaded)
    }

    @Test("overlapping reloads of a loaded empty list, the latest cancelled and the older superseded, leave it loaded")
    func overlappingReloadsKeepEmptyListLoaded() async {
        let world = Browsing()
        let list = await world.loadedList()
        await world.browsing.listGate.close()
        let older = Task { await list.load() }
        await waitUntil("the older reload to read the store") { await world.browsing.listGate.waiting == 1 }
        let latest = Task { await list.load() }
        await waitUntil("the latest reload to read the store") { await world.browsing.listGate.waiting == 2 }

        world.browsing.listError.withLock { $0 = .unavailable }
        latest.cancel()
        await world.browsing.listGate.releaseNewest()
        await latest.value
        #expect(list.status == .loading)
        await world.browsing.listGate.open()
        await older.value

        #expect(list.status == .loaded)
    }
}
