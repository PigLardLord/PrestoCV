// The surface test below imports only the presentation and not `@testable`: it uses what a view sees.
import PrestoCVApplication
import PrestoCVDomain
import Observation
import Testing
@testable import PrestoCVPresentation

@MainActor
@Suite("Shell navigation")
struct ShellNavigationModelTests {
    private struct World {
        let first: CVRow
        let second: CVRow
        let rows: [CVRow]
        /// A CV made and not stored, as a way to start gives it.
        let draft: CVDraft
    }

    /// A shell whose editors are never loaded here: these tests are about what it opens, not what its editors store.
    private static func shell() -> ShellNavigationModel { Editing().shell() }

    private static func world() async throws -> World {
        let browsing = Browsing()
        _ = try await browsing.stored(title: "First")
        _ = try await browsing.stored(title: "Second")
        let list = await browsing.loadedList()
        let draft = CVDraft(cv: CV(id: browsing.editing.ids.next(), title: "Draft"))
        return World(first: list.rows[1], second: list.rows[0], rows: list.rows, draft: draft)
    }

    @Test("A new shell has nothing selected and shows the list")
    func startsWithTheList() {
        let shell = Self.shell()

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("Opening a draft puts it in the detail and shows the detail on a compact screen; no row is selected")
    func openDraftSelectsTheDraft() async throws {
        let world = try await Self.world()
        let shell = Self.shell()

        shell.open(.draft(world.draft))

        guard case .draft(let open)? = shell.detail else { Issue.record("expected the draft in the detail"); return }
        #expect(open.cv.id == world.draft.cv.id)
        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .detail)
    }

