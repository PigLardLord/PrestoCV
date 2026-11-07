import Testing
import PrestoCVApplication
import PrestoCVDomain
@testable import PrestoCVPresentation

@MainActor
@Suite("CV list")
struct CVListViewModelTests {

    @Test("rows follow the listing: one per CV, in the order the store gives")
    func rowsFollowTheListingOrder() async throws {
        let world = Browsing()
        let first = try await world.stored(title: "First")
        let second = try await world.stored(title: "Second")
        let third = try await world.stored(title: "Third")

        let list = await world.loadedList()

        #expect(list.rows.map(\.reference) == [third, second, first].map(world.reference))
        #expect(list.rows.map(\.label) == ["Third", "Second", "First"])
        #expect(list.status == .loaded)
    }

    @Test("a store issue never hides the other CVs")
    func storeIssueKeepsOtherRows() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "First")
        _ = try await world.stored(title: "Second")
        world.browsing.issues.withLock { $0 = [.corrupt(file: "one.json", reason: "bad")] }

        let list = await world.loadedList()

        #expect(list.rows.count == 2)
        #expect(list.notice?.kinds == [.corrupt])
    }

    @Test("issues show their kind and their count, never a path")
    func issuesShowKindAndCountNotPaths() async throws {
        let world = Browsing()
        world.browsing.issues.withLock {
            $0 = [
                .corrupt(file: "/private/user/one.json", reason: "unexpected token"),
                .upgradeRequired(file: "/private/user/two.json", version: 9),
                .unreadable(file: "/private/user/three.json"),
                .tooLarge(file: "/private/user/four.json", bytes: 90_000_000),
                .quarantineFailed(file: "/private/user/five.json"),
            ]
        }

        let list = await world.loadedList()

        let notice = try #require(list.notice)
        #expect(notice.count == 5)
        #expect(notice.kinds == [.corrupt, .upgradeRequired, .unreadable, .tooLarge, .quarantineFailed])
        #expect(strings(in: notice).isEmpty)
    }

    @Test("dismissing the notice hides it for this launch, also after a reload")
    func dismissingTheNoticeHidesItForThisLaunch() async {
        let world = Browsing()
        world.browsing.issues.withLock { $0 = [.unreadable(file: "one.json")] }
        let list = await world.loadedList()
        #expect(list.notice != nil)

        list.dismissNotice()
        await list.load()

        #expect(list.notice == nil)
    }

    @Test("a list that fails to load says so and keeps the rows it had")
    func failedListKeepsLoadedRows() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "First")
        _ = try await world.stored(title: "Second")
        let list = await world.loadedList()

        world.browsing.listError.withLock { $0 = .unavailable }
        await list.load()

        #expect(list.status == .failed)
        #expect(list.rows.count == 2)
        #expect(!list.isStale)
    }

    @Test("after a change that succeeded, a list that cannot be read again is out of date and keeps its rows")
    func staleNoticeAfterChangeThenFailedReload() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "First")
        let list = await world.loadedList()

        world.browsing.listError.withLock { $0 = .unavailable }
        await list.rename(world.reference(cv), to: "Renamed")

        #expect(list.isStale)
        #expect(list.rows.count == 1)
        #expect(list.rows.first?.label == "Renamed")

        world.browsing.listError.withLock { $0 = nil }
        await list.load()
        #expect(!list.isStale)
        #expect(list.status == .loaded)
    }

    @Test("titles that read alike get different labels, and an untitled CV is called by the view's word")
    func alikeTitlesGetDifferentLabels() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "Backend", fullName: "")
        _ = try await world.stored(title: "backend ", fullName: "")
        _ = try await world.stored(title: "BACKEND", fullName: "")
        _ = try await world.stored(title: "", fullName: "")
        _ = try await world.stored(title: "", fullName: "")

        let list = await world.loadedList()

        let labels = list.rows.map(\.label)
        #expect(Set(labels).count == 5)
        #expect(labels.filter { $0.lowercased().hasPrefix("backend") }.count == 3)
        #expect(labels.contains(Browsing.untitled))
        #expect(labels.contains("\(Browsing.untitled) 2"))
    }

    @Test("an untitled CV and a CV titled with the view's word for untitled get different labels")
    func untitledAndNamedLikeTheWordDiffer() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "", fullName: "")
        _ = try await world.stored(title: Browsing.untitled, fullName: "")

        let list = await world.loadedList()

        let labels = list.rows.map(\.label)
        #expect(labels.count == 2)
        #expect(Set(labels).count == 2)
        #expect(labels.contains(Browsing.untitled))
    }

    @Test("a number never gives the label another row already shows")
    func numberAvoidsARealTitle() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "Backend", fullName: "")
        _ = try await world.stored(title: "Backend", fullName: "")
        _ = try await world.stored(title: "Backend (2)", fullName: "")

        let list = await world.loadedList()

        let labels = list.rows.map(\.label)
        #expect(Set(labels).count == 3)
        #expect(labels.contains("Backend (2)"))
        #expect(labels.contains("Backend"))
        #expect(labels.contains("Backend (3)"))
    }

    @Test("the labels are the same after a reload")
    func labelsAreStableAcrossReloads() async throws {
        let world = Browsing()
        for _ in 0..<4 { _ = try await world.stored(title: "Backend", fullName: "") }
        let list = await world.loadedList()
        let before = Dictionary(uniqueKeysWithValues: list.rows.map { ($0.reference, $0.label) })

        await list.load()

        let after = Dictionary(uniqueKeysWithValues: list.rows.map { ($0.reference, $0.label) })
        #expect(before == after)
        #expect(Set(before.values).count == 4)
    }

    @Test("the last-saved line is the store's instant, and `now` moves only when the clock is read again")
    func lastSavedMovesOnlyWithTheClock() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "First")
        let list = await world.loadedList()
        let start = world.moment.date
        #expect(list.now == start)
        #expect(list.rows.first?.lastSaved == cv.updatedAt)

        world.moment.date = start.addingTimeInterval(3_600)
        await list.load()
        #expect(list.now == start.addingTimeInterval(3_600))

        world.moment.date = start.addingTimeInterval(7_200)
        #expect(list.now == start.addingTimeInterval(3_600))
        list.refreshNow()
        #expect(list.now == start.addingTimeInterval(7_200))
    }

    @Test("the store is read only after the editors that were left have stored")
    func readsTheStoreAfterEditorsStored() async {
        let world = Browsing()
        let list = world.list()
        await world.storedGate.close()

        let loading = Task { await list.load() }
        await waitUntil("the list waits for the editors") { await world.storedGate.waiting == 1 }
        await settle()
        #expect(world.browsing.listCalls.withLock { $0 } == 0)

        await world.storedGate.open()
        await loading.value
        #expect(world.browsing.listCalls.withLock { $0 } == 1)
        #expect(list.status == .loaded)
    }
}
