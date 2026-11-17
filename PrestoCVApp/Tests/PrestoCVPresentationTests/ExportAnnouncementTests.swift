import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What VoiceOver is told of an export that ended: a problem the status line says, and nothing for a PDF made in full,
/// for an export still running, or for a field the CV lacks, which the list under the pages names.
@MainActor
@Suite("Export sheet announcements")
struct ExportAnnouncementTests {

    @Test("Each export failure is told as its status says it, but a CV that lacks a field",
          arguments: ExportSheetStatusTests.failures)
    func eachFailureIsTold(row: ExportSheetStatusTests.FailureRow) async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.exporter.returns(.failure(row.failure))

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == row.status)
        #expect(sheet.statusToAnnounce == (row.status == .notReady ? nil : row.status))
    }

    @Test("A PDF made in full is not told; a PDF shorter than the CV needs is")
    func onlyAShortPDFIsTold() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the first export to end") { sheet.status != .exporting }
        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.statusToAnnounce == nil, "a good end says nothing")

        world.exporter.returns(.success(ExportOutcome(pdf: Data([7]), pageCount: 2, requiredPages: 3)))
        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await waitUntil("the second export to end") { sheet.status != .exporting }
        #expect(sheet.statusToAnnounce == .truncated(pages: 2, required: 3))
    }

    @Test("A CV with no language is told it needs one, and nothing is exported")
    func aMissingLanguageIsTold() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        let sheet = world.sheet()

        sheet.start()
        world.passThePause()
        await waitUntil("the sheet to read the CV") { sheet.status != .exporting }

        #expect(sheet.status == .languageNeeded)
        #expect(sheet.statusToAnnounce == .languageNeeded)
        #expect(world.exporter.calls == 0)
    }

    @Test("A CV with no name is not told: the list under the pages says what it lacks, and Share's value points to it")
    func aMissingNameIsNotTold() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(fullName: "")
        let sheet = world.sheet()

        sheet.start()
        world.passThePause()
        await waitUntil("the sheet to read the CV") { sheet.status != .exporting }

        #expect(sheet.status == .notReady)
        #expect(sheet.statusToAnnounce == nil)
        #expect(world.exporter.calls == 0)
    }

    @Test("Nothing is told while an export runs, so the same problem is told again after it, nor after the sheet ends")
    func nothingIsToldWhileAnExportRunsNorAfterTheEnd() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.exporter.returns(.failure(ExportFailure.renderingFailed))
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the first export to end") { sheet.status != .exporting }
        #expect(sheet.statusToAnnounce == .failed)

        await world.exporter.gate.close()
        sheet.refresh()
        #expect(sheet.statusToAnnounce == nil, "the pause counts as part of the export")
        await world.passThePause(thenExports: 2)
        await world.held(1)
        #expect(sheet.statusToAnnounce == nil, "the export runs")

        await world.exporter.gate.open()
        await waitUntil("the second export to end") { sheet.status != .exporting }
        #expect(sheet.statusToAnnounce == .failed, "told again")

        sheet.stop()
        #expect(sheet.statusToAnnounce == nil)
    }
}
