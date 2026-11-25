import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// A PDF opened in the app is the person's newest request: it closes the sheets that cover the shell (Settings, the
/// sheet of the ways to start a CV, the report of the released app's import), so that the import or the question about
/// the file is seen (#404).
@MainActor
@Suite("A file opened while a sheet covers the shell")
struct HeldFileSheetsTests {

    private static let file = ImportValues.file
    private static let other = ImportValues.otherFile

    /// The shell on a store, and the import's report with one CV that lost details, shown over it.
    @MainActor
    struct World {
        let held = HeldFileTests.World()
        let browsing = Browsing()
        let reviewing: ReviewingFake
        let reminder = ReminderFake()
        let report: LegacyImportReportViewModel
        var shell: ShellNavigationModel { held.shell }

        init() async throws {
            let ada = try await browsing.stored(title: "Ada")
            reviewing = ReviewingFake(drops: [ada.id: [.look]])
            report = LegacyImportReportViewModel(
                reviewing: reviewing, reminder: reminder, browsing: browsing.browsing, untitled: Browsing.untitled,
                numbered: { "\($0) (\($1))" }
            )
            await report.load()
            try #require(report.isPresented)
            held.shell.legacyReport = report
        }

        func coverTheShell() {
            shell.showsSettings = true
            shell.showsNewCV = true
        }

        func expectUncovered() {
            #expect(!shell.showsSettings)
            #expect(!shell.showsNewCV)
            #expect(!report.isPresented)
        }
    }

    @Test("a file opened over Settings, the new-CV sheet and the report closes them, and the import reads it")
    func fileClosesTheSheetsAndImports() async throws {
        let world = try await World()
        world.coverTheShell()

        world.shell.receive(file: Self.file)

        world.expectUncovered()
        #expect(world.shell.importer != nil)
        #expect(world.held.imports.files.received.map(\.file.url) == [Self.file])
    }

    @Test("a file opened over an editor that cannot store closes them too, so that the question shows")
    func fileClosesTheSheetsAndAsks() async throws {
        let world = try await World()
        _ = try await world.held.conflictingEditor()
        world.coverTheShell()

        world.shell.receive(file: Self.file)

        world.expectUncovered()
        #expect(world.shell.question == .keepEditingOrDiscard(.conflict))
    }

    @Test("a newer file opened while the question shows closes the sheets opened since")
    func newerFileClosesTheSheets() async throws {
        let world = try await World()
        _ = try await world.held.conflictingEditor()
        world.shell.receive(file: Self.file)
        world.coverTheShell()

        world.shell.receive(file: Self.other)

        world.expectUncovered()
        #expect(world.shell.question == .keepEditingOrDiscard(.conflict))
    }

    @Test("the report closed by a file is closed as Not now: its old copies stay and it comes back at the next launch")
    func reportClosesAsNotNow() async throws {
        let world = try await World()

        world.shell.receive(file: Self.file)

        #expect(world.report.state == .hidden)
        #expect(world.reviewing.removals.withLock { $0 }.isEmpty, "nothing is removed")
        #expect(await world.reminder.remindsAgain())
    }

    @Test("the person's choice not to be reminded still counts when the report is closed by a file")
    func reportKeepsTheChoice() async throws {
        let world = try await World()
        world.report.remindsNoMore = true

        world.shell.receive(file: Self.file)
        await world.report.storingChoice?.value

        #expect(await !world.reminder.remindsAgain())
    }

    @Test("a file opened with no sheet over the shell leaves everything as it was")
    func noSheetNothingChanges() async throws {
        let held = HeldFileTests.World()

        held.shell.receive(file: Self.file)

        #expect(!held.shell.showsSettings && !held.shell.showsNewCV)
        #expect(held.shell.importer != nil)
    }
}
