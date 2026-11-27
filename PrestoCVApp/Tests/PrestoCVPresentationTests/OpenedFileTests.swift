import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// A PDF opened in the app from another app (step 5-13d of #404): the import shows in place of what was open and reads
/// it, as the person's own way to the import does. A file that arrives before the window's shell exists waits for it,
/// held from its arrival, and a file no import takes is let go, once.
@MainActor
@Suite("A file opened in the app")
struct OpenedFileTests {

    /// The shell on a store, making its import screens on the import's fakes, and a window's inbox that holds and lets
    /// go the files waiting on a fake of its own.
    @MainActor
    struct World {
        let editing: Editing
        let imports: ImportWorld
        let shell: ShellNavigationModel
        let inboxFiles: FileReadingFake
        let inbox: OpenedFileInbox

        init() {
            editing = Editing()
            imports = ImportWorld()
            shell = editing.shell(imports: imports)
            inboxFiles = FileReadingFake(.success(ImportValues.pdf))
            inbox = OpenedFileInbox(files: inboxFiles)
        }

        /// Waits until the import's fake let go of `file` once.
        func letGo(_ file: URL) async {
            await waitUntil("\(file.lastPathComponent) let go") { imports.files.released(file) == 1 }
        }
    }

    private static let file = ImportValues.file
    private static let other = ImportValues.otherFile

    @Test("a file opened with nothing open shows the import, which reads it at once and hands its draft to the editor")
    func fileWithNothingOpenIsImported() async throws {
        let world = World()
        world.inbox.shellReady(world.shell)
        await world.imports.files.gate.close()

        world.inbox.receive(Self.file)

        let importer = try #require(world.shell.importer)
        #expect(importer.status == .importing)
        #expect(importer.source == .file)
        #expect(world.shell.preferredColumn == .detail)
        await world.imports.files.gate.open()
        await world.letGo(Self.file)
        #expect(importer.status == .ready)
        world.shell.importStatusChanged()
        guard case .draft(let draft)? = world.shell.detail else {
            Issue.record("no draft in the detail: \(String(describing: world.shell.detail))")
            return
        }
        #expect(draft.cv.personal.fullName == "Ada Ferro")
        #expect(world.imports.files.recorded == [.read(Self.file), .released(Self.file)])
        #expect(world.imports.files.problems(ended: true).isEmpty)
        #expect(world.inboxFiles.recorded.isEmpty)
    }