    @Test("A draft is not a stored CV: reconciling with the list keeps it and writes nothing")
    func reconcileKeepsADraft() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.draft(world.draft))

        let wrote = Self.writes(to: shell) {
            shell.reconcile(with: world.rows)
            shell.reconcile(with: [])
        }

        #expect(!wrote)
        guard case .draft(let open)? = shell.detail else { Issue.record("expected the draft in the detail"); return }
        #expect(open.cv.id == world.draft.cv.id)
    }

    @Test("Opening a stored CV after a draft replaces the draft")
    func openingStoredAfterDraftReplacesIt() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.draft(world.draft))

        shell.open(.stored(world.first.reference))

        #expect(shell.selection == world.first.reference)
        guard case .stored(let open)? = shell.detail else { Issue.record("expected the stored CV in the detail"); return }
        #expect(open == world.first.reference)
    }

    @Test("Going back from a draft on a collapsed split view closes it, so the welcome of a first run shows again")
    func backFromADraftClosesIt() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.draft(world.draft))

        shell.columnChanged(to: .sidebar, isCollapsed: true)

        #expect(shell.detail == nil)
        #expect(shell.screen(for: .firstRun) == .welcome)
    }

    // MARK: Screen

    @Test("A first run with nothing open shows the welcome")
    func welcomeWhileFirstRunAndNothingOpen() {
        #expect(Self.shell().screen(for: .firstRun) == .welcome)
    }

    @Test("While the store is read, the shell shows it is loading")
    func loadingWhileTheFirstRunLoads() {
        #expect(Self.shell().screen(for: .loading) == .loading)
    }

    @Test("Once a draft is open, a first run shows the split view with the draft")
    func splitOnceADraftOpens() async throws {
        let world = try await Self.world()
        let shell = Self.shell()

        shell.open(.draft(world.draft))

        #expect(shell.screen(for: .firstRun) == .split)
    }

    @Test("A store that was used, or could not be read, shows the split view", arguments: [FirstRunState.returning, .failed])
    func splitWhenNotAFirstRun(state: FirstRunState) {
        #expect(Self.shell().screen(for: state) == .split)
    }

    // MARK: Stored CVs

    @Test("Selecting a CV sets the selection and shows the detail on a compact screen")
    func selectShowsTheDetail() async throws {
        let world = try await Self.world()
        let shell = Self.shell()

        shell.open(.stored(world.first.reference))

        #expect(shell.selection == world.first.reference)
        #expect(shell.preferredColumn == .detail)
    }

    @Test("Selecting another CV replaces the selection")
    func selectReplaces() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.open(.stored(world.second.reference))

        #expect(shell.selection == world.second.reference)
    }

    @Test("Selecting the CV that is selected writes nothing")
    func reselectChangesNothing() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        let wrote = Self.writes(to: shell) { shell.open(.stored(world.first.reference)) }

        #expect(!wrote)
        #expect(shell.selection == world.first.reference)
    }

    @Test("Selecting another CV is observed, so that the check of the other tests can fail")
    func selectIsObserved() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        let wrote = Self.writes(to: shell) { shell.open(.stored(world.second.reference)) }

        #expect(wrote)
    }

    @Test("Deselecting with nothing selected writes nothing")
    func deselectWithoutSelectionChangesNothing() {
        let shell = Self.shell()

        let wrote = Self.writes(to: shell) { shell.deselect() }

        #expect(!wrote)
    }

    @Test("Reconciling that keeps the selection writes nothing")
    func reconcileKeepsWithoutWriting() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        let wrote = Self.writes(to: shell) { shell.reconcile(with: world.rows) }

        #expect(!wrote)
    }

    @Test("The row of the selection is the listed row with its reference")
    func selectedRowIsTheListedRow() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.second.reference))

        #expect(shell.selectedRow(in: world.rows)?.reference == world.second.reference)
        #expect(shell.selectedRow(in: world.rows)?.label == world.second.label)
    }

    @Test("There is no selected row when nothing is selected or the list does not have the CV")
    func noSelectedRow() async throws {
        let world = try await Self.world()
        let shell = Self.shell()

        #expect(shell.selectedRow(in: world.rows) == nil)

        shell.open(.stored(world.first.reference))

        #expect(shell.selectedRow(in: [world.second]) == nil)
        #expect(shell.selectedRow(in: []) == nil)
    }

    @Test("Going back to the list closes the open CV on a collapsed split view")
    func backToTheListDeselectsWhenCollapsed() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.columnChanged(to: .sidebar, isCollapsed: true)

        #expect(shell.selection == nil)
    }

    @Test("Going back from a row's page keeps the open CV: the sidebar comes before the page closes")
    func backFromARowsPageKeepsTheCV() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))
        let editor = try #require(shell.editor)
        editor.layoutChanged(isNarrow: true)
        editor.addRow(to: .experiences)
        try #require(editor.openedEntry != nil)

        shell.columnChanged(to: .sidebar, isCollapsed: true)
        editor.closeEntry()

        #expect(shell.selection == world.first.reference)
        #expect(shell.editor === editor)
        #expect(shell.preferredColumn == .detail)

        shell.columnChanged(to: .sidebar, isCollapsed: true)

        #expect(shell.selection == nil, "once the page is closed, the sidebar is the person going back to the list")
    }

    @Test("Going to the list from a row's page by the back button's menu closes the open CV once the list clears it")
    func menuJumpFromARowsPageClosesTheCV() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))
        let editor = try #require(shell.editor)
        editor.layoutChanged(isNarrow: true)
        editor.addRow(to: .experiences)
        try #require(editor.openedEntry != nil)

        // On iOS 27.0 the pop to the root writes the column and closes the page at once: the column is read while the
        // page is open
        shell.columnChanged(to: .sidebar, isCollapsed: true)
        editor.closeEntry()
        #expect(shell.selection == world.first.reference)

        // The list's own write of its selection, about half a second later
        shell.deselect()

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("The back button's menu closes the open CV when the list clears it before the page closes")
    func menuJumpClearingTheListBeforeThePageClosesTheCV() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))
        let editor = try #require(shell.editor)
        editor.layoutChanged(isNarrow: true)
        editor.addRow(to: .experiences)
        try #require(editor.openedEntry != nil)

        // On iOS 26.5 the pop to the root writes the column, then the list's selection, then closes the page, at once
        shell.columnChanged(to: .sidebar, isCollapsed: true)
        shell.deselect()
        editor.closeEntry()

        #expect(shell.selection == nil)
        #expect(shell.editor == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("The sidebar the system writes while the split view changes its size class keeps the open CV")
    func sidebarWhileNotCollapsedKeepsTheSelection() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.columnChanged(to: .sidebar, isCollapsed: false)

        #expect(shell.selection == world.first.reference)
    }

    @Test("Showing the detail changes nothing, collapsed or not")
    func detailColumnChangesNothing() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.columnChanged(to: .detail, isCollapsed: true)
        shell.columnChanged(to: .detail, isCollapsed: false)

        #expect(shell.selection == world.first.reference)
    }

    @Test("Deselecting clears the selection and shows the list")
    func deselectShowsTheList() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.deselect()

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("Reconciling keeps a selection that is still listed")
    func reconcileKeeps() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.reconcile(with: world.rows)

        #expect(shell.selection == world.first.reference)
    }

    @Test("Reconciling clears a selection that is no longer listed")
    func reconcileClears() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.reconcile(with: [world.second])

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("Reconciling with an empty list clears the selection")
    func reconcileEmpty() async throws {
        let world = try await Self.world()
        let shell = Self.shell()
        shell.open(.stored(world.first.reference))

        shell.reconcile(with: [])

        #expect(shell.selection == nil)
    }

    @Test("Reconciling with nothing selected selects nothing")
    func reconcileWithoutSelection() async throws {
        let world = try await Self.world()
        let shell = Self.shell()

        shell.reconcile(with: world.rows)

        #expect(shell.selection == nil)
    }

    // MARK: Observation

    /// Whether `action` writes a property a view reads from the shell. Observation tells the views only of a write, so a
    /// guard that skips an equal value is seen here as no change.
    private static func writes(to shell: ShellNavigationModel, during action: () -> Void) -> Bool {
        let flag = Flag()
        withObservationTracking {
            _ = shell.detail
            _ = shell.editor
            _ = shell.selection
            _ = shell.preferredColumn
        } onChange: {
            flag.raised = true
        }
        action()
        return flag.raised
    }

    /// Set from the observation's callback, which runs on the writer's thread, the main actor here.
    private final class Flag: @unchecked Sendable {
        var raised = false
    }
}
