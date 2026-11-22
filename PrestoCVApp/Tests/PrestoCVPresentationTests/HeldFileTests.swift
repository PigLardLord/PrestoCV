import Foundation
import Testing
import PrestoCVDomain
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// A PDF opened in the app while the open CV's text cannot be stored as it is (step 5-13e of #404): the shell holds the
/// file and asks the person whether to keep editing or to discard their edits and import it. Each file held is let go
/// once, whatever the answer, and a newer file takes the place of the one held.
@MainActor
@Suite("A file opened while the editor cannot store")
struct HeldFileTests {

    /// The shell on a store, making its import screens on the import's fakes and its export sheets on fakes of their
    /// own.
    @MainActor
    struct World {
        let editing = Editing()
        let imports: ImportWorld
        let exports = ShellExports()
        let shell: ShellNavigationModel

        init() {
            self.init(imports: ImportWorld())
        }

        /// The shell whose import answers as `imports` does.
        init(imports: ImportWorld) {
            self.imports = imports
            shell = editing.shell(exports: exports, imports: imports)
        }

        /// A stored CV open in the editor, whose edit another window's save made conflict.
        func conflictingEditor() async throws -> (cv: CV, editor: EditorViewModel) {
            let cv = try await editing.storedCV()
            shell.open(.stored(CVReference(id: cv.id)))
            let editor = try #require(shell.editor)
            await editor.load()
            try await editing.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
            editor.type(\.fullName, "Mara Ellison Lowe")
            await editor.saveNow()
            try #require(editor.saveStatus == .conflict)
            return (cv, editor)
        }

        /// A stored CV open in the editor, whose edit the store refused.
        func failedEditor() async throws -> EditorViewModel {
            let cv = try await editing.storedCV()
            shell.open(.stored(CVReference(id: cv.id)))
            let editor = try #require(shell.editor)
            await editor.load()
            editing.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
            editor.type(\.fullName, "Mara Ellison Lowe")
            await editor.saveNow()
            try #require(editor.saveStatus == .failed)
            return editor
        }
    }

    private static let file = ImportValues.file
    private static let other = ImportValues.otherFile

    @Test("a file opened over an edit another save conflicts with is held, and the question names the conflict")
    func fileOverAConflictAsksTheQuestion() async throws {
        let world = World()
        let (_, editor) = try await world.conflictingEditor()

        world.shell.receive(file: Self.file)

        #expect(world.shell.question == .keepEditingOrDiscard(.conflict))
        #expect(world.shell.editor === editor, "the person stays in the CV until they answer")
        #expect(world.shell.importer == nil)
        #expect(world.imports.files.received.map(\.file.url) == [Self.file])
        #expect(world.imports.files.recorded.isEmpty, "the file is held while the question shows, not let go")
        #expect(world.imports.files.problems(ended: false).isEmpty)
    }

    @Test("a file opened over an edit the store refused is held, and the question names the failure")
    func fileOverAFailedStoreAsksTheQuestion() async throws {
        let world = World()
        let editor = try await world.failedEditor()

        world.shell.receive(file: Self.file)

        #expect(world.shell.question == .keepEditingOrDiscard(.failed))
        #expect(world.shell.editor === editor)
        #expect(world.imports.files.received.count == 1)
        #expect(world.imports.files.recorded.isEmpty)
    }

    @Test("Keep editing lets the file go once and leaves the editor with its text and its status")
    func keepEditingLetsTheFileGo() async throws {
        let world = World()
        let (_, editor) = try await world.conflictingEditor()
        world.shell.receive(file: Self.file)

        world.shell.keepEditing()

        #expect(world.shell.question == nil)
        #expect(world.shell.editor === editor)
        #expect(editor.content.fullName == "Mara Ellison Lowe")
        #expect(editor.saveStatus == .conflict)
        #expect(world.shell.importer == nil)
        #expect(world.imports.files.recorded == [.released(Self.file)])
        #expect(world.imports.files.problems(ended: true).isEmpty)
    }

    @Test("Discard my edits and import drops the editor without storing its text, and the import reads the file held")
    func discardAndImportDropsTheEditorAndImports() async throws {
        let world = World()
        let (cv, _) = try await world.conflictingEditor()
        let writes = world.editing.editing.writeCount
        world.shell.receive(file: Self.file)

        world.shell.discardAndImport()

        #expect(world.shell.question == nil)
        #expect(world.shell.editor == nil)
        #expect(world.shell.detail == nil)
        let importer = try #require(world.shell.importer)
        #expect(importer.source == .file)
        await waitUntil("the import let its file go") { world.imports.files.released(Self.file) == 2 }
        #expect(importer.status == .ready)
        #expect(world.imports.files.reads == 1)
        #expect(world.imports.files.problems(ended: true).isEmpty, "the shell's hold and the import's, let go once")
        await settle()
        #expect(world.editing.editing.writeCount == writes, "the edits the person discarded are not written")
        #expect(await world.editing.storedName(of: cv) == "Tobias Renn")
        #expect(world.shell.keptEditors.isEmpty, "a discarded editor is not kept")
    }

