import Testing
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The shell opens the export sheet over the open CV's editor: the sheet exports the form as it stands, there is one
/// sheet at a time, and it goes with the editor it was opened over (#407, step 5-12a).
@MainActor
@Suite("Shell export sheet")
struct ShellExportSheetTests {

    @Test("Export opens a sheet over the open CV and starts its export of the form as it stands, saved or not")
    func opensAndStarts() async throws {
        let world = Editing()
        let exports = ShellExports()
        let cv = try await world.storedCV()
        let shell = world.shell(exports: exports)
        shell.open(.stored(CVReference(id: cv.id)))
        let editor = try #require(shell.editor)
        await editor.load()
        editor.type(\.fullName, "Mara Ellison-Renn")

        shell.openExport()

        let sheet = try #require(shell.exportSheet, "an open CV gets a sheet")
        #expect(sheet.status == .exporting, "the shell starts the export: the view only shows it")
        exports.clock.advance(by: SheetWorld.pause)
        await waitUntil("the export reaches the port") { exports.exporter.calls == 1 }
        #expect(exports.exporter.snapshots.map(\.personal.fullName) == ["Mara Ellison-Renn"])
        #expect(world.editing.writeCount == 0, "the export writes nothing")
    }

    @Test("with no CV open, or before its editor has read it, Export opens no sheet")
    func noSheetWithoutAnOpenCV() async throws {
        let world = Editing()
        let exports = ShellExports()
        let cv = try await world.storedCV()
        let shell = world.shell(exports: exports)

        shell.openExport()
        #expect(shell.exportSheet == nil, "nothing is open")

        shell.open(.stored(CVReference(id: cv.id)))
        shell.openExport()
        #expect(shell.exportSheet == nil, "the editor has not read the CV yet")
        #expect(exports.exporter.calls == 0)
    }

    @Test("a second Export while the sheet is open keeps the same sheet and its export")
    func secondExportKeepsTheSheet() async throws {
        let world = Editing()
        let exports = ShellExports()
        let cv = try await world.storedCV()
        let shell = world.shell(exports: exports)
        shell.open(.stored(CVReference(id: cv.id)))
        await shell.editor?.load()
        shell.openExport()
        let first = try #require(shell.exportSheet)

        shell.openExport()

        #expect(shell.exportSheet === first)
        #expect(exports.made == 1, "one sheet was made")
    }

    @Test("closing the sheet stops its export and drops it")
    func closingStops() async throws {
        let world = Editing()
        let exports = ShellExports()
        await exports.exporter.gate.close()
        let cv = try await world.storedCV()
        let shell = world.shell(exports: exports)
        shell.open(.stored(CVReference(id: cv.id)))
        await shell.editor?.load()
        shell.openExport()
        let sheet = try #require(shell.exportSheet)
        exports.clock.advance(by: SheetWorld.pause)
        await waitUntil("the export waits at the gate") { await exports.exporter.gate.waiting == 1 }

        shell.closeExport()

        #expect(shell.exportSheet == nil)
        #expect(exports.exporter.cancellations.withLock { $0 } == 1, "the running export was cancelled")
        #expect(sheet.status == .idle)
        await exports.exporter.gate.releaseAll()
    }

    @Test("opening another CV or going back closes the sheet of the CV left, and stops its export")
    func leavingClosesTheSheet() async throws {
        let world = Editing()
        let exports = ShellExports()
        await exports.exporter.gate.close()
        let first = try await world.storedCV()
        let second = try await world.editing.stored(title: "Teaching roles", fullName: "Tobias Renn", language: "en")
        let shell = world.shell(exports: exports)
        shell.open(.stored(CVReference(id: first.id)))
        await shell.editor?.load()
        shell.openExport()
        let firstSheet = try #require(shell.exportSheet)
        exports.clock.advance(by: SheetWorld.pause)
        await waitUntil("the export waits at the gate") { await exports.exporter.gate.waiting == 1 }

        #expect(shell.open(.stored(CVReference(id: second.id))) == .left)

        #expect(shell.exportSheet == nil, "the sheet of the CV left is gone")
        #expect(exports.exporter.cancellations.withLock { $0 } == 1)
        #expect(firstSheet.status == .idle)

        await shell.editor?.load()
        shell.openExport()
        #expect(shell.exportSheet != nil)
        #expect(shell.deselect() == .left)
        #expect(shell.exportSheet == nil, "going back closes the sheet too")
        await exports.exporter.gate.releaseAll()
    }
}

/// Makes the shell's export sheets on the gated export port and a clock moved by hand, over the editor given, as the
/// composition does; it counts the sheets it made.
@MainActor
final class ShellExports {
    let exporter = ExportingFake()
    let files = SharedFilesFake()
    let clock = ManualClock()
    let detector = LanguageDetectorStub()
    private(set) var made = 0

    func sheet(for editor: EditorViewModel) -> ExportSheetViewModel? {
        guard let loaded = editor.exportSnapshot() else { return nil }
        made += 1
        return ExportSheetViewModel(
            exporter: exporter, files: files, snapshot: { editor.exportSnapshot() ?? loaded },
            offeredLanguages: SheetWorld.offered, appLanguage: SheetWorld.appLanguage,
            fileNamePattern: { SheetWorld.patterns[$0.tag] ?? "%@" }, onLanguageChosen: { _ in },
            languageDetector: detector, onLanguageFound: { _ in }, clock: clock, pause: SheetWorld.pause)
    }
}
