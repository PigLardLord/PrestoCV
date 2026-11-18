import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What the sheet says of an export that ended, and what it sends to the port.
@MainActor
@Suite("Export sheet status")
struct ExportSheetStatusTests {

    struct FailureRow: Sendable, CustomTestStringConvertible {
        let failure: ExportFailure
        let status: ExportStatus
        var testDescription: String { "\(failure)" }
    }

    nonisolated static let failures: [FailureRow] = [
        FailureRow(failure: .notReady, status: .notReady),
        FailureRow(failure: .unsupportedLanguage, status: .unsupportedLanguage),
        FailureRow(failure: .invalidDocument, status: .invalid),
        FailureRow(failure: .incomplete(missing: 2), status: .incomplete(missing: 2)),
        FailureRow(failure: .textNotVisible(lines: 2), status: .textNotVisible(lines: 2)),
        FailureRow(failure: .renderingFailed, status: .failed),
    ]

    @Test("Each export failure has its status, with how many texts are missing or lines hidden", arguments: failures)
    func eachExportFailureHasItsStatus(row: FailureRow) async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.exporter.returns(.failure(row.failure))

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == row.status)
        #expect(sheet.document == nil)
    }

    @Test("A PDF shorter than the CV needs keeps both page counts")
    func truncatedKeepsBothPageCounts() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.exporter.returns(.success(ExportOutcome(pdf: Data([7]), pageCount: 2, requiredPages: 3)))

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .truncated(pages: 2, required: 3))
        #expect(sheet.document == ExportedDocument(pdf: Data([7]), pages: 2), "the PDF is still shown, and can be shared")
    }

    @Test("A language without headings is reported, and the PDF is never made in another language")
    func unsupportedLanguageIsNotAnotherLanguage() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: "tlh")
        let sheet = world.sheet()
        world.exporter.returns(.failure(ExportFailure.unsupportedLanguage))

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }
        await settle()

        #expect(sheet.status == .unsupportedLanguage)
        #expect(sheet.document == nil)
        #expect(world.exporter.languages.map(\.tag) == ["tlh"], "one export, in the CV's own language")
    }

    struct NotAnExportFailure: Error {}

    @Test("Any error that is not an export failure, nor a cancellation, is failed")
    func anyOtherErrorIsFailed() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.exporter.returns(.failure(NotAnExportFailure()))

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .failed)
        #expect(sheet.document == nil)
    }

    @Test("An export takes the CV as it stands when the pause ends, saved or not, and once: a later change is not in it")
    func exportUsesTheSnapshotOfTheMoment() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        await world.exporter.gate.close()

        sheet.start()
        world.cv = SheetWorld.cv(fullName: "Ada Brook")
        await world.passThePause(thenExports: 1)
        world.cv = SheetWorld.cv(fullName: "Ada Brook-Lune")
        await world.exporter.gate.open()
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(world.exporter.snapshots.map(\.personal.fullName) == ["Ada Brook"])
        #expect(world.snapshotsTaken == 1, "the snapshot is read once per export")
    }

    @Test("refresh() exports again after the pause, with the CV as it stands then: a look changed while the sheet is open")
    func refreshUsesTheNewSnapshot() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the first export to end") { sheet.status != .exporting }
        world.cv = SheetWorld.cv(design: "classic")

        sheet.refresh()

        #expect(sheet.status == .exporting)
        #expect(sheet.document == nil, "the PDF on screen has the look left behind")
        await world.passThePause(thenExports: 2)
        await waitUntil("the second export to end") { sheet.status != .exporting }
        #expect(world.exporter.snapshots.map(\.design?.design) == [nil, "classic"])
        #expect(sheet.status == .done(pages: 1))
    }

    @Test("An export over the editor's snapshot sends the form as it stands, and never touches the store nor the save status")
    func neverTouchesTheStore() async throws {
        let store = Editing()
        let editor = await store.editor(on: try await store.storedCV())
        editor.type(\.fullName, "Mara Ellison-Renn")
        let world = SheetWorld()
        let sheet = ExportSheetViewModel(
            exporter: world.exporter, files: world.files, snapshot: { editor.exportSnapshot()! },
            offeredLanguages: SheetWorld.offered,
            appLanguage: SheetWorld.appLanguage, fileNamePattern: { SheetWorld.patterns[$0.tag] ?? "%@" },
            onLanguageChosen: { _ in }, languageDetector: world.detector, onLanguageFound: { _ in },
            clock: world.clock, pause: SheetWorld.pause)

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }
        await settle()

        #expect(world.exporter.snapshots.map(\.personal.fullName) == ["Mara Ellison-Renn"])
        #expect(sheet.status == .done(pages: 1))
        #expect(store.editing.loads.withLock { $0 } == 1, "only the editor's opening read the store")
        #expect(store.editing.writeCount == 0)
        #expect(editor.saveStatus == .pending, "the form still waits for its own pause")
    }
}