    @Test("the import holds the file before the shell lets its own hold go, so the copy is never removed under it")
    func theImportHoldsTheFileBeforeTheShellLetsGo() async throws {
        let world = World()
        _ = try await world.conflictingEditor()
        world.shell.receive(file: Self.file)
        let probe = ReleaseProbe()
        let files = world.imports.files
        files.whenReleased.withLock { $0 = { _ in probe.heldWhenReleased.append(files.received.count) } }

        world.shell.discardAndImport()

        #expect(probe.heldWhenReleased.first == 2, "the import had received its own hold when the shell let go")
    }

    @Test("a newer file opened while the question shows takes the place of the one held, which is let go")
    func newerFileReplacesTheHeldOne() async throws {
        let world = World()
        _ = try await world.conflictingEditor()
        world.shell.receive(file: Self.file)

        world.shell.receive(file: Self.other)

        #expect(world.shell.question == .keepEditingOrDiscard(.conflict))
        #expect(world.imports.files.received.map(\.file.url) == [Self.file, Self.other])
        #expect(world.imports.files.received.map(\.releases) == [1, 0], "the older let go once, the newer held")
        world.shell.discardAndImport()
        await waitUntil("the import let its file go") { world.imports.files.released(Self.other) == 2 }
        #expect(world.imports.files.recorded.contains(.read(Self.other)))
        #expect(!world.imports.files.recorded.contains(.read(Self.file)))
        #expect(world.imports.files.problems(ended: true).isEmpty)
    }

    @Test("the same file opened twice while the question shows is held once, and nothing of it is let go")
    func sameFileTwiceIsHeldOnce() async throws {
        let world = World()
        _ = try await world.conflictingEditor()
        let same = URL(fileURLWithPath: "/invented/cvs/../cvs/cv.pdf")
        try #require(same != Self.file)
        world.shell.receive(file: Self.file)

        world.shell.receive(file: same)

        #expect(world.imports.files.received.count == 1)
        #expect(world.imports.files.recorded.isEmpty)
        #expect(world.shell.question == .keepEditingOrDiscard(.conflict))
    }

    @Test("with no file held, Keep editing and Discard my edits and import change nothing")
    func answersWithNothingHeldChangeNothing() async throws {
        let world = World()
        let (_, editor) = try await world.conflictingEditor()

        world.shell.keepEditing()
        world.shell.discardAndImport()

        #expect(world.shell.editor === editor)
        #expect(editor.content.fullName == "Mara Ellison Lowe")
        #expect(world.shell.importer == nil)
        #expect(world.imports.files.received.isEmpty)
    }

    @Test("asking closes the export sheet over the editor, so that the question can show")
    func askingClosesTheExportSheet() async throws {
        let world = World()
        _ = try await world.conflictingEditor()
        world.shell.openExport()
        try #require(world.shell.exportSheet != nil)

        world.shell.receive(file: Self.file)

        #expect(world.shell.exportSheet == nil)
        #expect(world.shell.question != nil)
    }

    @Test("asking closes the review's sheet over an imported draft, and the review stays")
    func askingClosesTheReviewSheet() async throws {
        let world = World(imports: ImportWorld(answers: [.success(ShellReviewTests.outcome)]))
        world.shell.showImport()
        let importer = try #require(world.shell.importer)
        importer.text = "Ada Ferro\nStructural engineer"
        importer.importText()
        await waitUntil("the draft") { importer.status == .ready }
        world.shell.importStatusChanged()
        let editor = try #require(world.shell.editor)
        await editor.load()
        let review = try #require(world.shell.review)
        review.openSheet()
        try #require(world.shell.reviewSheet === review)
        world.editing.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Ada Ferro-Renn")
        await editor.saveNow()
        try #require(editor.saveStatus == .failed)

        world.shell.receive(file: Self.file)

        #expect(world.shell.reviewSheet == nil)
        #expect(world.shell.review === review)
        #expect(world.shell.question == .keepEditingOrDiscard(.failed))
    }

    @Test("an editor that goes while the question shows takes the question with it, and the file held is let go")
    func editorGoneTakesTheQuestion() async throws {
        let world = World()
        let editor = try await world.failedEditor()
        world.shell.receive(file: Self.file)
        await editor.saveNow()
        try #require(editor.saveStatus == .saved)

        world.shell.deselect()

        #expect(world.shell.question == nil)
        #expect(world.imports.files.recorded == [.released(Self.file)])
        #expect(world.imports.files.problems(ended: true).isEmpty)
    }

    @Test("a shell that goes away while it holds a file lets the file go once")
    func shellGoneLetsTheHeldFileGo() async throws {
        let editing = Editing()
        let imports = ImportWorld()
        var shell: ShellNavigationModel? = editing.shell(imports: imports)
        let cv = try await editing.storedCV()
        shell?.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell?.editor)
        await editor.load()
        editing.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Mara Ellison Lowe")
        await editor.saveNow()
        shell?.receive(file: Self.file)
        try #require(imports.files.received.count == 1)
        weak let probe = shell

        shell = nil

        let gone = probe == nil
        #expect(gone)
        #expect(imports.files.recorded == [.released(Self.file)])
        #expect(imports.files.problems(ended: true).isEmpty)
    }
}

/// How many files the import's fake had received at each release.
@MainActor
private final class ReleaseProbe {
    var heldWhenReleased: [Int] = []
}
