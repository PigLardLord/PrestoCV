import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// When the sheet exports: once per pause, the latest intent winning, and a superseded export changing nothing.
@MainActor
@Suite("Export sheet flow")
struct ExportSheetFlowTests {

    @Test("start() makes one export, after the pause, and shows its PDF")
    func startsOneExport() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.start()
        #expect(sheet.status == .exporting)
        await settle()
        #expect(world.exporter.calls == 0, "nothing is exported before the pause has passed")

        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.document == ExportedDocument(pdf: Data([1, 2, 3]), pages: 1))
        await settle()
        #expect(world.exporter.calls == 1)
    }

    @Test("Choices made within one pause make one export, in the language chosen last")
    func severalSelectionsWithinOnePauseGiveOneExport() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.start()
        world.clock.advance(by: .milliseconds(100))
        sheet.select(language: SheetWorld.language("de"))
        world.clock.advance(by: .milliseconds(100))
        sheet.select(language: SheetWorld.english)
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }
        await settle()

        #expect(world.exporter.calls == 1, "the pause starts again at each choice, so only the last one exports")
        #expect(world.exporter.languages.withLock { $0 }.map(\.tag) == ["en"])
    }

    @Test("A choice made while an export runs cancels that export")
    func newSelectionCancelsTheRunningExport() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        await world.exporter.gate.close()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.select(language: SheetWorld.language("de"))

        #expect(world.exporter.cancellations.withLock { $0 } == 1, "the export of the old language is no longer wanted")
        await world.exporter.gate.open()
    }

    @Test("The late result of a cancelled export changes nothing: the newer export's PDF and status stay")
    func lateResultOfACancelledExportIsDropped() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        await world.exporter.gate.close()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await world.held(1)
        sheet.select(language: SheetWorld.language("de"))
        await world.passThePause(thenExports: 2)
        await world.held(2)

        await world.exporter.gate.releaseNewest()
        await waitUntil("the newer export to end") { sheet.status != .exporting }
        world.exporter.returns(.success(ExportOutcome(pdf: Data([9]), pageCount: 2, requiredPages: 2)))
        await world.exporter.gate.releaseAll()
        await settle()

        #expect(sheet.status == .done(pages: 1), "the cancelled export returned late, after the newer one")
        #expect(sheet.document == ExportingFake.onePageDocument)
    }

    @Test("A new export drops the PDF of the last one at once, so the PDF in the old language is never shared")
    func oldDocumentIsClearedWhenANewExportStarts() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }
        #expect(sheet.document != nil)

        sheet.select(language: SheetWorld.language("de"))

        #expect(sheet.status == .exporting)
        #expect(sheet.document == nil, "the PDF on screen is in the language left behind")
    }

    @Test("An export that ends cancelled is idle, not failed")
    func cancelledExportIsIdle() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.exporter.returns(.failure(CancellationError()))

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .idle)
        #expect(sheet.document == nil)
    }

    @Test("stop() drops the PDF shown, cancels the running export, and the export's late result changes nothing")
    func stopCancelsAndClears() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the first export to end") { sheet.status != .exporting }

        sheet.stop()

        #expect(sheet.status == .idle)
        #expect(sheet.document == nil, "the sheet is gone: no PDF is kept")

        await world.exporter.gate.close()
        sheet.start()
        await world.passThePause(thenExports: 2)
        await world.held(1)

        sheet.stop()

        #expect(world.exporter.cancellations.withLock { $0 } == 1)
        #expect(sheet.status == .idle)
        await world.exporter.gate.open()
        await settle()
        #expect(sheet.status == .idle, "the late result of the stopped export is dropped")
        #expect(sheet.document == nil)
    }
}
