import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// The import in the shell's detail (#404): it shows in place of a CV, stops when the person goes elsewhere, and hands
/// its draft to the editor, which stores it like any draft (decisions 6 and 9).
@MainActor
@Suite("The shell's import")
struct ShellImportTests {

    /// The shell on a store, making its import screens on the import's fakes.
    @MainActor
    struct World {
        let editing: Editing
        let imports: ImportWorld
        let shell: ShellNavigationModel

        init() {
            editing = Editing()
            imports = ImportWorld()
            shell = editing.shell(imports: imports)
        }
    }

    private static let text = "Ada Ferro\nStructural engineer"

    /// The import shown by the shell, its text read by the port behind a closed gate.
    private static func reading(in world: World) async throws -> ImportViewModel {
        world.shell.showImport()
        let importer = try #require(world.shell.importer)
        importer.text = text
        await world.imports.hold(importer) { $0.importText() }
        return importer
    }

    /// The import shown by the shell, with its draft ready.
    private static func ready(in world: World) async throws -> ImportViewModel {
        world.shell.showImport()
        let importer = try #require(world.shell.importer)
        importer.text = text
        importer.importText()
        await waitUntil("the draft") { importer.status == .ready }
        return importer
    }

    @Test("showing the import puts it in the detail in place of the open CV, and showing it again keeps its text")
    func showImportSelectsTheImportScreen() async throws {
        let world = World()
        let cv = try await world.editing.storedCV()
        world.shell.open(.stored(CVReference(id: cv.id)))

        #expect(world.shell.showImport() == .left)

        let importer = try #require(world.shell.importer)
        #expect(world.shell.editor == nil)
        #expect(world.shell.detail == nil)
        #expect(world.shell.selection == nil)
        #expect(world.shell.preferredColumn == .detail)
        importer.text = Self.text
        world.shell.showImport()
        #expect(world.shell.importer === importer)
        #expect(importer.text == Self.text)
    }

    @Test("a way to start goes where it leads: a draft to the editor, the import to its screen, nothing nowhere")
    func startGoesWhereTheChoiceLeads() throws {
        let world = World()

        #expect(world.shell.start(at: nil) == .left)
        #expect(world.shell.importer == nil)
        #expect(world.shell.detail == nil)

        #expect(world.shell.start(at: .importCV) == .left)
        let importer = try #require(world.shell.importer)
        #expect(world.shell.preferredColumn == .detail)

        let draft = CVDraft(cv: ImportValues.cv("Ada Ferro"))
        #expect(world.shell.start(at: .draft(draft)) == .left)
        #expect(world.shell.importer == nil)
        #expect(importer.status == .idle)
        guard case .draft(let opened)? = world.shell.detail else {
            Issue.record("no draft in the detail: \(String(describing: world.shell.detail))")
            return
        }
        #expect(opened.cv == draft.cv)
    }

    @Test("an editor whose text cannot be stored as it is keeps the person in it, and no import shows")
    func showImportStaysWhileTheEditorCannotBeLeft() async throws {
        let world = World()
        let cv = try await world.editing.storedCV()
        world.shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(world.shell.editor)
        await editor.load()
        editor.type(\.summary, String(repeating: "a", count: CVLimits.maxTextCharacters + 1))

        #expect(world.shell.showImport() == .stayed(.textTooLong(.summary)))

        #expect(world.shell.importer == nil)
        #expect(world.shell.editor === editor)
    }

    @Test("the import counts as something open: a first run shows the split view, not the welcome")
    func importCountsAsOpenForTheFirstRunSwitch() {
        let shell = World().shell
        #expect(shell.screen(for: .firstRun) == .welcome)

        shell.showImport()

        #expect(shell.screen(for: .firstRun) == .split)
    }

