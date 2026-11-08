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
    }

    private static func world() async throws -> World {
        let browsing = Browsing()
        _ = try await browsing.stored(title: "First")
        _ = try await browsing.stored(title: "Second")
        let list = await browsing.loadedList()
        return World(first: list.rows[1], second: list.rows[0], rows: list.rows)
    }

    @Test("A new shell has nothing selected and shows the list")
    func startsWithTheList() {
        let shell = ShellNavigationModel()

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("Selecting a CV sets the selection and shows the detail on a compact screen")
    func selectShowsTheDetail() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()

        shell.select(world.first.reference)

        #expect(shell.selection == world.first.reference)
        #expect(shell.preferredColumn == .detail)
    }

    @Test("Selecting another CV replaces the selection")
    func selectReplaces() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.select(world.second.reference)

        #expect(shell.selection == world.second.reference)
    }

    @Test("Selecting the CV that is selected writes nothing")
    func reselectChangesNothing() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        let wrote = Self.writes(to: shell) { shell.select(world.first.reference) }

        #expect(!wrote)
        #expect(shell.selection == world.first.reference)
    }

    @Test("Selecting another CV is observed, so that the check of the other tests can fail")
    func selectIsObserved() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        let wrote = Self.writes(to: shell) { shell.select(world.second.reference) }

        #expect(wrote)
    }

    @Test("Deselecting with nothing selected writes nothing")
    func deselectWithoutSelectionChangesNothing() {
        let shell = ShellNavigationModel()

        let wrote = Self.writes(to: shell) { shell.deselect() }

        #expect(!wrote)
    }

    @Test("Reconciling that keeps the selection writes nothing")
    func reconcileKeepsWithoutWriting() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        let wrote = Self.writes(to: shell) { shell.reconcile(with: world.rows) }

        #expect(!wrote)
    }

    @Test("The row of the selection is the listed row with its reference")
    func selectedRowIsTheListedRow() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.second.reference)

        #expect(shell.selectedRow(in: world.rows)?.reference == world.second.reference)
        #expect(shell.selectedRow(in: world.rows)?.label == world.second.label)
    }

    @Test("There is no selected row when nothing is selected or the list does not have the CV")
    func noSelectedRow() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()

        #expect(shell.selectedRow(in: world.rows) == nil)

        shell.select(world.first.reference)

        #expect(shell.selectedRow(in: [world.second]) == nil)
        #expect(shell.selectedRow(in: []) == nil)
    }

    @Test("Going back to the list closes the open CV on a collapsed split view")
    func backToTheListDeselectsWhenCollapsed() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.columnChanged(to: .sidebar, isCollapsed: true)

        #expect(shell.selection == nil)
    }

    @Test("The sidebar the system writes while the split view changes its size class keeps the open CV")
    func sidebarWhileNotCollapsedKeepsTheSelection() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.columnChanged(to: .sidebar, isCollapsed: false)

        #expect(shell.selection == world.first.reference)
    }

    @Test("Showing the detail changes nothing, collapsed or not")
    func detailColumnChangesNothing() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.columnChanged(to: .detail, isCollapsed: true)
        shell.columnChanged(to: .detail, isCollapsed: false)

        #expect(shell.selection == world.first.reference)
    }

    @Test("Deselecting clears the selection and shows the list")
    func deselectShowsTheList() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.deselect()

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("Reconciling keeps a selection that is still listed")
    func reconcileKeeps() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.reconcile(with: world.rows)

        #expect(shell.selection == world.first.reference)
    }

    @Test("Reconciling clears a selection that is no longer listed")
    func reconcileClears() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.reconcile(with: [world.second])

        #expect(shell.selection == nil)
        #expect(shell.preferredColumn == .sidebar)
    }

    @Test("Reconciling with an empty list clears the selection")
    func reconcileEmpty() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.reconcile(with: [])

        #expect(shell.selection == nil)
    }

    @Test("Reconciling with nothing selected selects nothing")
    func reconcileWithoutSelection() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()

        shell.reconcile(with: world.rows)

        #expect(shell.selection == nil)
    }

    // MARK: Observation

    /// Whether `action` writes a property a view reads from the shell. Observation tells the views only of a write, so a
    /// guard that skips an equal value is seen here as no change.
    private static func writes(to shell: ShellNavigationModel, during action: () -> Void) -> Bool {
        let flag = Flag()
        withObservationTracking {
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
