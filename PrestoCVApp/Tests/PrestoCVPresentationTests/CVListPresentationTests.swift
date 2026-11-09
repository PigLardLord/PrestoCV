import Testing
import PrestoCVDomain
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// What the list column shows, decided by the view model so that the views only render it (R5): the content in place of
/// the rows, the notices and their order, the actions of a row, and the row whose change did not work.
@MainActor
@Suite("CV list presentation")
struct CVListPresentationTests {

    // MARK: Content

    @Test("the list shows loading until the first read ends, then its rows")
    func loadingThenRows() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "First")
        let list = world.list()
        #expect(list.content == .loading)

        await list.load()

        #expect(list.content == .rows)
    }

    @Test("a store with no CV shows the ways to start, also beside the notice of files it could not read")
    func emptyStoreShowsTheWaysToStart() async {
        let world = Browsing()
        let list = await world.loadedList()
        #expect(list.content == .empty)

        world.browsing.issues.withLock { $0 = [.corrupt(file: "one.json", reason: "bad")] }
        await list.load()

        #expect(list.content == .empty)
        #expect(list.notices == [.unreadable(StoreNotice(kinds: [.corrupt]))])
    }

    @Test("a store that cannot be read shows its rows, none at first, with the notice that reads it again")
    func failedReadShowsTheFailedNotice() async {
        let world = Browsing()
        world.browsing.listError.withLock { $0 = .unavailable }
        let list = await world.loadedList()

        #expect(list.content == .rows)
        #expect(list.notices == [.failed])

        world.browsing.listError.withLock { $0 = nil }
        await list.load()
        #expect(list.notices.isEmpty)
    }

    // MARK: Notices

    @Test("a change stored and a list not read again shows the stale notice first, then the files it could not read")
    func staleNoticeComesFirst() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "First")
        world.browsing.issues.withLock { $0 = [.unreadable(file: "one.json")] }
        let list = await world.loadedList()

        world.browsing.listError.withLock { $0 = .unavailable }
        await list.rename(world.reference(cv), to: "Renamed")

        #expect(list.content == .rows)
        #expect(list.notices == [.stale, .unreadable(StoreNotice(kinds: [.unreadable]))])
    }

    @Test("a dismissed notice of unreadable files leaves the notices of the list")
    func dismissedNoticeLeaves() async throws {
        let world = Browsing()
        _ = try await world.stored(title: "First")
        world.browsing.issues.withLock { $0 = [.unreadable(file: "one.json")] }
        let list = await world.loadedList()

        list.dismissNotice()

        #expect(list.notices.isEmpty)
    }

    @Test("the notice counts every file and names each kind once, in the order the store met them")
    func noticeNamesEachKindOnce() {
        let notice = StoreNotice(kinds: [.corrupt, .tooLarge, .corrupt, .unreadable, .tooLarge])

        #expect(notice.count == 5)
        #expect(notice.distinctKinds == [.corrupt, .tooLarge, .unreadable])
    }

    // MARK: Rows

    @Test("a row carries the stored title, empty for a CV that has none, beside its label")
    func rowCarriesTheStoredTitle() async throws {
        let world = Browsing()
        let untitled = try await world.stored(title: "", fullName: "")
        let named = try await world.stored(title: "Backend", fullName: "")

        let list = await world.loadedList()

        let rows = Dictionary(uniqueKeysWithValues: list.rows.map { ($0.reference, $0) })
        #expect(rows[world.reference(untitled)]?.title == "")
        #expect(rows[world.reference(untitled)]?.label == Browsing.untitled)
        #expect(rows[world.reference(named)]?.title == "Backend")
    }

    @Test("a row offers duplicate, rename and delete; a swipe offers duplicate from the leading edge and delete from the trailing one")
    func rowActions() {
        let list = Browsing().list()

        #expect(list.rowActions == [.duplicate, .rename, .delete])
        #expect(list.leadingSwipeActions == [.duplicate])
        #expect(list.trailingSwipeActions == [.delete])
        // A swipe is never the only way: the menu and the actions of VoiceOver hold every action
        #expect(Set(list.leadingSwipeActions + list.trailingSwipeActions).isSubset(of: Set(list.rowActions)))
    }

    // MARK: A row whose change did not work

    @Test("a row whose change did not work is told by its label until the person dismisses it")
    func rowAlertUntilDismissed() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        #expect(list.rowAlert == nil)
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")

        await list.rename(world.reference(cv), to: "Renamed")

        let alert = try #require(list.rowAlert)
        #expect(alert.reference == world.reference(cv))
        #expect(alert.label == "Backend")
        #expect(alert.status == .conflict)

        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("of two rows whose change did not work, the first to fail is told first, the other once it is dismissed")
    func rowAlertsFollowTheOrderGiven() async throws {
        let world = Browsing()
        let one = try await world.stored(title: "One")
        let two = try await world.stored(title: "Two")
        let list = await world.loadedList()
        // Each conflict reads the list again, so the other window saves the second CV only after the first conflict
        try await world.editing.otherWindowSaves(one, fullName: "Someone Else")
        await list.rename(world.reference(one), to: "Renamed")
        try await world.editing.otherWindowSaves(two, fullName: "Someone Else")
        await list.rename(world.reference(two), to: "Renamed")
        #expect(list.rowAlert?.reference == world.reference(one))
        list.dismissRowAlert()
        #expect(list.rowAlert?.reference == world.reference(two))
        #expect(Array(list.rowStatuses.keys) == [world.reference(two)])
    }

    /// Starts a rename of each row, held in the store's door, with both CVs saved elsewhere meanwhile; the one named first
    /// fails first, then the other.
    private func renamesHeld(
        _ first: CVReference, _ second: CVReference, saved: [CV], in world: Browsing, _ list: CVListViewModel
    ) async throws -> (first: Task<Void, Never>, second: Task<Void, Never>) {
        await world.editing.renameGate.close()
        let one = Task { await list.rename(first, to: "Renamed") }
        await waitUntil("the first rename to wait") { await world.editing.renameGate.waiting == 1 }
        let two = Task { await list.rename(second, to: "Renamed") }
        await waitUntil("the second rename to wait") { await world.editing.renameGate.waiting == 2 }
        for cv in saved { try await world.editing.otherWindowSaves(cv, fullName: "Someone Else") }
        return (one, two)
    }

    @Test("the alert given stays until it is dismissed when an earlier-listed row fails after it; each failure shows once")
    func alertGivenIsNotReplacedByAnEarlierListedFailure() async throws {
        let world = Browsing()
        let one = try await world.stored(title: "One")
        let two = try await world.stored(title: "Two")
        let list = await world.loadedList()
        let listed = list.rows.map(\.reference)
        let (a, b) = (listed[0], listed[1])
        let cvs = [b, a].map { reference in reference == world.reference(one) ? one : two }
        // The later-listed row fails first
        let held = try await renamesHeld(a, b, saved: cvs, in: world, list)
        await world.editing.renameGate.releaseNewest()
        await held.second.value
        #expect(list.rowAlert?.reference == b)
        let alertOfB = try #require(list.rowAlert)
        #expect(list.rows.map(\.reference).firstIndex(of: a)! < list.rows.map(\.reference).firstIndex(of: b)!)

        await world.editing.renameGate.releaseAll()
        await held.first.value

        #expect(list.rowAlert == alertOfB)
        #expect(Set(list.rowStatuses.keys) == [a, b])
        list.dismissRowAlert()
        #expect(list.rowAlert?.reference == a)
        #expect(list.rowStatuses.keys.contains(a))
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("a reload while an alert is given does not replace it")
    func reloadKeepsTheAlertGiven() async throws {
        let world = Browsing()
        let one = try await world.stored(title: "One")
        let two = try await world.stored(title: "Two")
        let list = await world.loadedList()
        let listed = list.rows.map(\.reference)
        // Each row fails on its own: the later-listed one first
        for reference in listed.reversed() {
            let cv = reference == world.reference(one) ? one : two
            try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")
            await list.rename(reference, to: "Renamed")
        }
        let given = try #require(list.rowAlert)
        #expect(given.reference == listed[1])

        await list.load()

        #expect(list.rowAlert == given)
        list.dismissRowAlert()
        #expect(list.rowAlert?.reference == listed[0])
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
    }

    // MARK: A row whose CV is gone

    @Test("a rename of a CV deleted elsewhere keeps its alert, by the label it had, across the reload that drops the row")
    func renameGoneKeepsTheAlertAcrossTheReload() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.delete(try await world.editing.inStore(cv.id))

        await list.rename(world.reference(cv), to: "Renamed")

        #expect(list.rows.isEmpty)
        let alert = try #require(list.rowAlert)
        #expect(alert.reference == world.reference(cv))
        #expect(alert.label == "Backend")
        #expect(alert.status == .gone)

        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("a duplicate of a CV deleted elsewhere keeps its alert, by the label it had, until it is dismissed")
    func duplicateGoneKeepsTheAlertAcrossTheReload() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.delete(try await world.editing.inStore(cv.id))
        world.editing.duplicateErrors.withLock { $0 = [.deletedElsewhere] }

        await list.duplicate(world.reference(cv), title: "Backend (copy)")

        #expect(list.rows.isEmpty)
        #expect(list.rowAlert?.label == "Backend")
        #expect(list.rowAlert?.status == .gone)

        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
    }

    @Test("a delete of a CV that is already gone is a delete that worked: the row goes and no alert shows")
    func deleteGoneIsNoAlert() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        try await world.editing.delete(try await world.editing.inStore(cv.id))

        await list.delete(world.reference(cv))

        #expect(list.rows.isEmpty)
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    // MARK: A latest failure whose row another action removed

    /// The kinds of action that follow a delete of the same row and fail after it, held in the store's door.
    enum Later: CaseIterable, CustomStringConvertible {
        case rename, language

        var description: String { self == .rename ? "rename" : "language" }

        func gate(of world: Browsing) -> Gate { self == .rename ? world.editing.renameGate : world.editing.gate }

        func apply(to list: CVListViewModel, _ row: CVReference) async {
            switch self {
            case .rename: await list.rename(row, to: "Renamed")
            case .language: await list.setDocumentLanguage(row, to: "de")
            }
        }
    }

    /// Starts a delete of the row, then `later` on it, both held; the delete goes first, then `later` reaches the store.
    private func deleteThen(
        _ later: Later, _ row: CVReference, in world: Browsing, _ list: CVListViewModel, deleteFirst: () async throws -> Void
    ) async throws {
        try await deleteFirst()
        await world.editing.deleteGate.close()
        await later.gate(of: world).close()
        let deleting = Task { await list.delete(row) }
        await waitUntil("the delete to wait") { await world.editing.deleteGate.waiting == 1 }
        let following = Task { await later.apply(to: list, row) }
        await waitUntil("the later action to wait") { await later.gate(of: world).waiting == 1 }
        await world.editing.deleteGate.open()
        await deleting.value
        #expect(!list.rows.map(\.reference).contains(row))
        await later.gate(of: world).open()
        await following.value
    }

    @Test("a later action that fails as gone after a delete removed the row keeps its alert, by the label the row had", arguments: Later.allCases)
    func laterGoneAfterDeleteKeepsTheAlert(later: Later) async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()

        try await deleteThen(later, world.reference(cv), in: world, list) {}

        let alert = try #require(list.rowAlert)
        #expect(alert.reference == world.reference(cv))
        #expect(alert.label == "Backend")
        #expect(alert.status == .gone)
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("the same when the delete itself found the CV gone already", arguments: Later.allCases)
    func laterGoneAfterDeleteThatFoundItGoneKeepsTheAlert(later: Later) async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()

        try await deleteThen(later, world.reference(cv), in: world, list) {
            try await world.editing.delete(try await world.editing.inStore(cv.id))
        }

        #expect(list.rowAlert?.label == "Backend")
        #expect(list.rowAlert?.status == .gone)
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("a later action that fails for another reason after a delete removed the row keeps its alert by the label the row had")
    func laterFailureAfterDeleteKeepsTheAlert() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        world.editing.restyleErrors.withLock { $0 = [EditFailure.unavailable] }

        try await deleteThen(.language, world.reference(cv), in: world, list) {}

        let alert = try #require(list.rowAlert)
        #expect(alert.label == "Backend")
        #expect(alert.status == .failed)
        // A reload keeps it
        await list.load()
        #expect(list.rowAlert == alert)
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("two rows found gone are told in the order found, the listed row whose change did not work between them once the first is dismissed")
    func goneAlertsComeInTheOrderFound() async throws {
        let world = Browsing()
        let first = try await world.stored(title: "First")
        let second = try await world.stored(title: "Second")
        let listed = try await world.stored(title: "Listed")
        let list = await world.loadedList()
        // The second CV is found gone before the first, whatever their order in the list
        try await deleteThen(.rename, world.reference(second), in: world, list) {}
        try await deleteThen(.rename, world.reference(first), in: world, list) {}
        try await world.editing.otherWindowSaves(listed, fullName: "Someone Else")
        await list.rename(world.reference(listed), to: "Renamed")

        #expect(list.rowAlert?.reference == world.reference(second))
        #expect(list.rowAlert?.label == "Second")
        list.dismissRowAlert()
        #expect(list.rowAlert?.reference == world.reference(listed))
        list.dismissRowAlert()
        #expect(list.rowAlert?.reference == world.reference(first))
        #expect(list.rowAlert?.label == "First")
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    // MARK: A newer failure of the row whose alert is given

    @Test("a newer failure of the row, recorded while its alert is given, is told next; the dismissal removes only the one shown")
    func newerFailureWhileAlertGivenStaysPending() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let row = world.reference(cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")
        await list.rename(row, to: "Renamed")
        #expect(list.rowAlert?.status == .conflict)
        // A later action of the same row begins and fails before the alert is dismissed
        world.editing.duplicateErrors.withLock { $0 = [.unavailable] }
        await list.duplicate(row, title: "Copy")
        #expect(list.rowAlert?.status == .conflict)
        #expect(list.rowStatuses[row] == .failed)

        list.dismissRowAlert()

        #expect(list.rowAlert?.reference == row)
        #expect(list.rowAlert?.status == .failed)
        #expect(list.rowStatuses[row] == .failed)
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }

    @Test("a failure of the row after a change that worked, while the earlier alert is still given, is told next")
    func failureAfterSuccessWhileAlertGivenStaysPending() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = await world.loadedList()
        let row = world.reference(cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")
        await list.rename(row, to: "Renamed")
        #expect(list.rowAlert?.status == .conflict)
        // A change of the row works: its status goes, the alert given stays
        await list.duplicate(row, title: "Copy")
        #expect(list.rowStatuses[row] == nil)
        #expect(list.rowAlert?.status == .conflict)
        // Another change of the row fails
        world.editing.duplicateErrors.withLock { $0 = [.unavailable] }
        await list.duplicate(row, title: "Copy 2")
        #expect(list.rowStatuses[row] == .failed)

        list.dismissRowAlert()

        #expect(list.rowAlert?.reference == row)
        #expect(list.rowAlert?.status == .failed)
        list.dismissRowAlert()
        #expect(list.rowAlert == nil)
        #expect(list.rowStatuses.isEmpty)
    }
}