    @Test("opening a CV stops the running import and drops it, with its text")
    func openingACVCancelsAndDropsTheImporter() async throws {
        let world = World()
        let cv = try await world.editing.storedCV()
        let importer = try await Self.reading(in: world)

        #expect(world.shell.open(.stored(CVReference(id: cv.id))) == .left)

        #expect(world.shell.importer == nil)
        #expect(importer.status == .idle)
        #expect(world.imports.importer.cancellations.withLock { $0 } == 1)
        #expect(world.shell.selection == CVReference(id: cv.id))
        await world.imports.importer.gate.open()
    }

    @Test("going back to the list stops the running import and drops it, by the person or by a collapsed split view", arguments: [false, true])
    func deselectCancelsARunningImport(collapsedSidebar: Bool) async throws {
        let world = World()
        let importer = try await Self.reading(in: world)

        if collapsedSidebar {
            world.shell.columnChanged(to: .sidebar, isCollapsed: true)
        } else {
            #expect(world.shell.deselect() == .left)
        }

        #expect(world.shell.importer == nil)
        #expect(importer.status == .idle)
        #expect(world.imports.importer.cancellations.withLock { $0 } == 1)
        #expect(world.shell.preferredColumn == .sidebar)
        await world.imports.importer.gate.open()
    }

    @Test("a list that changes leaves the import on the screen, still reading")
    func reconcileKeepsTheImportScreen() async throws {
        let world = World()
        let importer = try await Self.reading(in: world)

        world.shell.reconcile(with: [])

        #expect(world.shell.importer === importer)
        #expect(importer.status == .importing)
        await world.imports.importer.gate.open()
    }

    @Test("an imported draft opens in the editor, and the import is cleared and dropped")
    func openingAnImportedDraftOpensItsStartAndClearsTheResult() async throws {
        let world = World()
        let importer = try await Self.ready(in: world)
        let imported = try #require(importer.result)

        world.shell.open(imported)

        #expect(importer.result == nil)
        #expect(importer.status == .idle)
        #expect(world.shell.importer == nil)
        #expect(world.shell.editor != nil)
        #expect(world.shell.preferredColumn == .detail)
        guard case .draft(let draft)? = world.shell.detail else {
            Issue.record("no draft in the detail: \(String(describing: world.shell.detail))")
            return
        }
        #expect(draft.cv == ImportValues.cv("Ada Ferro"))
    }

    @Test("the view forwards each change of the import's status, and only a ready import is handed to the editor")
    func readyImportIsHandedToTheEditor() async throws {
        let world = World()
        let importer = try await Self.reading(in: world)

        world.shell.importStatusChanged()
        #expect(world.shell.importer === importer, "an import still reading stays on the screen")
        #expect(world.shell.editor == nil)

        await world.imports.importer.gate.open()
        await waitUntil("the draft") { importer.status == .ready }
        world.shell.importStatusChanged()

        #expect(world.shell.importer == nil)
        #expect(importer.result == nil)
        guard case .draft(let draft)? = world.shell.detail else {
            Issue.record("no draft in the detail: \(String(describing: world.shell.detail))")
            return
        }
        #expect(draft.cv.personal.fullName == "Ada Ferro")
    }

    @Test("a list that changes leaves the imported draft open in its editor")
    func importedDraftIsNotClearedByReconcile() async throws {
        let world = World()
        _ = try await Self.ready(in: world)
        world.shell.importStatusChanged()
        let editor = try #require(world.shell.editor)

        world.shell.reconcile(with: [])

        #expect(world.shell.editor === editor)
        guard case .draft? = world.shell.detail else {
            Issue.record("no draft in the detail: \(String(describing: world.shell.detail))")
            return
        }
    }

    @Test("an imported draft the person never edits is stored once they leave it")
    func importedDraftIsStoredOnLeavingWithoutAnEdit() async throws {
        let world = World()
        _ = try await Self.ready(in: world)
        world.shell.importStatusChanged()
        let editor = try #require(world.shell.editor)
        await editor.load()

        #expect(world.shell.deselect() == .left)

        let cv = ImportValues.cv("Ada Ferro")
        await waitUntil("the draft stored") { await world.editing.storedName(of: cv) == "Ada Ferro" }
        #expect(world.editing.editing.writeCount == 1)
    }
}
