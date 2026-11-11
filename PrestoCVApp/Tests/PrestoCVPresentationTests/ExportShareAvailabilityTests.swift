import Foundation
import Testing
@testable import PrestoCVPresentation

/// When the sheet's Share can be used, and how the sheet closes after a share.
@MainActor
@Suite("Export sheet share availability")
struct ExportShareAvailabilityTests {

    /// The ways an export ends without a PDF: what the CV lacks, and a failure of the export.
    enum NoPDF: CaseIterable {
        case nameMissing, languageMissing, exportFailed
    }

    struct NotAnExportFailure: Error {}

    /// A sheet that has made its PDF.
    private func exported(in world: SheetWorld) async -> ExportSheetViewModel {
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the PDF") { sheet.document != nil }
        return sheet
    }

    // MARK: - Share

    @Test("Share waits for the PDF: unavailable before the export, preparing while it runs, ready with the PDF")
    func shareWaitsForThePDF() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        #expect(sheet.shareAvailability == .unavailable)
        await world.exporter.gate.close()

        sheet.start()
        #expect(sheet.shareAvailability == .preparing, "the pause counts as part of the export")

        await world.passThePause(thenExports: 1)
        await world.held(1)
        #expect(sheet.shareAvailability == .preparing, "the export runs")
        await world.exporter.gate.open()
        await waitUntil("the PDF") { sheet.document != nil }
        #expect(sheet.shareAvailability == .ready)
    }

    @Test("Share is unavailable when the export ends without a PDF", arguments: NoPDF.allCases)
    func shareIsUnavailableWithoutAPDF(_ case: NoPDF) async {
        let world = SheetWorld()
        switch `case` {
        case .nameMissing: world.cv = SheetWorld.cv(fullName: "")
        case .languageMissing: world.cv = SheetWorld.cv(language: nil)
        case .exportFailed: world.exporter.returns(.failure(NotAnExportFailure()))
        }
        let sheet = world.sheet()

        sheet.start()
        world.passThePause()
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.document == nil)
        #expect(sheet.shareAvailability == .unavailable)
    }

    @Test("A new export makes Share wait again")
    func newExportMakesShareWait() async {
        let world = SheetWorld()
        let sheet = await exported(in: world)

        sheet.refresh()

        #expect(sheet.shareAvailability == .preparing)
    }

    @Test("Share is preparing while the file is written, and ready again when the write fails")
    func shareWaitsForTheFile() async {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        await world.files.gate.close()
        world.files.fails(true)

        sheet.share()
        await waitUntil("the write held") { await world.files.gate.waiting == 1 }
        #expect(sheet.shareAvailability == .preparing)

        await world.files.gate.open()
        await waitUntil("the failed write") { sheet.shareAvailability != .preparing }
        #expect(sheet.shareAvailability == .ready, "the next tap tries again")
        #expect(sheet.openShare == nil)
    }

    @Test("The end of the sheet makes Share unavailable, also while a file is written")
    func stopMakesShareUnavailable() async {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        await world.files.gate.close()
        sheet.share()
        await waitUntil("the write held") { await world.files.gate.waiting == 1 }

        sheet.stop()

        #expect(sheet.shareAvailability == .unavailable)
        await world.files.gate.open()
    }

    // MARK: - Close or Done

    @Test("The sheet closes as Done after a save or a send, and as Close otherwise",
          arguments: [(ShareResult.saved, true), (.sent, true), (.other, false), (.cancelled, false), (.failed, false)])
    func closesAsDoneAfterAShare(result: ShareResult, done: Bool) async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        #expect(!sheet.closesAsDone)

        sheet.shareEnded(result, of: try #require(sheet.documentID))

        #expect(sheet.closesAsDone == done)
    }

    @Test("A new export closes as Close again: Done is about the PDF that was shared")
    func newExportClosesAsCloseAgain() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        sheet.shareEnded(.saved, of: try #require(sheet.documentID))

        sheet.refresh()

        #expect(!sheet.closesAsDone)
    }
}
