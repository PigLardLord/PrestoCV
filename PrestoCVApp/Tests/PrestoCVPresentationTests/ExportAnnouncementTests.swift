import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What VoiceOver is told of an export that ended: a problem the status line says, and nothing for a PDF made in full,
/// for an export still running, or for a field the CV lacks, which the list under the pages names. A PDF made in full
/// again after a pick in the sheet is told with its pages: the picker hides the PDF behind it.
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

    @Test("A CV with no language is exported and not told: its words or the app's language stand in (#407)")
    func aMissingLanguageIsNotTold() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.statusToAnnounce == nil)
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

    // MARK: - A PDF made again after a pick

    /// A sheet whose opening export made its PDF.
    private static func openedSheet(_ world: SheetWorld) async -> ExportSheetViewModel {
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the opening export to end") { sheet.status != .exporting }
        return sheet
    }

    @Test("A PDF made again after a look picked in the sheet is told with its pages; the opening export is not (#407)")
    func aLookPickIsToldOnceItsPDFIsMade() async {
        let world = SheetWorld()
        let sheet = await Self.openedSheet(world)
        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.remadeToAnnounce == nil, "the opening export says nothing: the sheet opens on its PDF")

        world.exporter.returns(.success(ExportOutcome(pdf: Data([7]), pageCount: 2, requiredPages: 2)))
        sheet.choose(palette: "forest")
        #expect(sheet.remadeToAnnounce == nil, "nothing is told while the PDF is made")
        await world.passThePause(thenExports: 2)
        await waitUntil("the export of the pick to end") { sheet.status != .exporting }

        #expect(sheet.remadeToAnnounce?.pages == 2)
        #expect(sheet.statusToAnnounce == nil)
    }

    @Test("A PDF made again after a language picked in the sheet is told too")
    func aLanguagePickIsToldOnceItsPDFIsMade() async {
        let world = SheetWorld()
        let sheet = await Self.openedSheet(world)

        sheet.select(language: SheetWorld.language("de"))
        await world.passThePause(thenExports: 2)
        await waitUntil("the export of the pick to end") { sheet.status != .exporting }

        #expect(sheet.remadeToAnnounce?.pages == 1)
    }

    @Test("Each PDF made again is a new value, so the second of two picks with the same pages is told as well")
    func eachPDFMadeAgainIsANewValue() async {
        let world = SheetWorld()
        let sheet = await Self.openedSheet(world)

        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)
        await waitUntil("the first pick's export to end") { sheet.status != .exporting }
        let first = sheet.remadeToAnnounce
        sheet.choose(palette: "ocean")
        #expect(sheet.remadeToAnnounce == nil, "a new pick clears the last one")
        await world.passThePause(thenExports: 3)
        await waitUntil("the second pick's export to end") { sheet.status != .exporting }
        let second = sheet.remadeToAnnounce

        #expect(first != nil && second != nil)
        #expect(first?.pages == second?.pages)
        #expect(first != second)
    }

    @Test("A refresh, and a pick whose export ends with a problem, are not told as a PDF made again")
    func aRefreshAndAProblemAreNotToldAsMadeAgain() async {
        let world = SheetWorld()
        let sheet = await Self.openedSheet(world)

        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await waitUntil("the refresh to end") { sheet.status != .exporting }
        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.remadeToAnnounce == nil, "a refresh follows a change made outside the sheet")

        world.exporter.returns(.success(ExportOutcome(pdf: Data([7]), pageCount: 2, requiredPages: 3)))
        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 3)
        await waitUntil("the short export to end") { sheet.status != .exporting }
        #expect(sheet.statusToAnnounce == .truncated(pages: 2, required: 3))
        #expect(sheet.remadeToAnnounce == nil, "the status tells a short PDF")

        world.exporter.returns(.failure(ExportFailure.renderingFailed))
        sheet.choose(palette: "ocean")
        await world.passThePause(thenExports: 4)
        await waitUntil("the failed export to end") { sheet.status != .exporting }
        #expect(sheet.statusToAnnounce == .failed)
        #expect(sheet.remadeToAnnounce == nil, "the status tells a failure")
    }

    @Test("A pick of the look being made keeps its export told; a refresh after a pick is not told")
    func theLatestExportDecidesWhatIsTold() async {
        let world = SheetWorld()
        let sheet = await Self.openedSheet(world)

        await world.exporter.gate.close()
        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)
        await world.held(1)
        sheet.choose(palette: "forest")
        #expect(world.exporter.calls == 2, "the look being made keeps its export")
        await world.exporter.gate.open()
        await waitUntil("the pick's export to end") { sheet.status != .exporting }
        #expect(sheet.remadeToAnnounce?.pages == 1)

        await world.exporter.gate.close()
        sheet.choose(palette: "ocean")
        await world.passThePause(thenExports: 3)
        await world.held(1)
        sheet.refresh()
        await world.exporter.gate.open()
        await world.passThePause(thenExports: 4)
        await waitUntil("the refresh to end") { sheet.status != .exporting }
        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.remadeToAnnounce == nil, "the refresh, the latest export, is not told")
    }

    @Test("The end of the sheet clears a PDF made again")
    func theEndClearsAPDFMadeAgain() async {
        let world = SheetWorld()
        let sheet = await Self.openedSheet(world)
        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)
        await waitUntil("the pick's export to end") { sheet.status != .exporting }
        #expect(sheet.remadeToAnnounce != nil)

        sheet.stop()

        #expect(sheet.remadeToAnnounce == nil)
    }
}
