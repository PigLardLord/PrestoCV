// The surface test below imports only the presentation and not `@testable`: it uses what a view sees.
import PrestoCVApplication
import PrestoCVDomain
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

    @Test("Selecting the CV that is selected changes nothing")
    func reselectChangesNothing() async throws {
        let world = try await Self.world()
        let shell = ShellNavigationModel()
        shell.select(world.first.reference)

        shell.select(world.first.reference)

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
}