    @Test("a file opened over an editor leaves it, stored with what the person typed, and the import reads the file")
    func fileOverAnEditorStoresItAndIsImported() async throws {
        let world = World()
        world.inbox.shellReady(world.shell)
        let cv = try await world.editing.storedCV()
        world.shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(world.shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison Lowe")

        world.inbox.receive(Self.file)

        #expect(world.shell.editor == nil)
        #expect(world.shell.detail == nil)
        let importer = try #require(world.shell.importer)
        #expect(importer.source == .file)
        await waitUntil("the edit stored") { await world.editing.storedName(of: cv) == "Mara Ellison Lowe" }
        await world.letGo(Self.file)
        #expect(importer.status == .ready)
        #expect(world.imports.files.recorded == [.read(Self.file), .released(Self.file)])
    }

    @Test("a file opened while the import shows is read by that import, in place of its pasted text")
    func fileWhileTheImportShowsIsReadThere() async throws {
        let world = World()
        world.inbox.shellReady(world.shell)
        world.shell.showImport()
        let importer = try #require(world.shell.importer)
        importer.text = "Ada Ferro\nStructural engineer"

        world.inbox.receive(Self.file)

        #expect(world.shell.importer === importer)
        #expect(importer.source == .file)
        await world.letGo(Self.file)
        #expect(world.imports.importer.texts.withLock { $0 }.isEmpty)
        #expect(world.imports.importer.pdfs.withLock { $0 } == [ImportValues.pdf])
    }

    @Test("an editor whose text cannot be stored as it is keeps the person in it, and the file opened is let go")
    func fileOverAnEditorThatStaysIsLetGo() async throws {
        let world = World()
        world.inbox.shellReady(world.shell)
        let cv = try await world.editing.storedCV()
        world.shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(world.shell.editor)
        await editor.load()
        editor.type(\.summary, String(repeating: "a", count: CVLimits.maxTextCharacters + 1))

        world.inbox.receive(Self.file)

        #expect(world.shell.importer == nil)
        #expect(world.shell.editor === editor)
        #expect(world.imports.files.recorded == [.released(Self.file)])
        #expect(world.imports.files.problems(ended: true).isEmpty)
    }

    @Test("a file opened while an import reads one is let go: the import goes on with the first")
    func fileWhileAnImportReadsIsLetGo() async throws {
        let world = World()
        world.inbox.shellReady(world.shell)
        await world.imports.files.gate.close()
        world.inbox.receive(Self.file)
        let importer = try #require(world.shell.importer)

        world.inbox.receive(Self.other)

        #expect(world.shell.importer === importer)
        #expect(importer.status == .importing)
        #expect(world.imports.files.released(Self.other) == 1)
        await world.imports.files.gate.open()
        await world.letGo(Self.file)
        #expect(!world.imports.files.recorded.contains(.read(Self.other)))
        #expect(world.imports.files.problems(ended: true).isEmpty)
    }

    @Test("a file opened before the window's shell exists waits for it, and the shell's import reads it once")
    func fileBeforeTheShellIsHeldAndHandedOver() async throws {
        let world = World()

        world.inbox.receive(Self.file)

        #expect(world.shell.importer == nil)
        world.inbox.shellReady(world.shell)
        let importer = try #require(world.shell.importer)
        #expect(importer.source == .file)
        await world.letGo(Self.file)
        world.inbox.shellReady(world.shell)
        #expect(world.imports.files.recorded == [.read(Self.file), .released(Self.file)])
        #expect(world.inboxFiles.received.map(\.file.url) == [Self.file])
        #expect(world.inboxFiles.recorded == [.released(Self.file)])
        #expect(world.inboxFiles.problems(ended: true).isEmpty)
    }

    @Test("a file waiting for the shell stays held until the shell's import holds it")
    func waitingFileIsHeldUntilTheImportHoldsIt() {
        let world = World()
        let seen = Seen()
        let imports = world.imports.files
        world.inboxFiles.whenReleased.withLock { $0 = { _ in seen.counts.append(imports.received.count) } }
        world.inbox.receive(Self.file)

        world.inbox.shellReady(world.shell)

        #expect(seen.counts == [1], "the import held the file when the inbox let it go")
    }

    @Test("an inbox that goes away while a file waits lets that file go once")
    func inboxGoneLetsTheWaitingFileGo() {
        let files = FileReadingFake(.success(ImportValues.pdf))
        var inbox: OpenedFileInbox? = OpenedFileInbox(files: files)
        inbox?.receive(Self.file)
        weak let probe = inbox

        inbox = nil

        let gone = probe == nil
        #expect(gone)
        #expect(files.recorded == [.released(Self.file)])
        #expect(files.problems(ended: true).isEmpty)
    }

    @Test("a newer file opened before the shell exists takes the place of the one waiting, which is let go")
    func newerHeldFileLetsTheOlderGo() async throws {
        let world = World()

        world.inbox.receive(Self.file)
        world.inbox.receive(Self.other)

        #expect(world.inboxFiles.received.map(\.file.url) == [Self.file, Self.other])
        #expect(world.inboxFiles.received.map(\.releases) == [1, 0], "the older let go once, the newer held")
        #expect(world.inboxFiles.problems(ended: false).isEmpty)
        world.inbox.shellReady(world.shell)
        await world.letGo(Self.other)
        #expect(world.imports.files.recorded == [.read(Self.other), .released(Self.other)])
        #expect(world.inboxFiles.recorded == [.released(Self.file), .released(Self.other)])
        #expect(world.inboxFiles.problems(ended: true).isEmpty)
    }

    @Test("the same file opened twice before the shell exists waits once, and nothing of it is let go")
    func sameFileTwiceIsHeldOnce() async throws {
        let world = World()
        let same = URL(fileURLWithPath: "/invented/cvs/../cvs/cv.pdf")
        try #require(same != Self.file)

        world.inbox.receive(Self.file)
        world.inbox.receive(same)

        #expect(world.inboxFiles.received.count == 1)
        #expect(world.inboxFiles.recorded.isEmpty)
        world.inbox.shellReady(world.shell)
        await waitUntil("the file let go") { world.imports.files.recorded.count == 2 }
        #expect(world.imports.files.reads == 1)
        #expect(world.imports.files.problems(ended: true).isEmpty)
        #expect(world.inboxFiles.problems(ended: true).isEmpty)
    }

    @Test("a file waiting when the app cannot open its store is let go once, and no shell gets it after")
    func heldFileIsLetGoWhenTheCompositionFails() async throws {
        let world = World()
        world.inbox.receive(Self.file)

        world.inbox.compositionFailed()

        #expect(world.inboxFiles.recorded == [.released(Self.file)])
        #expect(world.inboxFiles.problems(ended: true).isEmpty)
        world.inbox.compositionFailed()
        world.inbox.shellReady(world.shell)
        #expect(world.inboxFiles.recorded == [.released(Self.file)])
        #expect(world.shell.importer == nil)
    }

    @Test("with no file waiting, a shell ready or a failed store changes nothing")
    func nothingHeldChangesNothing() {
        let world = World()

        world.inbox.compositionFailed()
        world.inbox.shellReady(world.shell)

        #expect(world.inboxFiles.recorded.isEmpty)
        #expect(world.shell.importer == nil)
        #expect(world.shell.detail == nil)
    }
}

/// What a hook on the main actor saw, kept for the test that set it.
@MainActor
private final class Seen {
    var counts: [Int] = []
}
